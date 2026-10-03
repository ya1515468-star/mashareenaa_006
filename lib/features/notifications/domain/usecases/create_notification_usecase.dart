import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_notification_entity.dart';
import '../repositories/notification_repository.dart';

class CreateNotificationUseCase {
  final NotificationRepository repository;

  const CreateNotificationUseCase(this.repository);

  Future<Either<Failure, void>> call(AppNotificationEntity notification) =>
      repository.create(notification);
}
