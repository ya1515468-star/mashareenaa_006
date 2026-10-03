import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_palette.dart';

const _kThemePaletteKey = 'selected_theme_palette_id';

/// يدير الثيم الفاخر المختار حاليًا، ويطبَّق فورًا على كامل التطبيق
/// عبر [MashareenaApp] لأن كل الشاشات تقرأ الألوان من Theme.of
/// (context) وليس من AppColors الثابت مباشرة. يُحفظ الاختيار محليًا
/// ليبقى بعد إغلاق التطبيق.
class ThemeController extends Notifier<AppThemePalette> {
  @override
  AppThemePalette build() {
    _restore();
    return AppThemePalette.goldLuxury;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kThemePaletteKey);
    if (savedId != null) {
      state = AppThemePalette.byId(savedId);
    }
  }

  Future<void> selectPalette(AppThemePalette palette) async {
    state = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePaletteKey, palette.id);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemePalette>(
  ThemeController.new,
);
