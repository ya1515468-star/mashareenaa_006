import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../entities/pattern_enums.dart';

/// يُرسل طلب باترون عبر دالة خادمية ذرّية واحدة (submit_pattern_request):
/// تقرأ السعر الحقيقي الحالي من app_config/pattern_studio وقت التنفيذ فعليًا
/// (لا وقت عرضه للمستخدم فقط، فقد يتغيّر السعر بينهما)، تخصم من رصيد
/// المستخدم، وتُنشئ سجل الطلب — كل ذلك معًا أو لا شيء منه إطلاقًا.
///
/// كانت هذه العملية سابقًا خطوتين منفصلتين (خصم عبر WalletRepository.debit،
/// ثم إنشاء الطلب) — فشل الخطوة الثانية بعد نجاح الأولى كان يترك المستخدم
/// خاسرًا للمال بلا أي طلب مقابل. كما اكتُشف أثناء الفحص أن WalletRepository
/// .debit نفسه كان معطّلاً كليًا لأي مستخدم عادي (معامل targetUid مفقود،
/// وقيد صلاحية إدارية كان يمنع حتى خصم النفس) — أُصلح ذلك في wallet_operation
/// مباشرة، لكن هذه الميزة تجاوزت المسار القديم كليًا الآن لتفادي أي طبقة
/// وسيطة إضافية.
class SubmitPatternRequestUseCase {
  const SubmitPatternRequestUseCase();

  Future<Either<Failure, void>> call({
    required String uid,
    required String sourceImageUrl,
    required MannequinType mannequinType,
    String? notes,
  }) async {
    try {
      await Supabase.instance.client.rpc('submit_pattern_request', params: {
        'p_source_image_url': sourceImageUrl,
        'p_mannequin_type': mannequinType.wire,
        'p_notes': notes,
        'p_idempotency_key': const Uuid().v4(),
      });
      return const Right(null);
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        String m when m.contains('INSUFFICIENT_BALANCE') => 'رصيدك لا يكفي لإتمام هذا الطلب.',
        String m when m.contains('FEATURE_DISABLED') => 'هذه الميزة غير مفعّلة حاليًا',
        _ => e.message,
      };
      final isPermission = message.contains('غير مفعّلة');
      return Left(isPermission
          ? PermissionFailure(message: message)
          : ValidationFailure(message: message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
