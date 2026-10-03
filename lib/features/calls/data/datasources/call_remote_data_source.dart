import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/call_entity.dart';
import '../models/call_model.dart';

abstract class CallRemoteDataSource {
  Future<CallModel> startCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  });
  Stream<CallModel?> watchIncomingRingingCall(String uid);
  Stream<CallModel?> watchCall(String callId);
  Future<void> updateStatus(
      {required String callId, required CallStatus status});
}

class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  final SupabaseClient client;

  CallRemoteDataSourceImpl(this.client);

  Map<String, dynamic> _rowToData(Map<String, dynamic> row) {
    final raw = row['data'];
    final data =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    data['id'] = row['doc_id']?.toString() ?? data['id'];
    return data;
  }

  @override
  Future<CallModel> startCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  }) async {
    try {
      final current = client.auth.currentUser?.id;
      if (current == null || current != callerUid) {
        throw const ServerException(
            message: 'هوية المتصل غير صالحة.', code: 'FORBIDDEN');
      }
      final response = await client.rpc('start_call', params: {
        'p_callee_uid': calleeUid,
        'p_type': type.wire,
      });
      final data = Map<String, dynamic>.from(response as Map);
      return CallModel.fromMap(data['id'].toString(), data);
    } on PostgrestException catch (e) {
      throw ServerException(
          message: 'تعذّر بدء الاتصال: ${e.message}', code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'تعذّر بدء الاتصال: $e');
    }
  }

  Stream<CallModel?> _watchCalls({String? callId, String? calleeUid}) {
    return client
        .from('app_documents')
        .stream(primaryKey: ['id'])
        .eq('collection_path', 'calls')
        .map((rows) {
          for (final raw in rows) {
            final row = Map<String, dynamic>.from(raw);
            final data = _rowToData(row);
            if (callId != null && data['id']?.toString() != callId) continue;
            if (calleeUid != null && data['calleeUid']?.toString() != calleeUid) {
              continue;
            }
            if (callId == null &&
                data['status']?.toString() != CallStatus.ringing.wire) {
              continue;
            }
            return CallModel.fromMap(data['id'].toString(), data);
          }
          return null;
        });
  }

  @override
  Stream<CallModel?> watchIncomingRingingCall(String uid) =>
      _watchCalls(calleeUid: uid);

  @override
  Stream<CallModel?> watchCall(String callId) => _watchCalls(callId: callId);

  @override
  Future<void> updateStatus({
    required String callId,
    required CallStatus status,
  }) async {
    try {
      await client.rpc('update_call_status', params: {
        'p_call_id': callId,
        'p_status': status.wire,
      });
    } on PostgrestException catch (e) {
      throw ServerException(
          message: 'تعذّر تحديث حالة الاتصال: ${e.message}', code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'تعذّر تحديث حالة الاتصال: $e');
    }
  }
}
