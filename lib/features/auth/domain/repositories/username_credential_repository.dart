import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/username_credential_entity.dart';

abstract class UsernameCredentialRepository {
  /// يتحقق من توفر اسم المستخدم (فحص فوري أثناء الكتابة في شاشة
  /// التسجيل).
  Future<Either<Failure, bool>> isUsernameAvailable(String username);

  /// ينشئ اسم المستخدم + يجزّئ رمز PIN ويخزّنه مرتبطًا بـ [uid].
  Future<Either<Failure, UsernameCredentialEntity>> createUsernameAndPin({
    required String uid,
    required String username,
    required String pin,
  });

  /// يتحقق من رمز PIN المُدخَل مقابل التجزئة المخزّنة لهذا المستخدم.
  Future<Either<Failure, bool>> verifyPin(
      {required String uid, required String pin});

  /// يحوّل اسم مستخدم إلى uid صاحبه — يُستخدم في شاشة تحويل النقاط
  /// للسماح بالتحويل باسم المستخدم بدل uid الخام.
  Future<Either<Failure, String>> resolveUidByUsername(String username);
}
