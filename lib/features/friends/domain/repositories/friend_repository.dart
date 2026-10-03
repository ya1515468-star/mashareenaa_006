import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/friend_request_entity.dart';

abstract class FriendRepository {
  Future<Either<Failure, void>> sendRequest(
      {required String fromUid, required String toUid});

  Future<Either<Failure, void>> respondToRequest({
    required String requestId,
    required bool accept,
  });

  Future<Either<Failure, void>> removeFriend(
      {required String uidA, required String uidB});

  /// يبث حالة العلاقة الحالية بين طرفين (لا يوجد طلب / معلّق مني /
  /// معلّق منه / أصدقاء بالفعل) — تُستخدم لتحديد نص وسلوك الزر في
  /// الواجهة.
  Stream<FriendRequestEntity?> watchRelationship(
      {required String uidA, required String uidB});

  /// قائمة الأصدقاء الفعليين (طلبات مقبولة فقط) لمستخدم معيّن.
  Stream<List<FriendRequestEntity>> watchFriends(String uid);

  /// الطلبات الواردة المعلّقة التي تنتظر رد هذا المستخدم.
  Stream<List<FriendRequestEntity>> watchPendingIncoming(String uid);
}
