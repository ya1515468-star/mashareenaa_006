import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/social_graph_repository.dart';

class UnblockUseCase {
  final SocialGraphRepository repository;

  const UnblockUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String blockerUid, required String targetUid}) {
    return repository.unblock(blockerUid: blockerUid, targetUid: targetUid);
  }
}
