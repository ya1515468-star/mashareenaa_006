import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../posts/domain/entities/post_entity.dart';
import '../../../profile/domain/entities/profile_entity.dart';

abstract class SearchRepository {
  /// بحث بادئة (Prefix) على اسم العرض — قيد تقني حقيقي لـ طبقة بيانات Supabase
  /// (لا محرك بحث نصي كامل مثل Algolia مربوط هنا)، لذا يجد "أحمد"
  /// عند كتابة "أحم" لكن لا يجدها عند كتابة "حمد" في المنتصف.
  Future<Either<Failure, List<ProfileEntity>>> searchProfiles(String query);

  /// بحث في المنشورات عبر تطابق وسم كامل (tags) أو بادئة النص.
  Future<Either<Failure, List<PostEntity>>> searchPosts(String query);
}
