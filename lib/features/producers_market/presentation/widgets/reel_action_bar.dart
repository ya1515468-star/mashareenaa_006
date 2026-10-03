import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/producer_reel_entity.dart';

/// شريط تفاعل الريل الجانبي — مثل TikTok
/// إعجاب، تعليق، حفظ، مشاركة، تحميل
class ReelActionBar extends StatelessWidget {
  final ProducerReelEntity reel;
  final Animation<double> glowAnim;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  const ReelActionBar({
    super.key,
    required this.reel,
    required this.glowAnim,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: reel.isLikedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: reel.isLikedByMe
              ? const Color(0xFFFF3B5C)
              : Colors.white,
          count: reel.likes,
          label: 'إعجاب',
          onTap: () {
            HapticFeedback.lightImpact();
            onLike();
          },
          glowAnim: glowAnim,
          glowColor: const Color(0xFFFF3B5C),
          glow: reel.isLikedByMe,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          count: reel.comments,
          label: 'تعليق',
          onTap: onComment,
          glowAnim: glowAnim,
          glowColor: const Color(0xFF64B5F6),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: reel.isSavedByMe
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: reel.isSavedByMe
              ? const Color(0xFFFFD700)
              : Colors.white,
          count: reel.saves,
          label: 'حفظ',
          onTap: () {
            HapticFeedback.lightImpact();
            onSave();
          },
          glowAnim: glowAnim,
          glowColor: const Color(0xFFFFD700),
          glow: reel.isSavedByMe,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          count: reel.shares,
          label: 'مشاركة',
          onTap: onShare,
          glowAnim: glowAnim,
          glowColor: const Color(0xFF81C784),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.download_rounded,
          color: Colors.white,
          count: null,
          label: 'تحميل',
          onTap: onDownload,
          glowAnim: glowAnim,
          glowColor: const Color(0xFF9C88FF),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final String label;
  final VoidCallback onTap;
  final Animation<double> glowAnim;
  final Color glowColor;
  final bool glow;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.onTap,
    required this.glowAnim,
    required this.glowColor,
    this.glow = false,
  });

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: glowAnim,
            builder: (context, child) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black26,
                boxShadow: glow
                    ? [
                        BoxShadow(
                          color: glowColor
                              .withValues(alpha: glowAnim.value * 0.7),
                          blurRadius: 14,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              _format(count!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
