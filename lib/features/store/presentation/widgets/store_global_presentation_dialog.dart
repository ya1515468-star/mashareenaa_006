import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/store_global_presentation_settings.dart';

Future<bool?> showStoreGlobalPresentationDialog({
  required BuildContext context,
  required StoreGlobalPresentationSettings initial,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _StoreGlobalPresentationDialog(initial: initial),
);

class _StoreGlobalPresentationDialog extends ConsumerStatefulWidget {
  final StoreGlobalPresentationSettings initial;
  const _StoreGlobalPresentationDialog({required this.initial});

  @override
  ConsumerState<_StoreGlobalPresentationDialog> createState() =>
      _StoreGlobalPresentationDialogState();
}

class _StoreGlobalPresentationDialogState
    extends ConsumerState<_StoreGlobalPresentationDialog> {
  late double _font = widget.initial.fontScale;
  late double _emoji = widget.initial.emojiScale;
  late double _card = widget.initial.cardScale;
  late double _preview = widget.initial.previewScale;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc(
        'owner_set_store_global_presentation_settings',
        params: {
          'p_font_scale': _font,
          'p_emoji_scale': _emoji,
          'p_card_scale': _card,
          'p_preview_scale': _preview,
        },
      );
      ref.invalidate(storeGlobalPresentationSettingsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e.toString();
      if (!mounted) return;
      setState(() {
        _error = message.contains('FORBIDDEN')
            ? 'لا تملك صلاحية تغيير إعدادات المتجر العامة.'
            : 'تعذر حفظ الإعدادات على الخادم. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
    _font = 1;
    _emoji = 1;
    _card = 1;
    _preview = 1;
  });

  @override
  Widget build(BuildContext context) {
    final outerMedia = MediaQuery.of(context);
    final baseTextScale = outerMedia.textScaler.scale(1.0);
    final draft = StoreGlobalPresentationSettings(
      fontScale: _font,
      emojiScale: _emoji,
      cardScale: _card,
      previewScale: _preview,
    );

    return AlertDialog(
      title: const Text('التحكم المركزي بمظهر المتجر'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إعدادات مشتركة لكل أقسام متجر الشات، تحفظ خادميًا وتُحدّث الشاشات المتصلة.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 14),
              _ScaleSlider(title: 'حجم الخط والنصوص', value: _font,
                min: 0.70, max: 1.30, divisions: 12,
                onChanged: (v) => setState(() => _font = v)),
              _ScaleSlider(title: 'حجم السمايلات والرموز', value: _emoji,
                min: 0.60, max: 1.50, divisions: 18,
                onChanged: (v) => setState(() => _emoji = v)),
              _ScaleSlider(title: 'حجم بطاقات المتجر وكثافتها', value: _card,
                min: 0.70, max: 1.30, divisions: 12,
                onChanged: (v) => setState(() => _card = v)),
              _ScaleSlider(title: 'حجم الصور ومعاينات العناصر', value: _preview,
                min: 0.60, max: 1.40, divisions: 16,
                onChanged: (v) => setState(() => _preview = v)),
              const SizedBox(height: 8),
              const Text('معاينة مباشرة', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              StorePresentationScope(
                settings: draft,
                child: MediaQuery(
                  data: outerMedia.copyWith(textScaler: TextScaler.linear(baseTextScale * _font)),
                  child: IconTheme(
                    data: IconTheme.of(context).copyWith(
                      size: (IconTheme.of(context).size ?? 24) * _emoji,
                    ),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(10 * _card),
                        child: Row(children: [
                          Text('🛍️', style: TextStyle(fontSize: 22 * _emoji)),
                          SizedBox(width: 8 * _card),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('عنصر تجريبي', style: TextStyle(fontWeight: FontWeight.w900)),
                              const Text('وصف العنصر وسعره'),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 34 * _card,
                                child: FilledButton(onPressed: null, child: const Text('شراء / تفعيل')),
                              ),
                            ],
                          )),
                          SizedBox(width: 48 * _preview, height: 48 * _preview,
                            child: const Icon(Icons.auto_awesome)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _reset, child: const Text('استعادة الافتراضي')),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ وتطبيق على الجميع'),
        ),
      ],
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _ScaleSlider({required this.title, required this.value, required this.min,
    required this.max, required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text('${(value * 100).round()}%'),
      ]),
      Slider(value: value.clamp(min, max).toDouble(), min: min, max: max,
        divisions: divisions, label: '${(value * 100).round()}%', onChanged: onChanged),
    ]),
  );
}
