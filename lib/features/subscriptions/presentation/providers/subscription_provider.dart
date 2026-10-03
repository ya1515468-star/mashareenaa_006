import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/user_subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

final currentSubscriptionProvider =
    StreamProvider<UserSubscriptionEntity?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  final repository = sl<SubscriptionRepository>();
  return repository.watchSubscription(user.uid);
});
