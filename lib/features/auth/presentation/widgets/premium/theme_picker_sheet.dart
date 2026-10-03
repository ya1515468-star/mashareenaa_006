import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_theme_palette.dart';
import '../../../../../core/theme/theme_controller.dart';

/// ورقة سفلية لاختيار الثيم الفاخر — تُستدعى من أيقونة صغيرة أعلى
/// شاشتي الدخول/التسجيل. الاختيار يُطبَّق فورًا على كامل التطبيق
/// (عبر [themeControllerProvider]) ويُحفظ محليًا.
class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ThemePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: p.divider, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'اختر ثيمك الفاخر',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final palette in AppThemePalette.all)
                _PaletteSwatch(
                  palette: palette,
                  selected: palette.id == current.id,
                  onTap: () => ref
                      .read(themeControllerProvider.notifier)
                      .selectPalette(palette),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteSwatch(
      {required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? palette.accent : palette.divider,
              width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: palette.accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [palette.accentMuted, palette.accentBright]),
              ),
              child: Icon(palette.icon, size: 18, color: palette.background),
            ),
            const SizedBox(height: 8),
            Text(
              palette.nameAr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: palette.textPrimary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle, size: 14, color: palette.accent),
            ],
          ],
        ),
      ),
    );
  }
}
