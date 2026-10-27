import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إعداد المواضع كما يضبطه المالك.
///
/// يُستعمل للتخطيط وحده (كم عنصرًا بين خانة وخانة): السياسة تبقى
/// خادمية، فلو تجاهله عميلٌ وطلب إعلانًا لموضع أغلقه المالك لم يُعطَ
/// شيئًا. ولذلك لا ضرر في تخزينه، ولا نفع في التلاعب به.
final adPlacementsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final raw = await Supabase.instance.client.rpc('get_ad_placements');
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  } catch (_) {
    return const {};
  }
});

/// كم عنصرًا بين خانة وخانة في هذا الموضع، و0 إن كان مغلقًا.
///
/// الصفر يعني «لا تُدرِج خانة إطلاقًا»، فتوفّر على القائمة بناءً
/// ونداءً لا طائل منه.
int adEveryN(Map<String, dynamic> config, String placement) {
  final p = config[placement];
  if (p is! Map) return 0;
  if (p['enabled'] != true) return 0;
  final n = (p['every_n'] as num?)?.toInt() ?? 0;
  return n < 1 ? 0 : n;
}

/// خانة إعلان مدفوع.
///
/// كل القرار خادمي: `ad_serve` هو من يختار ما يُعرض — يُرشِّح المنتهي
/// والموقوف ومن بلغ سقفه، ويطبّق الاستهداف بالمدينة والمهنة، ولا يعرض
/// إعلانًا على صاحبه، ويحدّ التكرار بمرّتين لكل عضو في اليوم. العميل لا
/// يُرشِّح شيئًا ولا يعرف عن إعلان لم يُعطَه.
///
/// والظهور لا يُحتسَب إلّا برمز يصدره الخادم مع الإعلان ويُستهلك مرّة
/// واحدة: فلا يستطيع عميل أن ينفخ عدّاد منافس ولا أن يستنزف سقفه.
/// ويُحتسَب عند **الظهور الفعلي على الشاشة** لا عند الجلب، فإعلان
/// جُلب ولم يُرَ لا يُحاسَب عليه المعلن.
class ServedAdSlot extends StatefulWidget {
  const ServedAdSlot({
    super.key,
    required this.placement,
    this.height = 92,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.onOpen,
    this.fullPage = false,
  });

  /// موضع العرض، يُسجَّل في الإحصاء ليعرف المالك أيّ موضع يُجدي.
  final String placement;
  final double height;
  final EdgeInsets margin;

  /// ما يُفعَل عند النقر. الاحتساب يحدث دائمًا قبل هذا.
  final void Function(Map<String, dynamic> ad)? onOpen;

  /// صفحة كاملة لا شريط: سوق المنتجين عرضٌ رأسي بملء الشاشة، فشريط
  /// صغير بينه وبين الريلات يبدو عطلًا في التخطيط لا إعلانًا.
  final bool fullPage;

  @override
  State<ServedAdSlot> createState() => _ServedAdSlotState();
}

class _ServedAdSlotState extends State<ServedAdSlot> {
  Map<String, dynamic>? _ad;
  bool _counted = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('ad_serve', params: {'p_placement': widget.placement, 'p_limit': 1});
      final rows = raw is List ? raw.whereType<Map>().toList() : const [];
      if (!mounted) return;
      setState(() {
        _ad = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
        _gone = rows.isEmpty;
      });
    } catch (_) {
      // لا إعلان أهون من خانة عاطلة تُظهر خطأ للمستخدم.
      if (mounted) setState(() => _gone = true);
    }
  }

  Future<void> _countImpression() async {
    final ad = _ad;
    if (_counted || ad == null) return;
    _counted = true; // قبل النداء: تمرير ثانٍ سريع لا يُرسل مرّتين
    try {
      await Supabase.instance.client
          .rpc('ad_record_impression', params: {'p_token': ad['token']});
    } catch (_) {
      // الخادم يرفض الرمز المستهلك أو المنتهي من نفسه؛ لا شيء يُصحَّح هنا.
    }
  }

  Future<void> _click() async {
    final ad = _ad;
    if (ad == null) return;
    try {
      await Supabase.instance.client
          .rpc('ad_record_click', params: {'p_token': ad['token']});
    } catch (_) {}
    widget.onOpen?.call(ad);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_gone || ad == null) return const SizedBox.shrink();

    final image = ad['image_url']?.toString() ?? '';

    if (widget.fullPage) {
      return VisibilityCounter(
        onVisible: _countImpression,
        child: GestureDetector(
          onTap: _click,
          child: Container(
            color: const Color(0xFF0B0718),
            child: Stack(fit: StackFit.expand, children: [
              if (image.isNotEmpty)
                Image.network(image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              // تعتيم متدرّج: النصّ يجب أن يُقرأ فوق أي صورة يرفعها
              // المعلن، فاتحةً كانت أو غامقة.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('إعلان ممول',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 10),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          ad['text']?.toString() ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.6,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return VisibilityCounter(
      onVisible: _countImpression,
      child: Padding(
        padding: widget.margin,
        child: InkWell(
          onTap: _click,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF1A1030),
              border: Border.all(color: const Color(0x66FFD700)),
            ),
            child: Row(children: [
              if (image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(image,
                      width: widget.height - 20,
                      height: widget.height - 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الشفافية مطلوبة: محتوى مدفوع يجب أن يُعرَف أنّه كذلك.
                    const Text('إعلان ممول',
                        style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      ad['text']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ينادي [onVisible] مرّة واحدة عند أول ظهور فعلي للطفل على الشاشة.
///
/// بلا هذا يُحتسَب الظهور لحظة الجلب، فإعلان في آخر قائمة لم يُمرَّر
/// إليها أبدًا يُخصم من سقف المعلن ولا يراه أحد.
class VisibilityCounter extends StatefulWidget {
  const VisibilityCounter({super.key, required this.child, required this.onVisible});

  final Widget child;
  final VoidCallback onVisible;

  @override
  State<VisibilityCounter> createState() => _VisibilityCounterState();
}

class _VisibilityCounterState extends State<VisibilityCounter> {
  bool _fired = false;
  Timer? _poll;
  int _visibleTicks = 0;

  /// لماذا مؤقِّت لا NotificationListener: إشعارات التمرير تصعد من
  /// Scrollable نحو الجذر، والخانة طفلٌ له — فمستمعٌ داخلها لا يبلغه
  /// إشعار أبدًا. والفحص الدوري يعمل كذلك إن لم يكن حولها تمرير أصلًا.
  static const _tick = Duration(milliseconds: 400);
  static const _ticksToCount = 3; // ~1.2 ثانية ثابتة
  static const _giveUpAfter = Duration(seconds: 90);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_tick, (t) => _check(t));
    Timer(_giveUpAfter, () {
      // خانة لم تُرَ خلال دقيقة ونصف: لا داعي لإبقاء مؤقِّت يعمل.
      if (!_fired) _poll?.cancel();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _check(Timer t) {
    if (_fired) {
      t.cancel();
      return;
    }
    if (!mounted) {
      t.cancel();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      _visibleTicks = 0;
      return;
    }

    final screen = MediaQuery.of(context).size;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    // نصف الخانة على الأقل داخل الشاشة: حدّ يمنع احتساب ما لمس حافّتها
    // أثناء تمرير سريع.
    final shown = (bottom.clamp(0.0, screen.height) -
            top.clamp(0.0, screen.height)) >=
        box.size.height / 2;

    if (!shown) {
      _visibleTicks = 0;
      return;
    }
    if (++_visibleTicks < _ticksToCount) return;

    _fired = true;
    t.cancel();
    widget.onVisible();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// يُحوّل عدد عناصر القائمة إلى عدد صفوفها بعد دسّ خانات الإعلان،
/// ويترجم موضع الصفّ إلى «إعلان» أو «العنصر رقم كذا».
///
/// لماذا مُشترَك: خمس قوائم تدسّ خانات بالتردّد نفسه الذي يضبطه
/// المالك. حسابُ الفهرس في كل قائمة على حدة يعني خمس نسخ من منطق
/// واحد — وخطأ ±1 في إحداها يُظهر عنصرًا مرّتين أو يُخفي آخر.
class AdInterleave {
  const AdInterleave._(this.everyN, this.itemCount);

  /// [everyN] = 0 يُلغي الدسّ تمامًا (موضع مغلق).
  factory AdInterleave(int everyN, int itemCount) =>
      AdInterleave._(everyN < 1 ? 0 : everyN, itemCount);

  final int everyN;
  final int itemCount;

  /// عدد الخانات المدسوسة: واحدة بعد كل [everyN] عنصرًا، ولا تُدَسّ
  /// خانة بعد آخر عنصر (إعلان يُذيّل القائمة بلا محتوى بعده مزعج).
  int get adCount =>
      everyN == 0 || itemCount <= everyN ? 0 : (itemCount - 1) ~/ everyN;

  int get rowCount => itemCount + adCount;

  /// هل هذا الصفّ خانة إعلان؟
  bool isAd(int row) {
    if (everyN == 0) return false;
    // المواضع: everyN, 2*everyN+1, 3*everyN+2 … (يتقدّم بواحد لكل خانة سبقته)
    return row > 0 && (row + 1) % (everyN + 1) == 0;
  }

  /// فهرس العنصر الحقيقي المقابل لهذا الصفّ.
  int itemIndex(int row) => everyN == 0 ? row : row - ((row + 1) ~/ (everyN + 1));
}
