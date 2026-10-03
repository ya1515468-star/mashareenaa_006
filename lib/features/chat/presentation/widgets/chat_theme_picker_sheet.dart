import 'dart:async';

import 'package:flutter/material.dart';

class ChatThemeDefinition {
  final String id;
  final String name;
  final String backgroundKey;
  final List<Color> gradient;
  final Color bubbleMine;
  final Color bubbleOther;
  final Color accent;
  final IconData icon;

  const ChatThemeDefinition({
    required this.id,
    required this.name,
    required this.backgroundKey,
    required this.gradient,
    required this.bubbleMine,
    required this.bubbleOther,
    required this.accent,
    required this.icon,
  });

  static const List<ChatThemeDefinition> all = [
    ChatThemeDefinition(
      id: 'royal_dark',
      name: 'ملكي داكن',
      backgroundKey: 'aurora',
      gradient: [Color(0xFF0D0617), Color(0xFF24103A), Color(0xFF0B0815)],
      bubbleMine: Color(0xFF6F26A0),
      bubbleOther: Color(0xFF32203D),
      accent: Color(0xFFC86BFF),
      icon: Icons.auto_awesome_rounded,
    ),
    ChatThemeDefinition(
      id: 'midnight_blue',
      name: 'ليلي أزرق',
      backgroundKey: 'midnight',
      gradient: [Color(0xFF06101C), Color(0xFF0B2741), Color(0xFF050B14)],
      bubbleMine: Color(0xFF1F5D91),
      bubbleOther: Color(0xFF18303F),
      accent: Color(0xFF64C8FF),
      icon: Icons.nights_stay_rounded,
    ),
    ChatThemeDefinition(
      id: 'emerald_night',
      name: 'زمردي',
      backgroundKey: 'emerald',
      gradient: [Color(0xFF061510), Color(0xFF0A342A), Color(0xFF050D0A)],
      bubbleMine: Color(0xFF13765B),
      bubbleOther: Color(0xFF17382F),
      accent: Color(0xFF5FE4B3),
      icon: Icons.eco_rounded,
    ),
    ChatThemeDefinition(
      id: 'rose_velvet',
      name: 'مخمل وردي',
      backgroundKey: 'rose',
      gradient: [Color(0xFF1A0913), Color(0xFF4A1730), Color(0xFF12070E)],
      bubbleMine: Color(0xFF9B3166),
      bubbleOther: Color(0xFF402036),
      accent: Color(0xFFFF80B8),
      icon: Icons.favorite_rounded,
    ),
    ChatThemeDefinition(
      id: 'golden_lounge',
      name: 'صالون ذهبي',
      backgroundKey: 'gold',
      gradient: [Color(0xFF171108), Color(0xFF3B2A08), Color(0xFF0D0A06)],
      bubbleMine: Color(0xFF80611A),
      bubbleOther: Color(0xFF382B13),
      accent: Color(0xFFFFD36A),
      icon: Icons.workspace_premium_rounded,
    ),
    ChatThemeDefinition(
      id: 'carbon',
      name: 'كربوني',
      backgroundKey: 'carbon',
      gradient: [Color(0xFF08090B), Color(0xFF1B1E23), Color(0xFF07080A)],
      bubbleMine: Color(0xFF3D434C),
      bubbleOther: Color(0xFF20242A),
      accent: Color(0xFFBFC7D2),
      icon: Icons.grid_4x4_rounded,
    ),
  ];

  static ChatThemeDefinition byId(String? id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => all.first,
    );
  }
}

class ChatThemePickerSheet extends StatelessWidget {
  final String selectedId;
  final Future<void> Function(ChatThemeDefinition theme) onSelected;

  const ChatThemePickerSheet({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String selectedId,
    required Future<void> Function(ChatThemeDefinition theme) onSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 760,
            maxHeight: MediaQuery.of(dialogContext).size.height * .82,
          ),
          child: ChatThemePickerSheet(
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF120C1B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x663E1B50))),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.wallpaper_rounded, color: Color(0xFFE0A8FF)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ثيمات الشات والخلفية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: ChatThemeDefinition.all.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.68,
                ),
                itemBuilder: (_, index) {
                  final theme = ChatThemeDefinition.all[index];
                  final selected = theme.id == selectedId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      unawaited(onSelected(theme));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: theme.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: selected ? theme.accent : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: theme.accent.withValues(alpha: .26),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ]
                            : const [],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: .08),
                                  border: Border.all(
                                    color: theme.accent.withValues(alpha: .7),
                                  ),
                                ),
                                child: Icon(theme.icon,
                                    color: theme.accent, size: 18),
                              ),
                              const Spacer(),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: theme.accent, size: 20),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            theme.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _BubblePreview(color: theme.bubbleMine),
                              const SizedBox(width: 5),
                              _BubblePreview(color: theme.bubbleOther),
                              const Spacer(),
                              Text(
                                'حفظ تلقائي',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .62),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubblePreview extends StatelessWidget {
  final Color color;
  const _BubblePreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class ChatThemeBackground extends StatelessWidget {
  final ChatThemeDefinition theme;
  final Widget child;

  /// عند رفع خلفية للغرفة، يجب أن تظهر الصورة نفسها ولا يُرسم فوقها تدرّج
  /// الثيم ونقشه — وإلا حجباها تمامًا. مع true تُلغى طبقتا التدرّج والنقش
  /// ويبقى المحتوى (فقاعات الرسائل) وحده فوق الصورة.
  final bool transparent;

  const ChatThemeBackground({
    super.key,
    required this.theme,
    required this.child,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (transparent) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
              child: CustomPaint(
                  painter: _PatternPainter(theme.backgroundKey, theme.accent))),
          child,
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final String keyName;
  final Color accent;

  const _PatternPainter(this.keyName, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: .07);

    if (keyName == 'carbon') {
      const step = 24.0;

      for (double x = -size.height; x < size.width + size.height; x += step) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          paint,
        );

        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
    }

    if (keyName == 'midnight' || keyName == 'aurora') {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: .07);

      for (var i = 0; i < 18; i++) {
        final x = (i * 67.0) % size.width;
        final y = (i * 113.0) % size.height;

        canvas.drawCircle(
          Offset(x, y),
          2.2 + (i % 3),
          fillPaint,
        );
      }
    }

    if (keyName == 'emerald' || keyName == 'rose' || keyName == 'gold') {
      final spacing = keyName == 'gold' ? 44.0 : 56.0;

      for (double y = -size.height; y < size.height * 2; y += spacing) {
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * .18,
            y,
            size.width * .64,
            spacing * .85,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.keyName != keyName || oldDelegate.accent != accent;
  }
}
