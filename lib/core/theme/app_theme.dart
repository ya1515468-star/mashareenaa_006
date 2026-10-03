// ignore_for_file: prefer_const_declarations, deprecated_member_use

import 'package:flutter/material.dart';
import 'app_theme_palette.dart';

/// ═══════════════════════════════════════════════════════════════
///  بنّاء ThemeData من أي [AppThemePalette]
///  • كل الشاشات القديمة تبقى تعمل (AppTheme.luxury)
///  • الشاشات الجديدة تستخدم [AppTheme.fromPalette]
///  • يستخدم التطبيق خطوط Flutter والمنصة الافتراضية
/// ═══════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  /// الثيم الافتراضي الفاخر (للتوافق الخلفي)
  static ThemeData get luxury => fromPalette(AppThemePalette.goldLuxury);

  /// بناء ThemeData من أي Palette
  static ThemeData fromPalette(AppThemePalette p) {
    // ─── أنماط النصوص ───
    TextStyle localBodyFont({
      Color? color,
      FontWeight? fontWeight,
      double? fontSize,
      double? letterSpacing,
    }) => TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
        );

    final headingStyle = TextStyle(
      color: p.accentBright,
      fontWeight: FontWeight.bold,
    );
    final bodyFont = localBodyFont;

    final textTheme = TextTheme(
      titleLarge: headingStyle.copyWith(fontSize: 24, letterSpacing: 0.4),
      titleMedium: bodyFont(
        color: p.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      titleSmall: bodyFont(
        color: p.accentBright,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: bodyFont(color: p.textPrimary, fontSize: 15),
      bodyMedium: bodyFont(color: p.textPrimary, fontSize: 14),
      bodySmall: bodyFont(color: p.textSecondary, fontSize: 12),
      labelLarge: bodyFont(
        color: p.textPrimary,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelMedium: bodyFont(color: p.textSecondary, fontSize: 12),
      labelSmall: bodyFont(color: p.textMuted, fontSize: 11),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.divider,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: p.surfaceHighlight.withValues(alpha: 0.3),
      focusColor: p.accent.withValues(alpha: 0.2),
      highlightColor: p.accent.withValues(alpha: 0.1),
      // ─── نظام الألوان الموحّد ───
      colorScheme: ColorScheme.dark(
        primary: p.accent,
        onPrimary: p.background,
        primaryContainer: p.accent.withValues(alpha: 0.2),
        onPrimaryContainer: p.accentBright,
        secondary: p.secondary,
        onSecondary: p.textPrimary,
        secondaryContainer: p.secondary.withValues(alpha: 0.2),
        onSecondaryContainer: p.textPrimary,
        tertiary: p.accentBright,
        onTertiary: p.background,
        error: p.error,
        onError: Colors.white,
        errorContainer: p.error.withValues(alpha: 0.15),
        onErrorContainer: p.error,
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerHighest: p.surfaceElevated,
        surfaceContainerHigh: p.surfaceElevated,
        surfaceContainer: p.surface,
        surfaceContainerLow: p.background,
        surfaceContainerLowest: p.background,
        outline: p.divider,
        outlineVariant: p.divider.withValues(alpha: 0.5),
        shadow: Colors.black,
        scrim: Colors.black87,
        inverseSurface: p.textPrimary,
        onInverseSurface: p.background,
        inversePrimary: p.accentBright,
      ),

      // ─── امتداد ThemeExtension لحمل الـ Palette الكاملة ───
      extensions: [AppPaletteExtension(palette: p)],

      // ─── أنماط النصوص ───
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ─── AppBar ───
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.accent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: headingStyle.copyWith(fontSize: 19, letterSpacing: 0.5),
        iconTheme: IconThemeData(color: p.accentBright),
        actionsIconTheme: IconThemeData(color: p.accentBright),
        surfaceTintColor: Colors.transparent,
      ),

      // ─── البطاقات ───
      cardTheme: CardThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.divider),
        ),
      ),

      // ─── الرقاقات (Chips) ───
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHighlight,
        selectedColor: p.accent,
        disabledColor: p.surfaceHighlight.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: p.background, fontSize: 12),
        side: BorderSide(color: p.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        showCheckmark: false,
      ),

      // ─── الأزرار ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.background,
          disabledBackgroundColor: p.surfaceHighlight,
          disabledForegroundColor: p.textMuted,
          // كان Size.fromHeight(52) = عرض أدنى لانهائي. أي زر يُوضع داخل
          // Row/Wrap/trailing في أي شاشة كان يطلب عرضًا لا نهائيًا فينهار
          // التخطيط (BoxConstraints(w=Infinity, 44<=h) — 44 لأن الويب يطرح
          // كثافة compact من 52). هذا هو السبب الجذري لانهيار لوحة الإدارة
          // وصفوف الشات؛ الأزرار التي تريد عرضًا كاملًا تلفّها SizedBox.
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 14,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent, width: 1.2),
          // كان Size.fromHeight(52) = عرض أدنى لانهائي. أي زر يُوضع داخل
          // Row/Wrap/trailing في أي شاشة كان يطلب عرضًا لا نهائيًا فينهار
          // التخطيط (BoxConstraints(w=Infinity, 44<=h) — 44 لأن الويب يطرح
          // كثافة compact من 52). هذا هو السبب الجذري لانهيار لوحة الإدارة
          // وصفوف الشات؛ الأزرار التي تريد عرضًا كاملًا تلفّها SizedBox.
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentBright,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.background,
          // كان Size.fromHeight(52) = عرض أدنى لانهائي. أي زر يُوضع داخل
          // Row/Wrap/trailing في أي شاشة كان يطلب عرضًا لا نهائيًا فينهار
          // التخطيط (BoxConstraints(w=Infinity, 44<=h) — 44 لأن الويب يطرح
          // كثافة compact من 52). هذا هو السبب الجذري لانهيار لوحة الإدارة
          // وصفوف الشات؛ الأزرار التي تريد عرضًا كاملًا تلفّها SizedBox.
          minimumSize: const Size(64, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.accentBright,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ─── حقول الإدخال ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textMuted),
        helperStyle: TextStyle(color: p.textMuted, fontSize: 11),
        errorStyle: TextStyle(color: p.error, fontSize: 11),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      // ─── شريط التنقل السفلي ───
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.accent,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: p.textPrimary, fontSize: 11),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: p.accent);
          }
          return IconThemeData(color: p.textMuted);
        }),
        elevation: 0,
        height: 64,
      ),

      // ─── الأيقونات ───
      iconTheme: IconThemeData(color: p.textSecondary),
      primaryIconTheme: IconThemeData(color: p.accent),

      // ─── SnackBars ───
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 14),
        actionTextColor: p.accentBright,
        disabledActionTextColor: p.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ─── الحوارات ───
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: headingStyle.copyWith(
          fontSize: 20,
          color: p.accentBright,
        ),
        contentTextStyle: bodyFont(color: p.textPrimary, fontSize: 14),
      ),

      // ─── القوائم ───
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: bodyFont(color: p.textPrimary, fontSize: 13),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // ─── أشرطة التمرير ───
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        circularTrackColor: p.surfaceHighlight,
        linearTrackColor: p.surfaceHighlight,
        linearMinHeight: 6,
      ),

      // ─── الفواصل ───
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 0.8,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: bodyFont(color: p.textPrimary, fontSize: 14),
        subtitleTextStyle: bodyFont(color: p.textSecondary, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ─── التبويبات ───
      tabBarTheme: TabBarThemeData(
        labelColor: p.accentBright,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
      ),

      // ─── التبديل ───
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.accentBright;
          return p.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.accent.withValues(alpha: 0.4);
          }
          return p.surfaceHighlight;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(p.background),
        side: BorderSide(color: p.divider, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return p.textMuted;
        }),
      ),

      // ─── Sliders ───
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceHighlight,
        thumbColor: p.accentBright,
        overlayColor: p.accent.withValues(alpha: 0.2),
        valueIndicatorColor: p.accent,
      ),

      // ─── Tooltip ───
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.divider),
        ),
        textStyle: bodyFont(color: p.textPrimary, fontSize: 12),
        preferBelow: true,
      ),

      // ─── إعدادات عامة ───
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // اسمان قديمان للتوافق الخلفي (main.dart كان يستخدم light/dark منفصلين)
  static ThemeData get light => luxury;
  static ThemeData get dark => luxury;
}

/// ═══════════════════════════════════════════════════════════════
///  ThemeExtension لحمل الـ Palette الكاملة
/// ═══════════════════════════════════════════════════════════════
class AppPaletteExtension extends ThemeExtension<AppPaletteExtension> {
  final AppThemePalette palette;

  const AppPaletteExtension({required this.palette});

  @override
  AppPaletteExtension copyWith({AppThemePalette? palette}) {
    return AppPaletteExtension(palette: palette ?? this.palette);
  }

  @override
  AppPaletteExtension lerp(
      ThemeExtension<AppPaletteExtension>? other, double t) {
    if (other is! AppPaletteExtension) return this;
    return t < 0.5 ? this : other;
  }

  @override
  Object get type => AppPaletteExtension;
}

/// ═══════════════════════════════════════════════════════════════
///  اختصار للوصول للـ Palette من أي BuildContext
/// ═══════════════════════════════════════════════════════════════
extension AppPaletteX on BuildContext {
  AppThemePalette get palette =>
      Theme.of(this).extension<AppPaletteExtension>()?.palette ??
      AppThemePalette.goldLuxury;
}
