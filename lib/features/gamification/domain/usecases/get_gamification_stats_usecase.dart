import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gamification_stats_entity.dart';
import '../repositories/gamification_repository.dart';

class GetGamificationStatsUseCase {
  final GamificationRepository repository;

  const GetGamificationStatsUseCase(this.repository);

  Future<Either<Failure, GamificationStatsEntity>> call(String uid) =>
      repository.getStats(uid);
}
