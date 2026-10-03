import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../entities/comment_entity.dart';
import '../repositories/post_repository.dart';

class AddCommentUseCase {
  final PostRepository postRepository;
  final NotificationRepository notificationRepository;

  const AddCommentUseCase(
      {required this.postRepository, required this.notificationRepository});

  Future<Either<Failure, void>> call(CommentEntity comment,
      {required String postAuthorUid}) async {
    if (comment.text.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'لا يمكن إضافة تعليق فارغ'));
    }

    final result = await postRepository.addComment(comment);

    if (result.isRight() && postAuthorUid != comment.authorUid) {
      await notificationRepository.create(
        AppNotificationEntity(
          id: '',
          uid: postAuthorUid,
          type: AppNotificationType.comment,
          title: 'تعليق جديد',
          body: comment.text,
          relatedId: comment.postId,
          actorUid: comment.authorUid,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    return result;
  }
}
