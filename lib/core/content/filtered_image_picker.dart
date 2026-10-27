import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_filters.dart';

/// يختار فلترًا لصورة قبل نشرها، ويُعيد البايتات **مخبوزةً** به.
///
/// الفلاتر تأتي من الخادم (`media_filter_catalog`) فيزيدها المالك
/// ويعدّلها ويمنعها بلا نسخة جديدة. والمعاينة هي نفسها الرسم الذي
/// يُخبَز، فما يراه الناشر هو ما يُحفَظ.
class FilteredImagePicker extends ConsumerStatefulWidget {
  const FilteredImagePicker({
    super.key,
    required this.bytes,
    this.title = 'تعديل الصورة',
  });

  final Uint8List bytes;
  final String title;

  /// يفتح المحرِّر ويُعيد البايتات بعد الفلتر، أو null عند الإلغاء.
  static Future<Uint8List?> edit(BuildContext context, Uint8List bytes,
      {String title = 'تعديل الصورة'}) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => FilteredImagePicker(bytes: bytes, title: title),
    );
  }

  @override
  ConsumerState<FilteredImagePicker> createState() =>
      _FilteredImagePickerState();
}

class _FilteredImagePickerState extends ConsumerState<FilteredImagePicker> {
  MediaFilter _selected = MediaFilter.none;
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final out = await MediaFilter.bake(widget.bytes, _selected);
      if (!mounted) return;
      Navigator.of(context).pop(out);
    } catch (_) {
      // فشل الخَبز يُعيد الأصل: صورة بلا فلتر أهون من نشرٍ لا يكتمل.
      if (!mounted) return;
      Navigator.of(context).pop(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters =
        ref.watch(mediaFiltersProvider).valueOrNull ?? const [MediaFilter.none];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(_selected.isNone ? '' : '${_selected.emoji} ${_selected.name}',
                  style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: _Preview(bytes: widget.bytes, filter: _selected),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final on = f.key == _selected.key;
                  return InkWell(
                    onTap: _busy ? null : () => setState(() => _selected = f),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: on
                                ? const Color(0xFFFFD700)
                                : Colors.white12,
                            width: on ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: _Preview(
                              bytes: widget.bytes, filter: f, thumb: true),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9.5,
                                color: on
                                    ? const Color(0xFFFFD700)
                                    : Colors.white54)),
                      ),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _apply,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('استخدام الصورة',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview(
      {required this.bytes, required this.filter, this.thumb = false});

  final Uint8List bytes;
  final MediaFilter filter;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final img = Image.memory(bytes,
        fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.medium);
    final cf = filter.colorFilter();
    final grad = filter.backgroundGradient();

    Widget child = cf == null ? img : ColorFiltered(colorFilter: cf, child: img);
    if (grad != null) {
      child = Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(gradient: grad)),
        // الخلفية تظهر حول صورة لا تملأ الإطار — وهو معنى «خلفية».
        Padding(
          padding: EdgeInsets.all(thumb ? 6 : 18),
          child: Image.memory(bytes,
              fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ]);
    }
    return child;
  }
}
