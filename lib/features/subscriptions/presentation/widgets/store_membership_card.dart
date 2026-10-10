import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../store/presentation/widgets/store_preview.dart';
import '../../domain/entities/subscription_tier_entity.dart';

/// بطاقة عضوية في المتجر.
///
/// أُعيد بناؤها بلغة سوق المنتجين البصرية: خلفية داكنة، ذهبي
/// #FFD700، ووهج متحرك عند حافة العضوية المفعّلة.
///
/// وصارت أصغر بكثير: كانت الشارة 92×92 والحشوة 16 والخط 18 فتملأ
/// البطاقةُ الواحدة نصفَ الشاشة؛ الآن 56×56 وحشوة 11 وخط 14.5،
/// فتُرى أربع بطاقات دفعة واحدة بدل واحدة ونصف.
///
/// الشارة تُحلّ بالترتيب: صورة يرفعها المالك ← الإيموجي ← صورة
/// المستوى الافتراضية. كان الخيار الوحيد سابقًا هو ⭐ بلا بديل.
class StoreMembershipCard extends StatefulWidget {
  final SubscriptionTierEntity tier;
  final String? currentTierId;
  final bool ownerMode;
  final VoidCallback? onPurchase;
  final String? priceText;
  final VoidCallback? onGift;
  final VoidCallback? onEditPrice;
  final VoidCallback? onDelete;

  /// يفتح مُنتقي صورة الشارة — للمالك وحده.
  final VoidCallback? onChangeBadge;

  const StoreMembershipCard({
    super.key,
    required this.tier,
    this.currentTierId,
    required this.ownerMode,
    this.onPurchase,
    this.priceText,
    this.onGift,
    this.onEditPrice,
    this.onDelete,
    this.onChangeBadge,
  });

  @override
  State<StoreMembershipCard> createState() => _StoreMembershipCardState();
}

class _StoreMembershipCardState extends State<StoreMembershipCard>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);
  static const _amber = Color(0xFFFFA500);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.tier.badge.color;
    final active = widget.currentTierId == widget.tier.id;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = (math.sin(_c.value * math.pi) + 1) / 2;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
            ),
            border: Border.all(
              color: active
                  ? _gold.withValues(alpha: .45 + glow * .35)
                  : tierColor.withValues(alpha: .28),
              width: active ? 1.6 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _gold.withValues(alpha: glow * .3),
                        blurRadius: 14)
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(tierColor, glow),
                    const SizedBox(width: 10),
                    Expanded(child: _info(tierColor, active)),
                  ],
                ),
                if (widget.tier.hasOneTimeGrants) ...[
                  const SizedBox(height: 8),
                  _grants(),
                ],
                const SizedBox(height: 9),
                _actions(active),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badge(Color tierColor, double glow) {
    final img = widget.tier.badge.imageUrl;
    final emoji = widget.tier.badge.emoji;

    Widget inner;
    if (img != null && img.trim().isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(img,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(emoji)),
      );
    } else if (emoji.trim().isNotEmpty) {
      inner = _fallback(emoji);
    } else {
      inner = StoreGifPreview(
          assetPath: _assetForTier(widget.tier.id), alt: widget.tier.name);
    }

    final badge = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: tierColor.withValues(alpha: .4 + glow * .25)),
      ),
      child: inner,
    );

    if (!widget.ownerMode || widget.onChangeBadge == null) return badge;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          bottom: -5,
          right: -5,
          child: GestureDetector(
            onTap: widget.onChangeBadge,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5)],
              ),
              child: const Icon(Icons.photo_camera_rounded,
                  size: 13, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback(String emoji) => Center(
      child: Text(emoji.isEmpty ? '👑' : emoji,
          style: const TextStyle(fontSize: 27)));

  Widget _info(Color tierColor, bool active) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(widget.tier.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              if (active) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _amber]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('مفعّلة',
                      style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.black,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text((widget.priceText?.isNotEmpty ?? false) ? widget.priceText! : widget.tier.price.formatted,
              style: TextStyle(
                  color: tierColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          Text(
              '${widget.tier.durationDays} يوم · مكافأة ×${widget.tier.dailyRewardMultiplier}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
      );

  Widget _grants() => Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          if (widget.tier.pointsGranted > 0)
            _chip('⭐ ${widget.tier.pointsGranted}'),
          if (widget.tier.gemsGranted > 0)
            _chip('💎 ${widget.tier.gemsGranted}'),
          if (widget.tier.grantedCosmeticKeys.isNotEmpty)
            _chip('🎨 ${widget.tier.grantedCosmeticKeys.length}'),
          if (widget.tier.grantedAnimationKeys.isNotEmpty)
            _chip('🐾 ${widget.tier.grantedAnimationKeys.length}'),
        ],
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _gold.withValues(alpha: .28)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10.5, color: _gold, fontWeight: FontWeight.w700)),
      );

  Widget _actions(bool active) {
    if (widget.ownerMode) {
      return Row(
        children: [
          _iconBtn(
              Icons.dashboard_customize_outlined, 'تعديل', widget.onEditPrice),
          _iconBtn(Icons.delete_outline, 'حذف', widget.onDelete,
              color: AppColors.error),
          const Spacer(),
          _smallBtn('إهداء', Icons.card_giftcard_rounded, widget.onGift,
              filled: false),
          const SizedBox(width: 6),
          _smallBtn(active ? 'مفعّلة' : 'منح', Icons.storefront_rounded,
              active ? null : widget.onPurchase),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: _smallBtn(
          active ? 'عضويتك الحالية' : 'اشترك الآن',
          active ? Icons.check_rounded : Icons.shopping_cart_rounded,
          active ? null : widget.onPurchase),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback? onTap,
          {Color? color}) =>
      IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color ?? Colors.white54),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(),
      );

  Widget _smallBtn(String label, IconData icon, VoidCallback? onTap,
      {bool filled = true}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: filled && enabled
              ? const LinearGradient(colors: [_gold, _amber])
              : null,
          color: filled && enabled ? null : Colors.white10,
          border: Border.all(
              color: enabled
                  ? _gold.withValues(alpha: filled ? 0 : .45)
                  : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color: filled && enabled ? Colors.black : Colors.white60),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: filled && enabled ? Colors.black : Colors.white60)),
          ],
        ),
      ),
    );
  }
}

String _assetForTier(String id) {
  switch (id) {
    case 'bronze':
      return 'assets/store_gifs/membership/membership_01.gif';
    case 'silver':
      return 'assets/store_gifs/membership/membership_06.gif';
    case 'gold':
      return 'assets/store_gifs/membership/membership_11.gif';
    case 'diamond':
      return 'assets/store_gifs/membership/membership_16.gif';
    case 'royal':
      return 'assets/store_gifs/membership/membership_21.gif';
    case 'vip':
      return 'assets/store_gifs/membership/membership_26.gif';
    case 'legendary':
      return 'assets/store_gifs/membership/membership_31.gif';
    default:
      return 'assets/store_gifs/membership/membership_11.gif';
  }
}
