import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/social_graph_repository.dart';

class UnfollowUseCase {
  final SocialGraphRepository repository;

  const UnfollowUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String followerUid, required String targetUid}) {
    return repository.unfollow(followerUid: followerUid, targetUid: targetUid);
  }
}
