import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/error/failures.dart';

/// يحوّل الرصيد بين نقاط الزد والجواهر عبر دالة خادمية ذرّية واحدة.
///
/// ⚠️ كان هذا الملف يستدعي spendPoints ثم creditGems كعمليتين منفصلتين
/// تمامًا — وbcreditGems/creditPoints يمرّان فعليًا عبر dragon_credit_gems/
/// dragon_credit_points وهما حصريتان للمالك (DRAGON_ONLY). النتيجة: أي
/// مستخدم عادي يحاول التحويل من إعدادات حسابه كان يخسر نقاطه فعليًا (الخصم
/// ينجح) بلا أي جواهر في المقابل (الإضافة تُرفض) — عطل مالي نشط حقيقي على
/// شاشة متاحة فعليًا. الإصلاح: دالة خادمية واحدة (exchange_points_for_gems/
/// exchange_gems_for_points) تُنفّذ الخصم والإضافة في معاملة واحدة ذرّية —
/// إمّا أن ينجح كلاهما معًا أو لا يحدث شيء إطلاقًا، ومعدّل الصرف يُقرأ من
/// gamification_config الحقيقي على الخادم، لا من ثابت في التطبيق.
class PointsGemsExchangeService {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// يحوّل [points] نقطة إلى جواهر بمعدّل الصرف الحقيقي من الخادم.
  Future<Either<Failure, int>> convertPointsToGems({
    required String uid,
    required int points,
    required bool unlimited,
  }) async {
    try {
      final raw = await _sb.rpc('exchange_points_for_gems', params: {
        'p_points': points,
        'p_idempotency_key': const Uuid().v4(),
      });
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return Right((data['gems_credited'] as num?)?.toInt() ?? 0);
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        String m when m.contains('INSUFFICIENT_POINTS') => 'رصيد النقاط غير كافٍ.',
        String m when m.contains('BELOW_MINIMUM_EXCHANGE') => 'المبلغ أقل من الحد الأدنى للتحويل.',
        _ => e.message,
      };
      return Left(ValidationFailure(message: message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// يحوّل [gems] جوهرة إلى نقاط بمعدّل الصرف الحقيقي من الخادم.
  Future<Either<Failure, int>> convertGemsToPoints({
    required String uid,
    required int gems,
    required bool unlimited,
  }) async {
    try {
      final raw = await _sb.rpc('exchange_gems_for_points', params: {
        'p_gems': gems,
        'p_idempotency_key': const Uuid().v4(),
      });
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return Right((data['points_credited'] as num?)?.toInt() ?? 0);
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        String m when m.contains('INSUFFICIENT_GEMS') => 'رصيد الجواهر غير كافٍ.',
        _ => e.message,
      };
      return Left(ValidationFailure(message: message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
