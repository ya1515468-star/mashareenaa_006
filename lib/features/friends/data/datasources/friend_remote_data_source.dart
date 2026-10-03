import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/friend_request_model.dart';

abstract class FriendRemoteDataSource {
  Future<void> sendRequest({required String fromUid, required String toUid});
  Future<void> respondToRequest(
      {required String requestId, required bool accept});
  Future<void> removeFriend({required String uidA, required String uidB});
  Stream<FriendRequestModel?> watchRelationship(
      {required String uidA, required String uidB});
  Stream<List<FriendRequestModel>> watchFriends(String uid);
  Stream<List<FriendRequestModel>> watchPendingIncoming(String uid);
}

class FriendRemoteDataSourceImpl implements FriendRemoteDataSource {
  final SupabaseClient client;
  FriendRemoteDataSourceImpl(this.client);

  FriendRequestModel _map(Map<String, dynamic> row) =>
      FriendRequestModel.fromMap(row['id'].toString(), row);

  @override
  Future<void> sendRequest(
      {required String fromUid, required String toUid}) async {
    try {
      final current = client.auth.currentUser?.id;
      if (current == null || current != fromUid) {
        throw const ServerException(
            message: 'هوية المرسل غير صالحة.', code: 'FORBIDDEN');
      }
      await client.rpc('send_friend_request', params: {'p_to_uid': toUid});
    } on PostgrestException catch (e) {
      throw ServerException(message: _error(e), code: e.code);
    }
  }

  @override
  Future<void> respondToRequest(
      {required String requestId, required bool accept}) async {
    try {
      await client.rpc('respond_friend_request',
          params: {'p_request_id': requestId, 'p_accept': accept});
    } on PostgrestException catch (e) {
      throw ServerException(message: _error(e), code: e.code);
    }
  }

  @override
  Future<void> removeFriend(
      {required String uidA, required String uidB}) async {
    if (client.auth.currentUser?.id != uidA) {
      throw const ServerException(message: 'FORBIDDEN', code: 'FORBIDDEN');
    }
    try {
      await client.rpc('remove_friend', params: {'p_other_uid': uidB});
    } on PostgrestException catch (e) {
      throw ServerException(message: _error(e), code: e.code);
    }
  }

  @override
  Stream<FriendRequestModel?> watchRelationship(
      {required String uidA, required String uidB}) {
    final a = uidA.compareTo(uidB) < 0 ? uidA : uidB;
    final b = uidA.compareTo(uidB) < 0 ? uidB : uidA;
    return client
        .from('friend_requests')
        .stream(primaryKey: ['id']).map((rows) {
      for (final row in rows) {
        if (row['from_uid'].toString() == a && row['to_uid'].toString() == b ||
            row['from_uid'].toString() == b && row['to_uid'].toString() == a) {
          return _map(Map<String, dynamic>.from(row));
        }
      }
      return null;
    });
  }

  @override
  Stream<List<FriendRequestModel>> watchFriends(String uid) {
    return client.from('friend_requests').stream(primaryKey: ['id']).map(
        (rows) => rows
            .map((r) => Map<String, dynamic>.from(r))
            .where((r) =>
                r['status'] == 'accepted' &&
                (r['from_uid'] == uid || r['to_uid'] == uid))
            .map(_map)
            .toList());
  }

  @override
  Stream<List<FriendRequestModel>> watchPendingIncoming(String uid) {
    return client.from('friend_requests').stream(primaryKey: ['id']).map(
        (rows) => rows
            .map((r) => Map<String, dynamic>.from(r))
            .where((r) => r['status'] == 'pending' && r['to_uid'] == uid)
            .map(_map)
            .toList());
  }

  String _error(PostgrestException e) {
    switch (e.message) {
      case 'ALREADY_FRIENDS':
        return 'أنتما صديقان بالفعل.';
      case 'REQUEST_EXISTS':
        return 'يوجد طلب صداقة معلّق بالفعل.';
      case 'INVALID_REQUEST':
        return 'طلب الصداقة غير صالح.';
      default:
        return e.message;
    }
  }
}
