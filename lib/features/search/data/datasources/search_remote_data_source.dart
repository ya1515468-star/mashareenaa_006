import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../profile/data/models/profile_model.dart';

abstract class SearchRemoteDataSource {
  Future<List<ProfileModel>> searchProfiles(String query);
  Future<List<PostModel>> searchPosts(String query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseDocumentStore store;

  SearchRemoteDataSourceImpl(this.store);

  /// يبني حدّي نطاق بحث البادئة القياسيين لـ طبقة بيانات Supabase: [query,
  /// query + \uf8ff] — وهي التقنية الرسمية الموصى بها من طبقة بيانات Supabase
  /// لبحث "يبدأ بـ" في غياب محرك بحث نصي كامل.
  (String, String) _prefixRange(String query) => (query, '$query\uf8ff');

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'search_public_profiles',
        params: {'p_query': query.trim(), 'p_limit': 30},
      );
      final rows = raw is List ? raw : const <dynamic>[];
      return rows.whereType<Map>().map((row) => ProfileModel.fromMap(
        row['id'].toString(), Map<String, dynamic>.from(row),
      )).toList(growable: false);
    } catch (e) {
      throw ServerException(message: 'تعذّر البحث عن المستخدمين: $e');
    }
  }

  @override
  Future<List<PostModel>> searchPosts(String query) async {
    try {
      final normalized = query.trim();
      if (normalized.isEmpty) return [];

      // مطابقة الوسم الكامل (بدون #) إن كتب المستخدم وسمًا بالضبط.
      final byTag = await store
          .collection('posts')
          .where('isHidden', isEqualTo: false)
          .where('tags', arrayContains: normalized.replaceAll('#', ''))
          .limit(30)
          .get();

      if (byTag.docs.isNotEmpty) {
        return byTag.docs
            .map((d) =>
                PostModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
            .toList();
      }

      // خلاف ذلك: بحث بادئة على بداية نص المنشور.
      final (start, end) = _prefixRange(normalized);
      final byText = await store
          .collection('posts')
          .where('isHidden', isEqualTo: false)
          .orderBy('text')
          .startAt([start])
          .endAt([end])
          .limit(30)
          .get();

      return byText.docs
          .map((d) =>
              PostModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      throw ServerException(message: 'تعذّر البحث عن المنشورات: $e');
    }
  }
}
