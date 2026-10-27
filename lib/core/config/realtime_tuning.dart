import 'dart:math' as math;

/// ضبط سرعة تحديث البيانات في مكان واحد.
///
/// المطلوب: تحديث بين 100 و400 مللي ثانية. هذا المدى يُطبَّق على المزامنة
/// التفاعلية (مباريات التركس، دعوات الطاولات، عدّادات الدردشة) — أي كل ما
/// يراه المستخدم يتغيّر أمامه لحظيًا.
///
/// ما لا يُطبَّق عليه المدى عن قصد: نبضات الحضور (presence heartbeat كل
/// 30/45 ثانية) ولوحات الصدارة (كل 5 دقائق). خفضها إلى 200ms يضرب الخادم
/// بأكثر من 200 ضعف الكتابات بلا أي فائدة للمستخدم، ويستهلك حصّة Supabase.
/// السرعة المطلوبة تُخدَم بالمزامنة اللحظية (Realtime) + الاستطلاع السريع
/// أدناه، لا بتسريع النبضات.
class RealtimeTuning {
  const RealtimeTuning._();

  /// الحد الأدنى والأقصى المسموحان (حاجز أمان: لا شيء يخرج عن 100–400ms).
  static const int minMs = 100;
  static const int maxMs = 400;

  /// أسرع نبضة: دور اللاعب الآن، أو هناك حركة/تأثير جارٍ.
  static const Duration hot = Duration(milliseconds: 120);

  /// النبضة الاعتيادية أثناء مباراة جارية.
  static const Duration active = Duration(milliseconds: 220);

  /// نبضة الخمول: الشاشة مفتوحة بلا تفاعل مباشر.
  static const Duration idle = Duration(milliseconds: 400);

  /// عدّاد الواجهة (مؤقّتات تنازلية، أشرطة تقدّم) — محلي بلا شبكة.
  static const Duration uiClock = Duration(milliseconds: 200);

  /// يحصر أي قيمة داخل المدى المسموح.
  static Duration clamp(Duration d) => Duration(
        milliseconds: math.max(minMs, math.min(maxMs, d.inMilliseconds)),
      );

  /// يختار النبضة المناسبة حسب حالة الشاشة.
  static Duration pick({required bool myTurn, required bool animating}) {
    if (myTurn || animating) return hot;
    return active;
  }
}
