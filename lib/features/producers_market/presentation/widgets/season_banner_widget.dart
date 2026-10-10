import 'package:flutter/material.dart';
import '../../domain/entities/producer_reel_entity.dart';

/// بانر الموسم — يظهر في أعلى سوق المنتجين
/// المالك يتحكم بعنوانه، تاريخه، خلفيته، وصورة GIF الموسمية (ثلوج/شمس)
/// التأثيرات البصرية مطابقة لتأثيرات اسم المستخدم (shimmer، glow)
class SeasonBannerWidget extends StatelessWidget {
  final MarketSeasonBannerEntity banner;
  final Animation<double> shimmerAnim;
  final Animation<double> glowAnim;
  final bool isOwner;
  final VoidCallback? onEdit;

  const SeasonBannerWidget({
    super.key,
    required this.banner,
    required this.shimmerAnim,
    required this.glowAnim,
    required this.isOwner,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ─── خلفية البانر ─────────────────────────────────────────
        Container(
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A0A2A), Color(0xFF1A0540), Color(0xFF0A1A40)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            ),
            image: banner.backgroundUrl != null
                ? DecorationImage(
                    image: NetworkImage(banner.backgroundUrl!),
                    fit: BoxFit.cover,
                    opacity: 0.35,
                  )
                : null,
          ),
          child: Stack(
            children: [
              // ─── GIF الموسمي (ثلوج/شمس) يتساقط فوق الكل ───────
              if (banner.seasonGifUrl != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: 0.65,
                      child: banner.seasonGifUrl!.startsWith('http')
                          ? Image.network(
                              banner.seasonGifUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            )
                          : Image.asset(
                              banner.seasonGifUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                    ),
                  ),
                ),

              // ─── العنوان مع تأثير shimmer ─────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: shimmerAnim,
                      builder: (context, child) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: const [
                            Color(0xFFFFD700),
                            Color(0xFFFFF8DC),
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                            Color(0xFFFFD700),
                          ],
                          stops: [
                            0.0,
                            (shimmerAnim.value - 0.15).clamp(0.0, 1.0),
                            shimmerAnim.value.clamp(0.0, 1.0),
                            (shimmerAnim.value + 0.15).clamp(0.0, 1.0),
                            1.0,
                          ],
                        ).createShader(bounds),
                        child: child,
                      ),
                      child: AnimatedBuilder(
                        animation: glowAnim,
                        builder: (context, child) => Text(
                          banner.title ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: glowAnim.value * 0.9),
                                blurRadius: 16 * glowAnim.value,
                              ),
                              Shadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: glowAnim.value * 0.5),
                                blurRadius: 32 * glowAnim.value,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (banner.date != null && banner.date!.isNotEmpty)
                      Text(
                        banner.date!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── زر التعديل (للمالك) ─────────────────────────────────
        if (isOwner && onEdit != null)
          Positioned(
            top: 8,
            left: 16,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        color: Color(0xFFFFD700), size: 13),
                    SizedBox(width: 4),
                    Text('تعديل',
                        style: TextStyle(
                            color: Color(0xFFFFD700), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
