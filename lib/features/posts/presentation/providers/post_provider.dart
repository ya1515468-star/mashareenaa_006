import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/create_post_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/delete_post_usecase.dart';
import '../../domain/usecases/toggle_like_usecase.dart';

final feedProvider =
    StreamProvider.family<List<PostEntity>, String?>((ref, category) {
  return sl<PostRepository>().watchFeed(category: category);
});

final postCommentsProvider =
    StreamProvider.family<List<CommentEntity>, String>((ref, postId) {
  return sl<PostRepository>().watchComments(postId);
});

final isPostLikedProvider =
    FutureProvider.family<bool, String>((ref, postId) async {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return false;
  final result =
      await sl<PostRepository>().isLikedByUser(postId: postId, uid: uid);
  return result.fold((failure) => false, (liked) => liked);
});

class PostController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createPost(PostEntity post) async {
    state = const AsyncLoading();
    final result = await sl<CreatePostUseCase>()(post);
    return result.fold((failure) {
      state = AsyncError(failure.message, StackTrace.current);
      return false;
    }, (_) {
      state = const AsyncData(null);
      return true;
    });
  }

  Future<void> toggleLike(
      {required String postId,
      required String uid,
      required String postAuthorUid}) async {
    await sl<ToggleLikeUseCase>()(
        postId: postId, uid: uid, postAuthorUid: postAuthorUid);
  }

  Future<bool> deletePost(
      {required String postId,
      required String authorUid,
      required String requestedByUid}) async {
    final result = await sl<DeletePostUseCase>()(
      postId: postId,
      authorUid: authorUid,
      requestedByUid: requestedByUid,
    );
    return result.isRight();
  }

  Future<bool> addComment(CommentEntity comment,
      {required String postAuthorUid}) async {
    final result =
        await sl<AddCommentUseCase>()(comment, postAuthorUid: postAuthorUid);
    return result.isRight();
  }

  Future<bool> deleteComment({
    required String postId,
    required String commentId,
    required String authorUid,
    required String requestedByUid,
  }) async {
    final result = await sl<DeleteCommentUseCase>()(
      postId: postId,
      commentId: commentId,
      authorUid: authorUid,
      requestedByUid: requestedByUid,
    );
    return result.isRight();
  }
}

final postControllerProvider =
    AsyncNotifierProvider<PostController, void>(PostController.new);
