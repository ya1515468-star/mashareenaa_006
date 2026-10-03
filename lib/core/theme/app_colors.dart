import 'package:flutter/material.dart';

/// لوحة ألوان "Dark Luxury" — الثيم الموحّد الوحيد للتطبيق بأكمله
/// (لا يوجد وضع فاتح منفصل؛ الفخامة الداكنة هي الهوية البصرية
/// الرسمية لمشاريعنا). أسود دافئ + ذهبي + عنابي عميق.
class AppColors {
  AppColors._();

  // الذهبي — اللون المميز الأساسي (العناوين، الأزرار، الحدود المضيئة)
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldMuted = Color(0xFFB8944A);
  static const Color goldBright = Color(0xFFF1D07A);

  // العنابي العميق — اللون الثانوي (تمييز، شارات VIP)
  static const Color burgundy = Color(0xFF7A1F3D);
  static const Color burgundyBright = Color(0xFFA23A5C);

  // الأسود الدافئ — خلفيات متدرجة العمق
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF15141A);
  static const Color surfaceElevated = Color(0xFF1E1C24);
  static const Color surfaceHighlight = Color(0xFF28242E);

  // النصوص
  static const Color textPrimary = Color(0xFFF5F1E8);
  static const Color textSecondary = Color(0xFFAFA79A);
  static const Color textMuted = Color(0xFF6E6A63);

  static const Color divider = Color(0xFF2A2830);

  // حالات
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF3FA377);
  static const Color warning = Color(0xFFE0A96D);

  // اسمان قديمان يُبقيان للتوافق مع الكود الحالي دون تعديل كل ملف
  // يستخدمهما — يشيران الآن لنفس هوية Dark Luxury.
  static const Color primary = gold;
  static const Color primaryDark = goldMuted;
  static const Color secondary = burgundy;
  static const Color backgroundDark = background;
  static const Color surfaceDark = surface;
  static const Color textPrimaryDark = textPrimary;
}
