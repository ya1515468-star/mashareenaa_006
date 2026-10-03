import '../../../../core/data/supabase_document_compat.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/domain/repositories/username_credential_repository.dart';
import '../repositories/gamification_repository.dart';

/// ميزة 4 من القائمة الإضافية: نظام إحالة (دعوة صديق) — يُطبَّق فقط
/// بعد تأكيد بريد العضو الجديد إلكترونيًا (وليس عند التسجيل مباشرة)
/// لمنع إساءة الاستخدام بحسابات وهمية غير مفعَّلة.
class ApplyReferralUseCase {
  final UsernameCredentialRepository usernameCredentialRepository;
  final GamificationRepository gamificationRepository;

  static const int referrerBonusPoints = 150;
  static const int newMemberBonusPoints = 50;

  const ApplyReferralUseCase({
    required this.usernameCredentialRepository,
    required this.gamificationRepository,
  });

  Future<void> call(
      {required String referrerUsername, required String newMemberUid}) async {
    if (referrerUsername.trim().isEmpty) return;

    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('applyReferral')
          .call({
        'referrerUsername': referrerUsername.trim(),
        'requestId': const Uuid().v4(),
      });
    } on SupabaseFunctionException {
      return;
    }
  }
}
