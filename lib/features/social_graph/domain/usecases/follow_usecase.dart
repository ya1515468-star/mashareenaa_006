import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/social_graph_repository.dart';

class FollowUseCase {
  final SocialGraphRepository repository;

  const FollowUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String followerUid, required String targetUid}) async {
    if (followerUid == targetUid) {
      return const Left(ValidationFailure(message: 'لا يمكن متابعة نفسك'));
    }

    final blockResult = await repository.hasBlockEitherDirection(
        uidA: followerUid, uidB: targetUid);
    final blocked = blockResult.getOrElse(() => false);
    if (blocked) {
      return const Left(PermissionFailure(
          message: 'لا يمكن المتابعة بسبب وجود حظر بين الطرفين'));
    }

    return repository.follow(followerUid: followerUid, targetUid: targetUid);
  }
}
