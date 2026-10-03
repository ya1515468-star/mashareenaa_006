import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String displayName;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

/// أهم نقطة ترابط في الأساس: عند إنشاء حساب بنجاح، يتم تلقائيًا
/// وبالتسلسل: 1) إنشاء المستخدم في Supabase Auth، 2) إنشاء ملفه
/// الشخصي (Profile)، 3) إسناد الدور الافتراضي visitor (RBAC).
class SignUpUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final RbacRepository rbacRepository;

  const SignUpUseCase({
    required this.authRepository,
    required this.profileRepository,
    required this.rbacRepository,
  });

  Future<Either<Failure, UserEntity>> call(SignUpParams params) async {
    final signUpResult = await authRepository.signUp(
      email: params.email,
      password: params.password,
      displayName: params.displayName,
    );

    if (signUpResult.isLeft()) {
      return signUpResult.fold(
          (failure) => Left(failure), (user) => Right(user));
    }

    final user = signUpResult.getOrElse(() => throw StateError('unreachable'));

    // Confirm Email can intentionally return without a session. In that case
    // profile/visitor role creation is handled by the auth.users triggers in
    // Supabase; client-side writes would be rejected by RLS before verification.
    // After verification and the first login, the normal update path below
    // remains available for projects where a session is returned immediately.
    if (sl<SupabaseClient>().auth.currentSession == null) {
      return Right(user);
    }

    final profileResult = await profileRepository.createProfile(
      uid: user.uid,
      displayName: params.displayName,
      email: params.email,
    );

    if (profileResult.isLeft()) {
      return profileResult.fold((failure) => Left(failure), (_) => Right(user));
    }

    // الدور الافتراضي يُسنده الخادم تلقائيًا عند إنشاء الحساب (المشغّل
    // on_auth_user_created ← handle_new_user). كان هذا الاستدعاء يكرّر
    // الإسناد من العميل عبر assign_default_role — وصلاحيتها مسحوبة عن
    // authenticated عمدًا (منحها يسمح لأي عضو بإسناد أدوار لغيره). فكان
    // يفشل دائمًا، والتسجيل يُرجع فشلًا رغم أن الحساب أُنشئ فعلًا بدوره
    // الصحيح على الخادم.
    return Right(user);
  }
}
