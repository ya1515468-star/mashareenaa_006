import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

/// مصدر الحقيقة الوحيد لهوية المستخدم عبر التطبيق. كل وحدة أخرى
/// (Profile, RBAC، وما سيُضاف لاحقًا) تعتمد على هذا الـ Provider
/// بدل قراءة SupabaseAuthCompat مباشرة.
class AuthController extends AsyncNotifier<UserEntity?> {
  AuthRepository get _repository => sl<AuthRepository>();

  @override
  Future<UserEntity?> build() async {
    // Resolve the current Supabase session immediately instead of waiting on
    // the first auth-state event. This prevents a valid saved session from
    // leaving the app on the login screen while the stream is still warming up.
    // Guarded with a timeout so a slow/unreachable network can never freeze
    // the whole app on this screen — it just falls back to "not logged in".
    UserEntity? initial;
    final current = await _repository.getCurrentUser().timeout(
      const Duration(seconds: 8),
      onTimeout: () => const Right(null),
    );
    current.fold<void>(
      (_) {},
      (user) => initial = user,
    );

    final sub = _repository.authStateChanges.listen((user) {
      state = AsyncData(user);
    }, onError: (_) {
      // Keep a valid current session usable even if an auxiliary auth-state
      // refresh fails transiently.
    });
    ref.onDispose(sub.cancel);

    return initial;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    final useCase = sl<SignUpUseCase>();
    final result = await useCase(
      SignUpParams(email: email, password: password, displayName: displayName),
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (user) {
        state = AsyncData(user);
        return true;
      },
    );
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final useCase = sl<SignInUseCase>();
    final result =
        await useCase(SignInParams(email: email, password: password));

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (user) {
        state = AsyncData(user);
        return true;
      },
    );
  }

  Future<void> signOut() async {
    final useCase = sl<SignOutUseCase>();
    await useCase();
    state = const AsyncData(null);
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final useCase = sl<ResetPasswordUseCase>();
    final result = await useCase(email);
    return result.isRight();
  }

  Future<String?> resendSignupConfirmationEmail(String email) async {
    final result = await _repository.resendSignupConfirmationEmail(email);
    return result.fold((f) => f.message, (_) => null);
  }

  /// كل التوابع التالية تُعيد null عند النجاح، أو رسالة الخطأ نصًّا —
  /// يكفي لعرضها مباشرة في SnackBar دون تعقيد إضافي.
  Future<String?> updateEmail(String newEmail) async {
    final result = await _repository.updateEmail(newEmail);
    return result.fold((f) => f.message, (_) => null);
  }

  Future<String?> updatePassword(String newPassword) async {
    final result = await _repository.updatePassword(newPassword);
    return result.fold((f) => f.message, (_) => null);
  }

  Future<String?> linkGoogleIdentity() async {
    final result = await _repository.linkGoogleIdentity();
    return result.fold((f) => f.message, (_) => null);
  }

  Future<String?> requestAccountDeletion(String uid) async {
    final result = await _repository.requestAccountDeletion(uid);
    return result.fold((f) => f.message, (_) => null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserEntity?>(
  AuthController.new,
);
