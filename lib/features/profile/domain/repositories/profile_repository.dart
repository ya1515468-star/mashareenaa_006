import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  /// يُنشئ الملف الشخصي مباشرة بعد نجاح التسجيل — يُستدعى حصريًا من
  /// [SignUpUseCase] وليس من أي شاشة مباشرة، لضمان أن كل مستخدم
  /// مسجَّل يملك ملفًا شخصيًا بلا استثناء.
  Future<Either<Failure, ProfileEntity>> createProfile({
    required String uid,
    required String displayName,
    required String email,
  });

  Future<Either<Failure, ProfileEntity>> getProfile(String uid);

  Future<Either<Failure, ProfileEntity>> updateProfile(ProfileEntity profile);

  Future<Either<Failure, void>> updateTypography({required String usernameFontFamily, required String messageFontFamily});

  Stream<ProfileEntity?> watchProfile(String uid);

  /// تفعيل/إلغاء شارة التوثيق — يتطلب صلاحية verify_accounts، يُتحقق
  /// منها داخل الـ UseCase قبل الاستدعاء.
  Future<Either<Failure, void>> setVerified(String uid, bool verified);
}
