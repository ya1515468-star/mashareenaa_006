import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';

abstract class SocialGraphRemoteDataSource {
  Future<void> follow({required String followerUid, required String targetUid});
  Future<void> unfollow(
      {required String followerUid, required String targetUid});
  Stream<bool> watchIsFollowing(
      {required String followerUid, required String targetUid});
  Stream<int> watchFollowersCount(String uid);
  Stream<int> watchFollowingCount(String uid);
  Stream<List<String>> watchFollowingUids(String uid);
  Future<void> block({required String blockerUid, required String targetUid});
  Future<void> unblock({required String blockerUid, required String targetUid});
  Future<bool> isBlocked(
      {required String blockerUid, required String targetUid});
  Stream<List<String>> watchBlockedUids(String uid);
}

class SocialGraphRemoteDataSourceImpl implements SocialGraphRemoteDataSource {
  final SupabaseDocumentStore store;

  SocialGraphRemoteDataSourceImpl(this.store);

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<void> follow(
      {required String followerUid, required String targetUid}) async {
    try {
      final currentUid = _sb.auth.currentUser?.id;
      if (currentUid == null || currentUid != followerUid) {
        throw const ServerException(message: 'جلسة المستخدم غير صالحة');
      }
      if (followerUid == targetUid) {
        throw const ServerException(message: 'لا يمكنك متابعة نفسك');
      }
      await _sb.from('user_follows').upsert({
        'follower_uid': followerUid,
        'following_uid': targetUid,
      }, onConflict: 'follower_uid,following_uid');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'لم تكتمل المتابعة: $e');
    }
  }

  @override
  Future<void> unfollow(
      {required String followerUid, required String targetUid}) async {
    try {
      final currentUid = _sb.auth.currentUser?.id;
      if (currentUid == null || currentUid != followerUid) {
        throw const ServerException(message: 'جلسة المستخدم غير صالحة');
      }
      await _sb
          .from('user_follows')
          .delete()
          .eq('follower_uid', followerUid)
          .eq('following_uid', targetUid);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'تعذّر إلغاء المتابعة: $e');
    }
  }

  @override
  Stream<bool> watchIsFollowing(
      {required String followerUid, required String targetUid}) {
    return _sb
        .from('user_follows')
        .stream(primaryKey: const ['follower_uid', 'following_uid'])
        .eq('follower_uid', followerUid)
        .map((rows) =>
            rows.any((row) => row['following_uid']?.toString() == targetUid));
  }

  @override
  Stream<int> watchFollowersCount(String uid) {
    return _sb
        .from('user_follows')
        .stream(primaryKey: const ['follower_uid', 'following_uid'])
        .eq('following_uid', uid)
        .map((rows) => rows.length);
  }

  @override
  Stream<int> watchFollowingCount(String uid) {
    return _sb
        .from('user_follows')
        .stream(primaryKey: const ['follower_uid', 'following_uid'])
        .eq('follower_uid', uid)
        .map((rows) => rows.length);
  }

  @override
  Stream<List<String>> watchFollowingUids(String uid) {
    return _sb
        .from('user_follows')
        .stream(primaryKey: const ['follower_uid', 'following_uid'])
        .eq('follower_uid', uid)
        .map((rows) => rows
            .map((row) => row['following_uid']?.toString())
            .whereType<String>()
            .toList(growable: false));
  }

  @override
  Future<void> block(
      {required String blockerUid, required String targetUid}) async {
    try {
      await _account(blockerUid).collection('blocked').doc(targetUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException(message: 'لم يكتمل الحظر: $e');
    }
  }

  @override
  Future<void> unblock(
      {required String blockerUid, required String targetUid}) async {
    try {
      await _account(blockerUid).collection('blocked').doc(targetUid).delete();
    } catch (e) {
      throw ServerException(message: 'تعذّر إلغاء الحظر: $e');
    }
  }

  @override
  Future<bool> isBlocked(
      {required String blockerUid, required String targetUid}) async {
    try {
      final doc =
          await _account(blockerUid).collection('blocked').doc(targetUid).get();
      return doc.exists;
    } catch (e) {
      throw ServerException(message: 'تعذّر التحقق من الحظر: $e');
    }
  }

  @override
  Stream<List<String>> watchBlockedUids(String uid) {
    return _account(uid).collection('blocked').snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toList(),
        );
  }

  DocumentReference<Map<String, dynamic>> _account(String uid) =>
      store.collection('accounts').doc(uid);
}
