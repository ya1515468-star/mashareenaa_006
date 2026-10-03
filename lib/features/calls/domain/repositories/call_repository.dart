import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/call_entity.dart';

abstract class CallRepository {
  Future<Either<Failure, CallEntity>> startCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  });

  /// يبث أي مكالمة "تُرن" حاليًا لهذا المستخدم — تُستخدم لعرض شاشة
  /// الاتصال الوارد فور وصولها من أي مكان في التطبيق.
  Stream<CallEntity?> watchIncomingRingingCall(String uid);

  Stream<CallEntity?> watchCall(String callId);

  Future<Either<Failure, void>> updateStatus(
      {required String callId, required CallStatus status});
}
