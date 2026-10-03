import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_notification_entity.dart';

abstract class NotificationRepository {
  Stream<List<AppNotificationEntity>> watchNotifications(String uid);

  Stream<int> watchUnreadCount(String uid);

  /// نقطة الإنشاء الوحيدة للإشعارات عبر كل التطبيق — تُستدعى داخليًا
  /// من وحدات أخرى (Chat عند رسالة جديدة، Posts عند إعجاب/تعليق،
  /// Follow عند متابعة جديدة) وليس من الواجهة مباشرة.
  Future<Either<Failure, void>> create(AppNotificationEntity notification);

  Future<Either<Failure, void>> markRead(String notificationId);

  Future<Either<Failure, void>> markAllRead(String uid);

  Future<Either<Failure, void>> delete(String notificationId);

  Future<Either<Failure, void>> deleteAll(String uid);
}
