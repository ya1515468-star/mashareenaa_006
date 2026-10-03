/// تُرمى فقط من طبقة Data (DataSources) ثم تُلتقط داخل الـ Repository
/// Implementation وتُحوَّل إلى Failure مناسب، حتى لا تعرف طبقة
/// Domain شيئًا عن Supabase أو أي مصدر بيانات خارجي.
library;

class ServerException implements Exception {
  final String message;
  final String? code;
  const ServerException({required this.message, this.code});

  @override
  String toString() => code == null ? message : '$message (code: $code)';
}

class AuthException implements Exception {
  final String message;
  final String? code;
  const AuthException({required this.message, this.code});
}

class PermissionException implements Exception {
  final String message;
  final String? code;
  const PermissionException({required this.message, this.code});
}

class AccountStatusException implements Exception {
  final String message;
  final String? code;
  const AccountStatusException({required this.message, this.code});
}
