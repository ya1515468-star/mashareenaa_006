import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';
import '../models/app_notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<AppNotificationEntity>> watchNotifications(String uid) =>
      remoteDataSource.watchNotifications(uid);

  @override
  Stream<int> watchUnreadCount(String uid) =>
      remoteDataSource.watchUnreadCount(uid);

  @override
  Future<Either<Failure, void>> create(
      AppNotificationEntity notification) async {
    try {
      await remoteDataSource.create(
        AppNotificationModel(
          id: '',
          uid: notification.uid,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          relatedId: notification.relatedId,
          actorUid: notification.actorUid,
          isRead: false,
          createdAt: notification.createdAt,
        ),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markRead(String notificationId) async {
    try {
      await remoteDataSource.markRead(notificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAllRead(String uid) async {
    try {
      await remoteDataSource.markAllRead(uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String notificationId) async {
    try {
      await remoteDataSource.delete(notificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAll(String uid) async {
    try {
      await remoteDataSource.deleteAll(uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
