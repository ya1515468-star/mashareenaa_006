import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rbac/presentation/providers/rbac_provider.dart';
import '../../domain/entities/gamification_stats_entity.dart';
import '../../domain/entities/points_package_entity.dart';
import '../../domain/repositories/gamification_repository.dart';
import '../../domain/usecases/claim_daily_reward_usecase.dart';
import '../../domain/usecases/purchase_points_package_usecase.dart';

final pointsPackagesProvider =
    FutureProvider.autoDispose<List<PointsPackageEntity>>((ref) async {
  final result = await sl<ListPointsPackagesUseCase>()();
  return result.fold(
      (failure) => throw Exception(failure.message), (items) => items);
});

// يبث إحصائيات التلعيب للمستخدم الحالي — مرتبط بـ
/// [authControllerProvider] مثل بقية الوحدات.
final gamificationStatsProvider =
    FutureProvider.family<GamificationStatsEntity?, String>((ref, uid) async {
  final result = await sl<GamificationRepository>().getStats(uid);
  return result.fold((_) => null, (stats) => stats);
});

final currentGamificationStatsProvider =
    StreamProvider<GamificationStatsEntity?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  final repository = sl<GamificationRepository>();
  return repository.watchStats(user.uid);
});

/// هل يملك المستخدم الحالي موارد غير محدودة؟ يُعاد استخدام نفس
/// hasPermissionProvider من وحدة RBAC — لا منطق صلاحيات مكرر.
final isUnlimitedResourcesProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(hasPermissionProvider(AppPermissions.unlimitedResources));
});

class GamificationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> claimDailyReward(String uid) async {
    state = const AsyncLoading();
    final useCase = sl<ClaimDailyRewardUseCase>();
    final result = await useCase(uid);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  Future<bool> purchasePointsPackage(
      {required String uid, required String packageId}) async {
    state = const AsyncLoading();
    final useCase = sl<PurchasePointsPackageUseCase>();
    final result = await useCase(uid: uid, packageId: packageId);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final gamificationControllerProvider =
    AsyncNotifierProvider<GamificationController, void>(
  GamificationController.new,
);
