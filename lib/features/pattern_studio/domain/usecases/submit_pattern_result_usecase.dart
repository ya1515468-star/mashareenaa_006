import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../repositories/pattern_studio_repository.dart';

class SubmitPatternResultUseCase {
  final PatternStudioRepository patternRepository;
  final RbacRepository rbacRepository;
  final NotificationRepository notificationRepository;

  const SubmitPatternResultUseCase({
    required this.patternRepository,
    required this.rbacRepository,
    required this.notificationRepository,
  });

  Future<Either<Failure, void>> call({
    required String requestId,
    required String requesterUid,
    required String reviewedByUid,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  }) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: reviewedByUid,
      permission: AppPermissions.moderateContent,
    );
    final allowed = permissionResult.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    final result = await patternRepository.submitResult(
      requestId: requestId,
      resultImageUrl: resultImageUrl,
      resultVideoUrl: resultVideoUrl,
      reviewerNote: reviewerNote,
    );

    if (result.isRight()) {
      await notificationRepository.create(
        AppNotificationEntity(
          id: '',
          uid: requesterUid,
          type: AppNotificationType.system,
          title: 'باترونك جاهز',
          body: 'تم إكمال طلب استوديو الباترون الخاص بك',
          relatedId: requestId,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    return result;
  }
}
