import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/gamification_repository.dart';

/// نقطة الاستهلاك الوحيدة للنقاط/الجواهر عبر كل التطبيق (السوق،
/// المتاجر، تأثيرات الأسماء المدفوعة بالنقاط لاحقًا...). تتحقق أولًا
/// من RbacRepository إن كان المستخدم يملك unlimited_resources —
/// وإن كان كذلك، تتجاوز الخصم بالكامل بدل استهلاك أي رقم.
class SpendPointsUseCase {
  final GamificationRepository gamificationRepository;
  final RbacRepository rbacRepository;

  const SpendPointsUseCase(
      {required this.gamificationRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call(
      {required String uid, required int amount}) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: uid,
      permission: AppPermissions.unlimitedResources,
    );

    final unlimited = permissionResult.getOrElse(() => false);

    return gamificationRepository.spendPoints(
        uid: uid, amount: amount, unlimited: unlimited);
  }
}
