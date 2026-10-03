import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/post_repository.dart';

class DeleteCommentUseCase {
  final PostRepository postRepository;
  final RbacRepository rbacRepository;

  const DeleteCommentUseCase(
      {required this.postRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required String postId,
    required String commentId,
    required String authorUid,
    required String requestedByUid,
  }) async {
    if (authorUid != requestedByUid) {
      final permissionResult = await rbacRepository.hasPermission(
        uid: requestedByUid,
        permission: AppPermissions.moderateContent,
      );
      final allowed = permissionResult.getOrElse(() => false);
      if (!allowed) return const Left(PermissionFailure());
    }

    return postRepository.deleteComment(postId: postId, commentId: commentId);
  }
}
