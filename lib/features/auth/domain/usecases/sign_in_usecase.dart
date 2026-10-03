import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// بعد نجاح المصادقة، يتحقق من حالة الحساب في store. حساب موقوف
/// أو محظور أو محذوف يُرفض دخوله فورًا برسالة واضحة، رغم أن بيانات
/// اعتماده صحيحة — هذا يطابق متطلب "التحقق من حالة الحظر أو
/// التعطيل" في تسلسل تشغيل التطبيق.
class SignInUseCase {
  final AuthRepository repository;

  const SignInUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call(SignInParams params) async {
    final signInResult =
        await repository.signIn(email: params.email, password: params.password);

    if (signInResult.isLeft()) {
      return signInResult.fold(
          (failure) => Left(failure), (user) => Right(user));
    }

    final user = signInResult.getOrElse(() => throw StateError('unreachable'));

    if (user.status != AccountStatus.active) {
      await repository.signOut();
      return Left(AccountStatusFailure(message: _messageFor(user.status)));
    }

    return Right(user);
  }

  String _messageFor(AccountStatus status) {
    switch (status) {
      case AccountStatus.suspended:
        return 'حسابك موقوف مؤقتًا. تواصل مع الدعم الفني لمزيد من التفاصيل.';
      case AccountStatus.banned:
        return 'تم حظر هذا الحساب بشكل دائم.';
      case AccountStatus.deleted:
        return 'هذا الحساب تم حذفه.';
      case AccountStatus.active:
        return '';
    }
  }
}
