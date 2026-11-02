import 'package:equatable/equatable.dart';

/// حالة الحساب — تُفحص عند كل تسجيل دخول وعند كل إجراء حساس.
enum AccountStatus { active, suspended, banned, deleted }

extension AccountStatusX on AccountStatus {
  String get wire => name;

  static AccountStatus fromWire(String? s) => AccountStatus.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => AccountStatus.active,
      );
}

/// كيان المستخدم كما تراه طبقة Domain. لا يحتوي على أي تفاصيل خاصة
/// بـ Supabase، فقط البيانات الجوهرية التي تحتاجها بقية الوحدات.
class UserEntity extends Equatable {
  final String uid;
  final String email;
  final bool emailVerified;
  final AccountStatus status;
  final DateTime createdAt;

  /// حساب زائر (مجهول) لم يُرقَّ ببريد مؤكَّد بعد.
  ///
  /// لماذا هنا: الزائر بلا بريد إطلاقًا، فـ[emailVerified] تساوي false
  /// عنده دائمًا. وبوّابة تأكيد البريد في AppRouter كانت ترسله إلى شاشة
  /// «أدخل الرمز المُرسَل إلى بريدك» — لبريد غير موجود — فيعلق هناك ولا
  /// يصل التطبيق أبدًا. هذا الحقل يميّز «بلا بريد قصدًا» عن «بريد غير
  /// مؤكَّد»، فتبقى البوّابة سارية على الثاني وحده.
  final bool isGuest;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.status,
    required this.createdAt,
    this.isGuest = false,
  });

  @override
  List<Object?> get props =>
      [uid, email, emailVerified, status, createdAt, isGuest];
}
