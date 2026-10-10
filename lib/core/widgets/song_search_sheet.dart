import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// بحث أغنية/فيديو على يوتيوب — نتائج حقيقية تُجلَب خادميًا بالكامل عبر
/// Edge Function (youtube-search)، لا عبر WebView كما كان سابقًا.
///
/// الفرق الجوهري عن النسخة السابقة:
/// ١) كانت WebView تُحمِّل صفحة youtube.com/results مباشرة داخل التطبيق —
///    يرفضها يوتيوب كليًا على الويب (X-Frame-Options)، فالبحث كان معطّلاً
///    بالكامل في نسخة الويب (هذا تحديدًا ما ظهر أثناء اختبار الويب). الآن
///    البحث نفسه يُنفَّذ على الخادم (Deno Edge Function يجلب صفحة النتائج
///    خادميًا ويستخرج منها قائمة مُهيكَلة)، فيعمل على كل المنصات بما فيها
///    الويب — ولا يصل أي HTML/JS من يوتيوب إلى جهاز المستخدم إطلاقًا.
/// ٢) لا تُرسَل النتيجة فور الضغط عليها — الضغط على نتيجة يُحدّدها فقط،
///    ويظهر زر "إرسال" صريح أسفل اللوحة؛ لا شيء يصل الشات إلا بضغطه.
/// ٣) لوحة عائمة مصغّرة (ارتفاع محدود، زوايا كاملة مستديرة) لا شاشة كاملة —
///    لا تحجب الشات أثناء البحث وعرض النتائج.
class SongSearchSheet {
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String videoId, String title) onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongSearchBody(onSend: onSend),
    );
  }
}

class _YoutubeSearchResult {
  final String videoId;
  final String title;
  final String thumbnail;
  final String channel;
  final String duration;
  const _YoutubeSearchResult({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.channel,
    required this.duration,
  });

  factory _YoutubeSearchResult.fromMap(Map<String, dynamic> map) {
    return _YoutubeSearchResult(
      videoId: map['videoId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'فيديو يوتيوب',
      thumbnail: map['thumbnail']?.toString() ?? '',
      channel: map['channel']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
    );
  }
}

class _SongSearchBody extends StatefulWidget {
  final Future<void> Function(String videoId, String title) onSend;
  const _SongSearchBody({required this.onSend});
  @override
  State<_SongSearchBody> createState() => _SongSearchBodyState();
}

class _SongSearchBodyState extends State<_SongSearchBody> {
  final _query = TextEditingController();
  List<_YoutubeSearchResult> _results = const [];
  _YoutubeSearchResult? _selected;
  bool _searching = false;
  bool _sending = false;
  String? _error;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _selected = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'youtube-search',
        body: {'q': q},
      );
      final data = res.data;
      final rows = (data is Map ? data['results'] : null) as List<dynamic>?;
      final serverError = data is Map ? data['error']?.toString() : null;
      final results = (rows ?? const [])
          .whereType<Map>()
          .map((m) => _YoutubeSearchResult.fromMap(Map<String, dynamic>.from(m)))
          .where((r) => r.videoId.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isNotEmpty
            ? null
            : (serverError != null && serverError.isNotEmpty)
                ? 'تعذّر البحث حاليًا. حاول مرة أخرى.'
                : 'لا نتائج لهذا البحث.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = 'تعذّر البحث حاليًا. تحقق من الاتصال وحاول مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirmSend() async {
    final sel = _selected;
    if (sel == null || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(sel.videoId, sel.title);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'تعذّر إرسال الأغنية. حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // لوحة عائمة مصغّرة بارتفاع محدود (لا 82% من الشاشة كما كانت) — لا
    // تحجب الشات أثناء البحث وعرض النتائج، تمامًا كالمطلوب.
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.62).clamp(360.0, 520.0);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
            child: Material(
              color: const Color(0xFF17101F),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'ابحث عن اسم أغنية…',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: Colors.white54, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _searching ? null : _search,
                      child: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('بحث', style: TextStyle(color: Colors.black)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: _error != null && _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54)),
                        )
                      : _results.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('اكتب اسم أغنية ثم اضغط بحث',
                                  style: TextStyle(color: Colors.white38)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shrinkWrap: true,
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                final isSelected = _selected?.videoId == r.videoId;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _selected = r),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFD700).withValues(alpha: .14)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(color: const Color(0xFFFFD700), width: 1)
                                          : null,
                                    ),
                                    child: Row(children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: r.thumbnail.isEmpty
                                            ? Container(
                                                width: 64,
                                                height: 40,
                                                color: Colors.white12,
                                                child: const Icon(Icons.music_note,
                                                    color: Colors.white38, size: 18),
                                              )
                                            : Image.network(
                                                r.thumbnail,
                                                width: 64,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                    width: 64,
                                                    height: 40,
                                                    color: Colors.white12,
                                                    child: const Icon(Icons.music_note,
                                                        color: Colors.white38, size: 18)),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(r.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600)),
                                            if (r.channel.isNotEmpty || r.duration.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                    [r.channel, r.duration]
                                                        .where((s) => s.isNotEmpty)
                                                        .join(' · '),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white38, fontSize: 11)),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? const Color(0xFFFFD700)
                                            : Colors.white24,
                                        size: 20,
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
                if (_selected != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700)),
                        onPressed: _sending ? null : _confirmSend,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                        label: Text(
                          _sending ? 'جارٍ الإرسال…' : 'إرسال "${_selected!.title}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
