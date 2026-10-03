import 'package:flutter/material.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/gift_transaction_entity.dart';

/// طبقة عرض متحركة ملء-الشاشة تظهر مؤقتًا فوق أي شاشة عند استلام
/// هدية كبيرة — على طراز رسوم "الأسد/الحوت" الشهيرة في تطبيقات
/// البث المباشر: الإيموجي يكبر بارتداد (bounce) ثم يتزحلق أفقيًا مع
/// اسم المُرسِل، مصحوبًا بجزيئات بريق خلفية، ثم يتلاشى تلقائيًا.
/// الهدايا الصغيرة/المتوسطة لا تُشغّل هذه الطبقة إطلاقًا (تظهر فقط
/// كفقاعة عادية في الدردشة) — التفعيل فقط لـ big/epic/legendary.
class GiftAnimationOverlay {
  static OverlayEntry? _current;

  static void showIfEligible(
    BuildContext context, {
    required GiftTransactionEntity transaction,
    required String fromDisplayName,
  }) {
    final gift = transaction.gift;
    if (gift == null) return;
    if (gift.tier == GiftTier.small || gift.tier == GiftTier.medium) return;

    _current?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _GiftAnimationWidget(
        gift: gift,
        fromDisplayName: fromDisplayName,
        onFinished: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _GiftAnimationWidget extends StatefulWidget {
  final GiftEntity gift;
  final String fromDisplayName;
  final VoidCallback onFinished;

  const _GiftAnimationWidget({
    required this.gift,
    required this.fromDisplayName,
    required this.onFinished,
  });

  @override
  State<_GiftAnimationWidget> createState() => _GiftAnimationWidgetState();
}

class _GiftAnimationWidgetState extends State<_GiftAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _slide;
  late final Animation<double> _opacity;

  bool get _isLegendary => widget.gift.tier == GiftTier.legendary;

  @override
  void initState() {
    super.initState();
    final duration = Duration(milliseconds: _isLegendary ? 4200 : 3000);
    _controller = AnimationController(vsync: this, duration: duration)
      ..forward().whenComplete(widget.onFinished);

    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.25)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 10),
    ]).animate(_controller);

    _slide = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic)),
    );

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value.clamp(0, 1),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              color: Colors.black.withValues(alpha: 0.25 * _opacity.value),
              child: FractionalTranslation(
                translation: Offset(_slide.value, 0),
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.gift.emoji,
                          style: TextStyle(fontSize: _isLegendary ? 140 : 100)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.fromDisplayName} أرسل ${widget.gift.nameAr} 🎉',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
