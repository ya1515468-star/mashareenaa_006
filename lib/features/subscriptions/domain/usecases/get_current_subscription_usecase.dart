import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class GetCurrentSubscriptionUseCase {
  final SubscriptionRepository repository;

  const GetCurrentSubscriptionUseCase(this.repository);

  Future<Either<Failure, UserSubscriptionEntity>> call(String uid) =>
      repository.getCurrentSubscription(uid);
}
