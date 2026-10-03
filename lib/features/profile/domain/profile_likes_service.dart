import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real Supabase-backed profile likes.
/// The old app_documents compatibility path caused RLS failures on the
/// profile page, so likes now use the dedicated profile_likes table.
class ProfileLikesService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<bool> toggleLike({
    required String profileUid,
    required String likerUid,
  }) async {
    if (profileUid == likerUid) return false;
    final currentUid = _sb.auth.currentUser?.id;
    if (currentUid == null || currentUid != likerUid) {
      throw const PostgrestException(message: 'AUTH_REQUIRED');
    }

    final existing = await _sb
        .from('profile_likes')
        .select('profile_uid,liker_uid')
        .eq('profile_uid', profileUid)
        .eq('liker_uid', likerUid)
        .maybeSingle();

    if (existing != null) {
      await _sb
          .from('profile_likes')
          .delete()
          .eq('profile_uid', profileUid)
          .eq('liker_uid', likerUid);
      return false;
    }

    await _sb.from('profile_likes').insert({
      'profile_uid': profileUid,
      'liker_uid': likerUid,
    });
    return true;
  }

  static Stream<int> watchLikesCount(String profileUid) {
    return _sb
        .from('profile_likes')
        .stream(primaryKey: const ['profile_uid', 'liker_uid'])
        .eq('profile_uid', profileUid)
        .map((rows) => rows.length);
  }

  static Stream<bool> watchIsLikedBy({
    required String profileUid,
    required String viewerUid,
  }) {
    return _sb
        .from('profile_likes')
        .stream(primaryKey: const ['profile_uid', 'liker_uid'])
        .eq('profile_uid', profileUid)
        .map((rows) =>
            rows.any((row) => row['liker_uid']?.toString() == viewerUid));
  }
}

final profileLikesCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, uid) {
  return ProfileLikesService.watchLikesCount(uid);
});

final profileIsLikedByViewerProvider = StreamProvider.autoDispose
    .family<bool, ({String profileUid, String viewerUid})>((ref, args) {
  return ProfileLikesService.watchIsLikedBy(
    profileUid: args.profileUid,
    viewerUid: args.viewerUid,
  );
});
