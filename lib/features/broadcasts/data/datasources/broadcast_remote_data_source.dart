import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failure_text.dart';

import '../../../../core/error/exceptions.dart';
import '../models/broadcast_model.dart';

abstract class BroadcastRemoteDataSource {
  Future<void> sendBroadcast({
    required String message,
    required String sentByUid,
  });

  Stream<BroadcastModel?> watchLatestBroadcast();
}

class BroadcastRemoteDataSourceImpl implements BroadcastRemoteDataSource {
  final SupabaseClient client;

  const BroadcastRemoteDataSourceImpl(this.client);

  @override
  Future<void> sendBroadcast({
    required String message,
    required String sentByUid,
  }) async {
    try {
      final trimmedMessage = message.trim();

      if (trimmedMessage.isEmpty) {
        throw const ServerException(
          message: 'لا يمكن إرسال بث فارغ',
        );
      }

      // sentByUid يبقى ضمن الواجهة الحالية للتوافق مع الـUseCase،
      // لكن لا يتم الوثوق به ولا إرساله إلى الخادم كمصدر للصلاحية.
      //
      // الـbackend سيعتمد على auth.uid() داخل RPC.
      await client.rpc(
        'publish_platform_broadcast',
        params: <String, dynamic>{
          'p_message': trimmedMessage,
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: FailureText.of(e),
        code: e.code,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: FailureText.of(e),
      );
    }
  }

  @override
  Stream<BroadcastModel?> watchLatestBroadcast() {
    if (client.auth.currentSession == null) {
      return Stream<BroadcastModel?>.value(null);
    }

    // كان هذا الاستعلام بلا أي مُرشِّح على `is_active` ولا `expires_at`،
    // والنموذج لا يقرأ هذين الحقلين أصلًا — فيُجلب **أحدث صفّ مهما كان**.
    // الأثر الفعلي: بثّ قديم مُطفأ ومنتهٍ منذ شهر («هاي») كان يومض عند
    // كل فتح للتطبيق ثم يختفي. الآن المُرشِّح على الخادم لـis_active،
    // والانتهاء يُفحص هنا لأن قيمة الوقت في مُرشِّح البثّ تتجمّد عند
    // الاشتراك فلا تصلح لمقارنة زمنية حيّة.
    return client
        .from('platform_broadcasts')
        .stream(primaryKey: const ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }

          final row = Map<String, dynamic>.from(rows.first);

          if (row['is_active'] != true) {
            return null;
          }

          final expiresRaw = row['expires_at']?.toString();
          if (expiresRaw != null && expiresRaw.isNotEmpty) {
            final expiresAt = DateTime.tryParse(expiresRaw);
            if (expiresAt != null &&
                expiresAt.toUtc().isBefore(DateTime.now().toUtc())) {
              return null;
            }
          }

          return BroadcastModel.fromMap(
            row['id']?.toString() ?? '',
            <String, dynamic>{
              'message': row['message'],
              'sentByUid': row['sent_by_uid'],
              'createdAt': row['created_at'],
            },
          );
        });
  }
}
