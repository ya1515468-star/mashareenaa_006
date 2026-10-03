import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/gamification_repository.dart';

/// تحويل نقاط بين عضوين. الحالة العادية: يُخصَم المبلغ من الراسل
/// ويُشترط تأكيد بريد الطرفين إلكترونيًا فعليًا (Supabase
/// accounts/{uid}.emailVerified — الذي تضبطه Cloud Function كود
/// التأكيد بعد التسجيل). حالة الإدارة: من يملك صلاحية
/// transfer_points_admin (DRAGON) يحوّل بلا خصم من أي طرف ولا شرط
/// تحقق — منح إداري مباشر.
class TransferPointsUseCase {
  final GamificationRepository gamificationRepository;
  final RbacRepository rbacRepository;

  const TransferPointsUseCase(
      {required this.gamificationRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required String fromUid,
    required String toUid,
    required int amount,
  }) async {
    if (amount <= 0) {
      return const Left(
          ValidationFailure(message: 'مبلغ التحويل يجب أن يكون أكبر من صفر'));
    }

    final adminCheck = await rbacRepository.hasPermission(
      uid: fromUid,
      permission: AppPermissions.transferPointsAdmin,
    );
    final isAdminTransfer = adminCheck.getOrElse(() => false);

    return gamificationRepository.transferPoints(
      fromUid: fromUid,
      toUid: toUid,
      amount: amount,
      bypassChecks: isAdminTransfer,
    );
  }
}
