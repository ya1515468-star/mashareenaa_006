import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../social_graph/domain/repositories/social_graph_repository.dart';
import '../entities/call_entity.dart';
import '../repositories/call_repository.dart';

class StartCallUseCase {
  final CallRepository callRepository;
  final SocialGraphRepository socialGraphRepository;

  const StartCallUseCase(
      {required this.callRepository, required this.socialGraphRepository});

  Future<Either<Failure, CallEntity>> call({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  }) async {
    if (callerUid == calleeUid) {
      return const Left(ValidationFailure(message: 'لا يمكن الاتصال بنفسك'));
    }

    final blockResult = await socialGraphRepository.hasBlockEitherDirection(
        uidA: callerUid, uidB: calleeUid);
    final blocked = blockResult.getOrElse(() => false);
    if (blocked) {
      return const Left(PermissionFailure(
          message: 'لا يمكن الاتصال بسبب وجود حظر بين الطرفين'));
    }

    return callRepository.startCall(
        callerUid: callerUid, calleeUid: calleeUid, type: type);
  }
}
