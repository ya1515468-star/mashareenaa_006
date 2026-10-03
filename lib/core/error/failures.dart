import 'package:equatable/equatable.dart';

/// الفئة الأساسية لكل أنواع الفشل في التطبيق. كل Failure جديد في أي
/// Feature يرث من هذه الفئة حتى تبقى معالجة الأخطاء موحدة عبر كل
/// وحدات المشروع (Auth, RBAC, Profile، وما سيُضاف لاحقًا).
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'لا يوجد اتصال بالإنترنت', super.code});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// فشل ناتج عن عدم امتلاك المستخدم الصلاحية اللازمة — يُستخدم من
/// وحدة RBAC ويُعاد استخدامه من كل الوحدات الأخرى عند التوسع.
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'لا تملك الصلاحية الكافية لتنفيذ هذا الإجراء',
    super.code,
  });
}

/// فشل خاص بحالة الحساب (محظور/موقوف/محذوف) — يُتحقق منه عند كل
/// عملية دخول وعند كل إجراء حساس.
class AccountStatusFailure extends Failure {
  const AccountStatusFailure({required super.message, super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(
      {super.message = 'العنصر المطلوب غير موجود', super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'حدث خطأ غير متوقع', super.code});
}
