import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_theme_palette.dart';

/// الأسماء الثلاثة هنا مطابقة حرفيًا لما تُرجعه get_login_visual_variant()
/// على الخادم — هو من يقرر الترتيب الدوري (لا عشوائي)، لا التطبيق.
enum LoginVisualVariant {
  atelier,
  royal,
  modern;

  static LoginVisualVariant fromServer(String? key) => switch (key) {
        'royal' => LoginVisualVariant.royal,
        'modern' => LoginVisualVariant.modern,
        _ => LoginVisualVariant.royal,
      };
}

class LoginVariantStyle {
  final String backgroundAsset;
  final AppThemePalette palette;
  final String tagline;
  final String heading;
  final String subtitle;
  final List<(IconData, String)> features;

  /// ⚠️ لم يعد مُستخدَمًا: كان إخفاء/إظهار زر Apple يتبع الطراز البصري
  /// المتناوب عشوائيًا، فيظهر الزر ويختفي بين زيارة وأخرى بلا أي منطق.
  /// ظهور Apple الآن يتبع المنصة الفعلية داخل SocialLoginRow وحدها.
  /// أُبقي الحقل هنا فقط لتفادي كسر بنية الطرز الثلاثة القائمة.
  final bool showAppleButton;
  final bool defaultRememberMe;

  const LoginVariantStyle({
    required this.backgroundAsset,
    required this.palette,
    required this.tagline,
    required this.heading,
    required this.subtitle,
    required this.features,
    required this.showAppleButton,
    required this.defaultRememberMe,
  });
}

/// ثلاث لوحات ألوان مخصَّصة لتناوب شاشة الدخول تحديدًا — منفصلة عمدًا عن
/// الأربع لوحات العامة القابلة للاختيار من المستخدم بعد الدخول
/// (app_theme_palette.dart)، فهذه تدور تلقائيًا بأمر الخادم، لا باختيار
/// المستخدم، ولكل تصميم منها هوية لونية مطابقة لصورته الأصلية.
const _atelierPalette = AppThemePalette(
  id: 'login_atelier',
  nameAr: 'الورشة',
  icon: Icons.content_cut,
  accent: Color(0xFF8B4B9C),
  accentMuted: Color(0xFF6B2C7A),
  accentBright: Color(0xFFC084D4),
  secondary: Color(0xFF4A1942),
  secondaryBright: Color(0xFF6B2C5F),
  background: Color(0xFF1A0F1C),
  surface: Color(0xFF241326),
  surfaceElevated: Color(0xFF2E1930),
  surfaceHighlight: Color(0xFF3A1F3D),
  textPrimary: Color(0xFFFDF6FA),
  textSecondary: Color(0xFFD8C2DE),
  textMuted: Color(0xFF9B85A3),
  divider: Color(0xFF3A2A3D),
  error: Color(0xFFE0716A),
  success: Color(0xFF54B98C),
  warning: Color(0xFFE0B06D),
);

const _royalPalette = AppThemePalette(
  id: 'login_royal',
  nameAr: 'الملكي',
  icon: Icons.diamond_outlined,
  accent: Color(0xFFD4AF37),
  accentMuted: Color(0xFFB8944A),
  accentBright: Color(0xFFF1D07A),
  secondary: Color(0xFF141833),
  secondaryBright: Color(0xFF232B57),
  background: Color(0xFF0A0C1C),
  surface: Color(0xFF11142A),
  surfaceElevated: Color(0xFF181C36),
  surfaceHighlight: Color(0xFF212642),
  textPrimary: Color(0xFFFAF6E8),
  textSecondary: Color(0xFFC9C2A3),
  textMuted: Color(0xFF807A5F),
  divider: Color(0xFF2A2E4A),
  error: Color(0xFFE0716A),
  success: Color(0xFF54B98C),
  warning: Color(0xFFE0B06D),
);

const _modernPalette = AppThemePalette(
  id: 'login_modern',
  nameAr: 'العصري',
  icon: Icons.auto_awesome,
  accent: Color(0xFFE84393),
  accentMuted: Color(0xFF9B59B6),
  accentBright: Color(0xFFFF9EC4),
  secondary: Color(0xFF3D1E52),
  secondaryBright: Color(0xFF5B2C7A),
  background: Color(0xFF190E22),
  surface: Color(0xFF23142E),
  surfaceElevated: Color(0xFF2D1B3A),
  surfaceHighlight: Color(0xFF3A2248),
  textPrimary: Color(0xFFFDF3FA),
  textSecondary: Color(0xFFD4B8DE),
  textMuted: Color(0xFF9885A3),
  divider: Color(0xFF3D2A4A),
  error: Color(0xFFE0716A),
  success: Color(0xFF54B98C),
  warning: Color(0xFFE0B06D),
);

const Map<LoginVisualVariant, LoginVariantStyle> loginVariantStyles = {
  LoginVisualVariant.atelier: LoginVariantStyle(
    backgroundAsset: 'assets/login_variants/login_bg_1.png',
    palette: _atelierPalette,
    tagline: 'مشاريعنا … بخيوط النجاح',
    heading: 'مرحبًا بك في مشاريعنا',
    subtitle: 'منصة تجمع محبي الخياطة والتصميم والإبداع',
    showAppleButton: false,
    defaultRememberMe: false,
    features: [
      (Icons.content_cut, 'خدمات الخياطة'),
      (Icons.groups_outlined, 'مجتمع المبدعين'),
      (Icons.storefront_outlined, 'متجر المنتجات'),
      (Icons.lightbulb_outline, 'فرص العمل'),
    ],
  ),
  LoginVisualVariant.royal: LoginVariantStyle(
    backgroundAsset: 'assets/login_variants/login_bg_3.png',
    palette: _royalPalette,
    tagline: 'مشاريعنا … تصنع مستقبلك',
    heading: 'مرحبًا بك في مشاريعنا',
    subtitle: 'منصة متكاملة لعالم الخياطة والأزياء',
    showAppleButton: true,
    defaultRememberMe: false,
    features: [
      (Icons.checkroom_outlined, 'تصميم وتفصيل'),
      (Icons.groups_outlined, 'مجتمع المبدعين'),
      (Icons.storefront_outlined, 'متجر الأدوات والمواد'),
      (Icons.school_outlined, 'تعلم وتطوير'),
      (Icons.auto_awesome_outlined, 'فرص وإعلانات'),
    ],
  ),
  LoginVisualVariant.modern: LoginVariantStyle(
    backgroundAsset: 'assets/login_variants/login_bg_2.png',
    palette: _modernPalette,
    tagline: 'أهلاً بك في مشاريعنا',
    heading: 'أهلاً بك في مشاريعنا',
    subtitle: 'ابدأ رحلتك في عالم الموضة والإبداع',
    showAppleButton: false,
    defaultRememberMe: true,
    features: [
      (Icons.checkroom_outlined, 'تصميم وتفصيل'),
      (Icons.groups_outlined, 'مجتمع المبدعين'),
      (Icons.storefront_outlined, 'متجر المنتجات'),
      (Icons.lightbulb_outline, 'فرص العمل'),
    ],
  ),
};

/// يستدعي الدالة الخادمية مرة واحدة لكل ظهور لشاشة الدخول — الخادم وحده
/// يقرر أي تصميم يظهر الآن عبر عدّاد دوري ذري (لا عشوائي، ولا يتكرر منطقه
/// محليًا)، فيبقى الترتيب صحيحًا حتى مع تعدد الأجهزة والجلسات في آن واحد.
final loginVisualVariantProvider =
    FutureProvider.autoDispose<LoginVisualVariant>((ref) async {
  try {
    final result =
        await Supabase.instance.client.rpc('get_login_visual_variant');
    return LoginVisualVariant.fromServer(result?.toString());
  } catch (_) {
    return LoginVisualVariant.royal;
  }
});
