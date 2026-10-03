import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../repositories/post_repository.dart';

/// يبدّل حالة الإعجاب، وينشئ إشعارًا لصاحب المنشور فقط عند الإعجاب
/// الفعلي (وليس عند إلغائه)، وفقط إن لم يكن هو نفسه صاحب المنشور.
class ToggleLikeUseCase {
  final PostRepository postRepository;
  final NotificationRepository notificationRepository;

  const ToggleLikeUseCase(
      {required this.postRepository, required this.notificationRepository});

  Future<Either<Failure, void>> call({
    required String postId,
    required String uid,
    required String postAuthorUid,
  }) async {
    final wasLikedResult =
        await postRepository.isLikedByUser(postId: postId, uid: uid);
    final wasLiked = wasLikedResult.getOrElse(() => false);

    final toggleResult =
        await postRepository.toggleLike(postId: postId, uid: uid);

    final nowLiking = !wasLiked;
    if (toggleResult.isRight() && nowLiking && postAuthorUid != uid) {
      await notificationRepository.create(
        AppNotificationEntity(
          id: '',
          uid: postAuthorUid,
          type: AppNotificationType.like,
          title: 'إعجاب جديد',
          body: 'أعجب أحدهم بمنشورك',
          relatedId: postId,
          actorUid: uid,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    return toggleResult;
  }
}
