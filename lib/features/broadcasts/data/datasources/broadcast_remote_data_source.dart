import 'package:supabase_flutter/supabase_flutter.dart';

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
        message: 'تعذّر إرسال البث: ${e.message}',
        code: e.code,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'تعذّر إرسال البث: $e',
      );
    }
  }

  @override
  Stream<BroadcastModel?> watchLatestBroadcast() {
    if (client.auth.currentSession == null) {
      return Stream<BroadcastModel?>.value(null);
    }

    return client
        .from('platform_broadcasts')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }

          final row = Map<String, dynamic>.from(rows.first);

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
