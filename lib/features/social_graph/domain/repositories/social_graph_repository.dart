import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class SocialGraphRepository {
  // ------------------------------ متابعة -------------------------------------
  Future<Either<Failure, void>> follow(
      {required String followerUid, required String targetUid});
  Future<Either<Failure, void>> unfollow(
      {required String followerUid, required String targetUid});
  Stream<bool> watchIsFollowing(
      {required String followerUid, required String targetUid});
  Stream<int> watchFollowersCount(String uid);
  Stream<int> watchFollowingCount(String uid);

  /// قائمة uids من يتابعهم هذا المستخدم — تُستخدم لحساب "الأصدقاء
  /// المشتركون" بين مستخدمَين (ميزة 14 من القائمة الإضافية).
  Stream<List<String>> watchFollowingUids(String uid);

  // ------------------------------- حظر ---------------------------------------
  Future<Either<Failure, void>> block(
      {required String blockerUid, required String targetUid});
  Future<Either<Failure, void>> unblock(
      {required String blockerUid, required String targetUid});
  Future<Either<Failure, bool>> isBlocked(
      {required String blockerUid, required String targetUid});

  /// قائمة uids الذين حظرهم هذا المستخدم — لشاشة "إدارة المحظورين".
  Stream<List<String>> watchBlockedUids(String uid);

  /// هل يوجد حظر بأي اتجاه بين الطرفين؟ تُستخدم قبل السماح بالمراسلة
  /// أو المتابعة.
  Future<Either<Failure, bool>> hasBlockEitherDirection(
      {required String uidA, required String uidB});
}
