import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  نموذج ثيم فاخر كامل — بديل عن [AppColors] الثابت القديم
///  • يدعم 4 ثيمات جاهزة: ذهبي / زمردي / ياقوتي / وردي
///  • قابل للتوسيع بإضافة ثيمات جديدة
///  • معرف فريد (id) لكل ثيم لسهولة الحفظ في SharedPreferences
/// ═══════════════════════════════════════════════════════════════
class AppThemePalette {
  // ─── المعرّف والعرض ───
  final String id;
  final String nameAr;
  final IconData icon;

  // ─── اللون المميز (Primary) ───
  final Color accent;
  final Color accentMuted;
  final Color accentBright;

  // ─── اللون الثانوي (Secondary) ───
  final Color secondary;
  final Color secondaryBright;

  // ─── خلفيات ودواخل ───
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;

  // ─── النصوص ───
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // ─── فواصل وحالات ───
  final Color divider;
  final Color error;
  final Color success;
  final Color warning;

  const AppThemePalette({
    required this.id,
    required this.nameAr,
    required this.icon,
    required this.accent,
    required this.accentMuted,
    required this.accentBright,
    required this.secondary,
    required this.secondaryBright,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.error,
    required this.success,
    required this.warning,
  });

  /// ───────────────────────────────────────────────────────────
  ///  الثيم الافتراضي — الذهبي الفاخر
  /// ───────────────────────────────────────────────────────────
  static const AppThemePalette goldLuxury = AppThemePalette(
    id: 'gold_luxury',
    nameAr: 'الذهبي الفاخر',
    icon: Icons.diamond_outlined,
    accent: Color(0xFFD4AF37),
    accentMuted: Color(0xFFB8944A),
    accentBright: Color(0xFFF1D07A),
    secondary: Color(0xFF7A1F3D),
    secondaryBright: Color(0xFFA23A5C),
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF15141A),
    surfaceElevated: Color(0xFF1E1C24),
    surfaceHighlight: Color(0xFF28242E),
    textPrimary: Color(0xFFF5F1E8),
    textSecondary: Color(0xFFAFA79A),
    textMuted: Color(0xFF6E6A63),
    divider: Color(0xFF2A2830),
    error: Color(0xFFCF6679),
    success: Color(0xFF3FA377),
    warning: Color(0xFFE0A96D),
  );

  /// ───────────────────────────────────────────────────────────
  ///  الزمردي الليلي (Emerald Noir)
  /// ───────────────────────────────────────────────────────────
  static const AppThemePalette emeraldNoir = AppThemePalette(
    id: 'emerald_noir',
    nameAr: 'الزمردي الليلي',
    icon: Icons.eco_outlined,
    accent: Color(0xFF2FBF8E),
    accentMuted: Color(0xFF279E76),
    accentBright: Color(0xFF7FE3BC),
    secondary: Color(0xFF14483C),
    secondaryBright: Color(0xFF1F6E5A),
    background: Color(0xFF08100D),
    surface: Color(0xFF10201A),
    surfaceElevated: Color(0xFF162B23),
    surfaceHighlight: Color(0xFF1D372D),
    textPrimary: Color(0xFFEFF7F2),
    textSecondary: Color(0xFFA4BDB2),
    textMuted: Color(0xFF63776E),
    divider: Color(0xFF223A30),
    error: Color(0xFFE0716A),
    success: Color(0xFF52D19A),
    warning: Color(0xFFE0C36D),
  );

  /// ───────────────────────────────────────────────────────────
  ///  الياقوتي الليلي (Sapphire Midnight)
  /// ───────────────────────────────────────────────────────────
  static const AppThemePalette sapphireMidnight = AppThemePalette(
    id: 'sapphire_midnight',
    nameAr: 'الياقوتي الليلي',
    icon: Icons.nightlight_outlined,
    accent: Color(0xFF3E7BFA),
    accentMuted: Color(0xFF3560C4),
    accentBright: Color(0xFF8FB2FF),
    secondary: Color(0xFF241B57),
    secondaryBright: Color(0xFF3B2C86),
    background: Color(0xFF07080F),
    surface: Color(0xFF10131F),
    surfaceElevated: Color(0xFF161B2B),
    surfaceHighlight: Color(0xFF1E2438),
    textPrimary: Color(0xFFEEF1FB),
    textSecondary: Color(0xFFA6ACC4),
    textMuted: Color(0xFF636B87),
    divider: Color(0xFF232B44),
    error: Color(0xFFE07A87),
    success: Color(0xFF4FBE8F),
    warning: Color(0xFFE0A96D),
  );

  /// ───────────────────────────────────────────────────────────
  ///  الذهبي الوردي (Rose Gold)
  /// ───────────────────────────────────────────────────────────
  static const AppThemePalette roseGold = AppThemePalette(
    id: 'rose_gold',
    nameAr: 'الذهبي الوردي',
    icon: Icons.local_florist_outlined,
    accent: Color(0xFFE0A0A8),
    accentMuted: Color(0xFFC7818C),
    accentBright: Color(0xFFF3C7CD),
    secondary: Color(0xFF4A2530),
    secondaryBright: Color(0xFF6E3B49),
    background: Color(0xFF0C0808),
    surface: Color(0xFF171112),
    surfaceElevated: Color(0xFF211819),
    surfaceHighlight: Color(0xFF2C2021),
    textPrimary: Color(0xFFF8EFEE),
    textSecondary: Color(0xFFC0A6A5),
    textMuted: Color(0xFF7A6362),
    divider: Color(0xFF332525),
    error: Color(0xFFE0716A),
    success: Color(0xFF54B98C),
    warning: Color(0xFFE0B06D),
  );

  /// ───────────────────────────────────────────────────────────
  ///  كل الثيمات المتاحة
  /// ───────────────────────────────────────────────────────────
  static const List<AppThemePalette> all = [
    goldLuxury,
    emeraldNoir,
    sapphireMidnight,
    roseGold,
  ];

  /// البحث بالمعرّف (مع fallback)
  static AppThemePalette byId(String id) {
    final found = all.where((p) => p.id == id);
    if (found.isEmpty) return goldLuxury;
    return found.first;
  }

  /// البحث بالاسم العربي
  static AppThemePalette? byName(String nameAr) {
    for (final p in all) {
      if (p.nameAr == nameAr) return p;
    }
    return null;
  }

  /// نسخ الـ Palette مع تغيير بعض الحقول
  AppThemePalette copyWith({
    String? id,
    String? nameAr,
    IconData? icon,
    Color? accent,
    Color? accentMuted,
    Color? accentBright,
    Color? secondary,
    Color? secondaryBright,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? error,
    Color? success,
    Color? warning,
  }) {
    return AppThemePalette(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      icon: icon ?? this.icon,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      accentBright: accentBright ?? this.accentBright,
      secondary: secondary ?? this.secondary,
      secondaryBright: secondaryBright ?? this.secondaryBright,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppThemePalette && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppThemePalette($id, $nameAr)';
}
