import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// عند تسجيل الدخول، يتحقق التطبيق من حالة الحساب (نشط/موقوف/
  /// محظور/محذوف) ويرفض الدخول بـ [AccountStatusFailure] إن لم يكن
  /// نشطًا — هذا التحقق يتم داخل الـ UseCase وليس هنا.
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  Future<Either<Failure, void>> resendSignupConfirmationEmail(String email);

  /// يبث المستخدم الحالي فور تغيّر حالة المصادقة. كل وحدة أخرى
  /// (Profile, RBAC) تعتمد على [AuthController] المبني فوق هذا
  /// الـ Stream كمصدر وحيد لمعرفة "من هو المستخدم الحالي؟".
  Stream<UserEntity?> get authStateChanges;

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// يجلب حالة الحساب من طبقة بيانات Supabase (وليس من Auth) — تُستخدم عند
  /// تسجيل الدخول للتحقق من الحظر/الإيقاف/الحذف.
  Future<Either<Failure, AccountStatus>> getAccountStatus(String uid);

  Future<Either<Failure, void>> updateEmail(String newEmail);

  Future<Either<Failure, void>> updatePassword(String newPassword);

  Future<Either<Failure, void>> linkGoogleIdentity();

  Future<Either<Failure, void>> requestAccountDeletion(String uid);
}
