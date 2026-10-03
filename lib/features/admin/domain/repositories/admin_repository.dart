import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class AdminRepository {
  /// يكتب حالة حساب جديدة مباشرة في طبقة بيانات Supabase — لا يتحقق من
  /// الصلاحية هنا؛ التحقق (suspend_accounts/ban_accounts/manage_users)
  /// يتم داخل [SetAccountStatusUseCase] قبل الوصول لهذه الطبقة.
  Future<Either<Failure, void>> setAccountStatus({
    required String targetUid,
    required AccountStatus status,
  });
}
