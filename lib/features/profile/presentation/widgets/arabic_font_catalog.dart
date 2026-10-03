import 'package:flutter/material.dart';

/// Opt-in decorative Arabic fonts. They are used only for user content:
/// username, status and chat messages. Unknown/empty values use platform default.
String? localArabicFontFamily(String? key) {
  switch (key?.trim().toLowerCase()) {
    case 'decorative_amiri':
      return 'MashareenaAmiri';
    case 'decorative_naskh':
      return 'MashareenaNaskh';
    case 'decorative_kufi':
      return 'MashareenaKufi';
    // System-installed families. These add ZERO bytes to the app (no font
    // files bundled), which is why they were chosen — the requirement was
    // more choices without inflating the build size. They fall back to the
    // platform default automatically on any device that lacks them.
    case 'sys_tahoma':
      return 'Tahoma';
    case 'sys_arial':
      return 'Arial';
    case 'sys_times':
      return 'Times New Roman';
    case 'sys_segoe':
      return 'Segoe UI';
    case 'sys_georgia':
      return 'Georgia';
    case 'sys_verdana':
      return 'Verdana';
    case 'sys_trebuchet':
      return 'Trebuchet MS';
    case 'sys_courier':
      return 'Courier New';
    case 'system_default':
      return null;
    default:
      return null;
  }
}

class ArabicFontOption {
  final String key;
  final String nameAr;
  const ArabicFontOption(this.key, this.nameAr);

  TextStyle style({double size = 18, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFamily: localArabicFontFamily(key),
      );
}

const kArabicFontOptions = <ArabicFontOption>[
  ArabicFontOption('system_default', 'افتراضي النظام'),
  ArabicFontOption('decorative_amiri', 'أميري — كلاسيكي أنيق'),
  ArabicFontOption('decorative_naskh', 'نسخ — زخرفي'),
  ArabicFontOption('decorative_kufi', 'كوفي — فاخر'),
  // 4 additional Arabic-capable system families
  ArabicFontOption('sys_tahoma', 'تاهوما — واضح'),
  ArabicFontOption('sys_arial', 'أريال — بسيط'),
  ArabicFontOption('sys_times', 'تايمز — رسمي'),
  ArabicFontOption('sys_segoe', 'سيجو — عصري'),
  // 4 additional Latin families
  ArabicFontOption('sys_georgia', 'Georgia — إنجليزي كلاسيكي'),
  ArabicFontOption('sys_verdana', 'Verdana — إنجليزي واضح'),
  ArabicFontOption('sys_trebuchet', 'Trebuchet — إنجليزي أنيق'),
  ArabicFontOption('sys_courier', 'Courier — إنجليزي آلة كاتبة'),
];

ArabicFontOption arabicFontOption(String key) =>
    kArabicFontOptions.firstWhere(
      (option) => option.key == key,
      orElse: () => kArabicFontOptions.first,
    );
