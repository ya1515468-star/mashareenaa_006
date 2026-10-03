import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../chat/data/services/chat_sound_service.dart';
import '../../domain/repositories/social_graph_repository.dart';
import '../../domain/usecases/block_usecase.dart';
import '../../domain/usecases/follow_usecase.dart';
import '../../domain/usecases/unblock_usecase.dart';
import '../../domain/usecases/unfollow_usecase.dart';

final isFollowingProvider =
    StreamProvider.family<bool, ({String followerUid, String targetUid})>(
  (ref, params) => sl<SocialGraphRepository>().watchIsFollowing(
      followerUid: params.followerUid, targetUid: params.targetUid),
);

final followersCountProvider = StreamProvider.family<int, String>(
    (ref, uid) => sl<SocialGraphRepository>().watchFollowersCount(uid));

final followingCountProvider = StreamProvider.family<int, String>(
    (ref, uid) => sl<SocialGraphRepository>().watchFollowingCount(uid));

class SocialGraphController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> follow(
      {required String followerUid, required String targetUid}) async {
    final result = await sl<FollowUseCase>()(
        followerUid: followerUid, targetUid: targetUid);
    return result.isRight();
  }

  Future<bool> unfollow(
      {required String followerUid, required String targetUid}) async {
    final result = await sl<UnfollowUseCase>()(
        followerUid: followerUid, targetUid: targetUid);
    return result.isRight();
  }

  Future<bool> block(
      {required String blockerUid, required String targetUid}) async {
    final result =
        await sl<BlockUseCase>()(blockerUid: blockerUid, targetUid: targetUid);
    // نجاح الحظر فعليًا (لا مجرد ضغط الزر) هو ما يُشغّل الصوت — إن رفضه
    // الخادم لأي سبب، لا صوت يوهم المستخدم بنجاح لم يحدث.
    if (result.isRight()) {
      unawaited(ChatSoundService(Supabase.instance.client)
          .play(ChatSoundEvent.block));
    }
    return result.isRight();
  }

  Future<bool> unblock(
      {required String blockerUid, required String targetUid}) async {
    final result = await sl<UnblockUseCase>()(
        blockerUid: blockerUid, targetUid: targetUid);
    return result.isRight();
  }
}

final socialGraphControllerProvider =
    AsyncNotifierProvider<SocialGraphController, void>(
        SocialGraphController.new);
