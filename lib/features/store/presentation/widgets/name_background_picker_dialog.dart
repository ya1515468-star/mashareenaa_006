import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../gamification/domain/entities/username_effect.dart';
import '../../../gamification/presentation/widgets/username_cosmetic_name.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Backing catalog items. The server only honours user-chosen colors for
/// items whose metadata sets `user_customizable`, so every selection in this
/// dialog is saved against one of these three (all unisex):
const String _kSolidItemKey = 'namebg_custom_solid';
const String _kDualItemKey = 'namebg_custom_dual';
const String _kEmptyItemKey = 'namebg_empty_interior';

/// A single swatch: one color (solid fill) or two (manually merged gradient).
class _Swatch {
  final Color c1;
  final Color? c2;
  const _Swatch(this.c1, [this.c2]);
  bool get isDual => c2 != null;
}

/// Tab 1 — لون: classic flat colors, black first (it was missing entirely
/// from every picker in the app before this).
const List<_Swatch> _kSolidColors = [
  _Swatch(Color(0xFF000000)), _Swatch(Color(0xFF7F1D1D)), _Swatch(Color(0xFFE30613)), _Swatch(Color(0xFFF97316)),
  _Swatch(Color(0xFFD4AF37)), _Swatch(Color(0xFFFFD740)), _Swatch(Color(0xFF808000)), _Swatch(Color(0xFF16A34A)),
  _Swatch(Color(0xFF065F46)), _Swatch(Color(0xFF2DD4BF)), _Swatch(Color(0xFF06B6D4)), _Swatch(Color(0xFF38BDF8)),
  _Swatch(Color(0xFF2563EB)), _Swatch(Color(0xFF0B1B3F)), _Swatch(Color(0xFF4338CA)), _Swatch(Color(0xFF7C3AED)),
  _Swatch(Color(0xFFC4B5FD)), _Swatch(Color(0xFFEC4899)), _Swatch(Color(0xFF800020)), _Swatch(Color(0xFFFF7F50)),
  _Swatch(Color(0xFF78350F)), _Swatch(Color(0xFF6B7280)), _Swatch(Color(0xFFC0C0C0)), _Swatch(Color(0xFFFFFFFF)),
];

/// Tab 2 — نيون: bright, high-saturation colors.
const List<_Swatch> _kNeonColors = [
  _Swatch(Color(0xFFFF1744)), _Swatch(Color(0xFFFF5252)), _Swatch(Color(0xFFFF6D00)), _Swatch(Color(0xFFFFAB00)),
  _Swatch(Color(0xFFFFFF00)), _Swatch(Color(0xFFC6FF00)), _Swatch(Color(0xFF76FF03)), _Swatch(Color(0xFF00E676)),
  _Swatch(Color(0xFF00FF8A)), _Swatch(Color(0xFF1DE9B6)), _Swatch(Color(0xFF00E5FF)), _Swatch(Color(0xFF00B0FF)),
  _Swatch(Color(0xFF2979FF)), _Swatch(Color(0xFF3D5AFE)), _Swatch(Color(0xFF651FFF)), _Swatch(Color(0xFF7C4DFF)),
  _Swatch(Color(0xFFD500F9)), _Swatch(Color(0xFFFF00E5)), _Swatch(Color(0xFFF50057)), _Swatch(Color(0xFFFF4081)),
  _Swatch(Color(0xFFFF80AB)), _Swatch(Color(0xFFB388FF)), _Swatch(Color(0xFF64FFDA)), _Swatch(Color(0xFFEEFF41)),
];

/// Tab 3 — خلفية: ready-made two-color merges (saved as a real dual
/// background, exactly like a manual merge).
const List<_Swatch> _kGradients = [
  _Swatch(Color(0xFF000000), Color(0xFFD4AF37)), _Swatch(Color(0xFF7F1D1D), Color(0xFFFF6D00)),
  _Swatch(Color(0xFF0B1B3F), Color(0xFF00E5FF)), _Swatch(Color(0xFF4338CA), Color(0xFFEC4899)),
  _Swatch(Color(0xFF7C3AED), Color(0xFF00E5FF)), _Swatch(Color(0xFF16A34A), Color(0xFFEEFF41)),
  _Swatch(Color(0xFF06B6D4), Color(0xFF7C4DFF)), _Swatch(Color(0xFFE30613), Color(0xFFFFD740)),
  _Swatch(Color(0xFF000000), Color(0xFFC0C0C0)), _Swatch(Color(0xFF800020), Color(0xFFFF80AB)),
  _Swatch(Color(0xFF065F46), Color(0xFF00FF8A)), _Swatch(Color(0xFF78350F), Color(0xFFFFAB00)),
  _Swatch(Color(0xFF2563EB), Color(0xFF00B0FF)), _Swatch(Color(0xFFFF1744), Color(0xFF7C3AED)),
  _Swatch(Color(0xFF1DE9B6), Color(0xFF2979FF)), _Swatch(Color(0xFFD500F9), Color(0xFFFFD740)),
];

/// Tab 4 — آخر: muted / neutral / pastel extras.
const List<_Swatch> _kOtherColors = [
  _Swatch(Color(0xFF3E2723)), _Swatch(Color(0xFF5D4037)), _Swatch(Color(0xFF8D6E63)), _Swatch(Color(0xFFBCAAA4)),
  _Swatch(Color(0xFF9E9E9E)), _Swatch(Color(0xFF90A4AE)), _Swatch(Color(0xFF607D8B)), _Swatch(Color(0xFF455A64)),
  _Swatch(Color(0xFF263238)), _Swatch(Color(0xFF37474F)), _Swatch(Color(0xFFCFD8DC)), _Swatch(Color(0xFFECEFF1)),
  _Swatch(Color(0xFFFFCCBC)), _Swatch(Color(0xFFFFE0B2)), _Swatch(Color(0xFFFFF9C4)), _Swatch(Color(0xFFDCEDC8)),
  _Swatch(Color(0xFFB2DFDB)), _Swatch(Color(0xFFB3E5FC)), _Swatch(Color(0xFFD1C4E9)), _Swatch(Color(0xFFF8BBD0)),
];

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Future<void> showNameBackgroundPickerDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _NameBackgroundPickerDialog(),
  );
}

class _NameBackgroundPickerDialog extends ConsumerStatefulWidget {
  const _NameBackgroundPickerDialog();
  @override
  ConsumerState<_NameBackgroundPickerDialog> createState() => _NameBackgroundPickerDialogState();
}

class _NameBackgroundPickerDialogState extends ConsumerState<_NameBackgroundPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  /// 'solid' | 'dual' | 'transparent_empty'
  String _mode = 'solid';
  Color _color1 = const Color(0xFF000000);
  Color _color2 = const Color(0xFF7C4DFF);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _pickSwatch(_Swatch s) {
    setState(() {
      _error = null;
      if (s.isDual) {
        _mode = 'dual';
        _color1 = s.c1;
        _color2 = s.c2!;
      } else {
        _mode = 'solid';
        _color1 = s.c1;
      }
    });
  }

  /// Manual two-color merge: pick color 1, then color 2, in place — no nested
  /// dialog stacking (that pattern caused an app-wide MouseTracker freeze
  /// earlier in this project).
  Future<void> _manualMerge() async {
    final first = await _pickOneColor('اختر اللون الأول');
    if (first == null || !mounted) return;
    final second = await _pickOneColor('اختر اللون الثاني');
    if (second == null || !mounted) return;
    setState(() {
      _mode = 'dual';
      _color1 = first;
      _color2 = second;
      _error = null;
    });
  }

  Future<Color?> _pickOneColor(String title) {
    final all = <_Swatch>[..._kSolidColors, ..._kNeonColors, ..._kOtherColors];
    return showDialog<Color>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in all)
                  InkWell(
                    onTap: () => Navigator.pop(c, s.c1),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: s.c1,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء'))],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final itemKey = switch (_mode) {
        'dual' => _kDualItemKey,
        'transparent_empty' => _kEmptyItemKey,
        _ => _kSolidItemKey,
      };
      await Supabase.instance.client.rpc('set_username_background', params: {
        'p_background_key': itemKey,
        'p_custom_color1': _hex(_color1),
        'p_custom_color2': _hex(_mode == 'dual' ? _color2 : _color1),
      });
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('تم حفظ خلفية إطار الاسم ✓'), backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      final s = e.toString();
      debugPrint('NAME_BACKGROUND_SAVE_ERROR: $s');
      setState(() {
        _error = s.contains('ITEM_NOT_OWNED')
            ? 'هذه الخلفية غير مملوكة بعد — اشترِها من قسم «خلفية إطار الاسم» أولًا.'
            : s.contains('INVALID_CUSTOM_COLOR')
                ? 'قيمة اللون غير صالحة.'
                : s.contains('AUTH_REQUIRED')
                    ? 'انتهت جلسة الدخول.'
                    : 'تعذر حفظ الخلفية. تم تسجيل تفاصيل الخطأ.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _grid(List<_Swatch> swatches) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemCount: swatches.length,
      itemBuilder: (_, i) {
        final s = swatches[i];
        final selected = s.isDual
            ? (_mode == 'dual' && s.c1.toARGB32() == _color1.toARGB32() && s.c2!.toARGB32() == _color2.toARGB32())
            : (_mode == 'solid' && s.c1.toARGB32() == _color1.toARGB32());
        return InkWell(
          onTap: () => _pickSwatch(s),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              color: s.isDual ? null : s.c1,
              gradient: s.isDual ? LinearGradient(colors: [s.c1, s.c2!]) : null,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? Colors.amberAccent : Colors.white24,
                width: selected ? 2.4 : 1,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final effect = UsernameEffectX.fromWire(profile?.usernameEffect);
    final name = profile?.displayName.trim() ?? '';

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text('خلفية إطار الاسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            // Live preview: shows the chosen background TOGETHER with the
            // user's own name effect and name template, so what you see here
            // is exactly what chat/profile will render.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: UsernameCosmeticName(
                name: name,
                effect: effect,
                fontSize: profile?.usernameFontSize ?? 22,
                backgroundMode: _mode,
                backgroundColor1: _hex(_color1),
                backgroundColor2: _hex(_mode == 'dual' ? _color2 : _color1),
                backgroundOpacity: _mode == 'transparent_empty' ? 0 : .82,
                templateKey: profile?.usernameTemplateKey,
                userId: profile?.uid,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              ),
            ),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabs,
              isScrollable: false,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [Tab(text: 'لون'), Tab(text: 'نيون'), Tab(text: 'خلفية'), Tab(text: 'آخر')],
            ),
            SizedBox(
              height: 190,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _grid(_kSolidColors),
                  _grid(_kNeonColors),
                  _grid(_kGradients),
                  _grid(_kOtherColors),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _manualMerge,
                  icon: const Icon(Icons.gradient, size: 18),
                  label: const Text('دمج لونين يدويًا', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _mode = 'transparent_empty';
                            _error = null;
                          }),
                  icon: Icon(Icons.check_box_outline_blank,
                      size: 18, color: _mode == 'transparent_empty' ? Colors.amberAccent : null),
                  label: const Text('فارغة من الداخل', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
