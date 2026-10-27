import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure_text.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/services/snack_sfx.dart';
import 'package:file_picker/file_picker.dart' as fp;

/// خدمة «خلفية مخصّصة لكل محادثة» (البند ١٠).
///
/// الخدمة كانت تُشترى ولا تفعل شيئًا: مفتاحها chat_wallpaper لا وجود
/// له في موزِّع خدمات VIP إطلاقًا، فالضغط عليها يسقط في `default:
/// return;` — بلا رسالة ولا شاشة. الخلفية نفسها كانت تعمل لكن من
/// داخل المحادثة وحدها، ولا شيء يدلّ العضو على ذلك.
///
/// هذه الشاشة تجمع الأمرين: قائمة محادثاته الحقيقية
/// (list_my_threads)، وفهرس الخلفيات (get_chat_wallpaper_catalog)،
/// أو صورة من جهازه — ويُحفَظ الاختيار بـset_my_chat_wallpaper التي
/// تتحقّق خادميًّا أنّه مشارك في المحادثة وأنّه يملك الخدمة.
final _myThreadsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await Supabase.instance.client
      .rpc('list_my_threads', params: {'p_limit': 60});
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

final _wallpaperCatalogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await Supabase.instance.client
      .rpc('get_chat_wallpaper_catalog', params: {'p_scope': 'direct'});
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

final _threadWallpaperProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, threadId) async {
  final r = await Supabase.instance.client
      .rpc('get_my_chat_wallpaper', params: {'p_thread_id': threadId});
  return r is Map ? Map<String, dynamic>.from(r) : null;
});

class ChatWallpaperPage extends ConsumerWidget {
  const ChatWallpaperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('خلفية كل محادثة'), centerTitle: true),
        body: ref.watch(_myThreadsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Text(FailureText.of(e, subject: 'محادثاتك'),
                      textAlign: TextAlign.center),
                ),
              ),
              data: (threads) {
                final real =
                    threads.where((t) => t['is_system'] != true).toList();
                if (real.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(26),
                      child: Text(
                        'لا محادثات بعد. ابدأ محادثة ثم اختر لها خلفية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_myThreadsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: real.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ThreadRow(thread: real[i]),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.thread});
  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = thread['id'].toString();
    final current = ref.watch(_threadWallpaperProvider(id)).valueOrNull;
    final url = current?['image_url']?.toString();
    final gradientKey = current?['wallpaper_key']?.toString();
    final has = (url != null && url.isNotEmpty) ||
        (gradientKey != null && gradientKey.isNotEmpty);
    final avatar = thread['other_avatar']?.toString();

    return ListTile(
      leading: Stack(children: [
        CircleAvatar(
          radius: 22,
          backgroundImage:
              (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
          child: (avatar == null || avatar.isEmpty)
              ? const Icon(Icons.person, size: 20)
              : null,
        ),
        if (has)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Color(0xFF34D399), shape: BoxShape.circle),
              child: const Icon(Icons.wallpaper_rounded,
                  size: 10, color: Colors.black),
            ),
          ),
      ]),
      title: Text(thread['other_name']?.toString() ??
          thread['title']?.toString() ??
          'محادثة'),
      subtitle: Text(has ? 'لها خلفية مخصّصة' : 'بلا خلفية',
          style: const TextStyle(fontSize: 11, color: Colors.white54)),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => _pick(context, ref, id,
          thread['other_name']?.toString() ?? 'المحادثة', current),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, String threadId,
      String name, Map<String, dynamic>? current) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131B),
      builder: (_) => _WallpaperSheet(
        threadId: threadId,
        name: name,
        currentUrl: current?['image_url']?.toString(),
        currentOpacity: (current?['opacity'] as num?)?.toDouble() ?? 0.35,
        currentKey: current?['wallpaper_key']?.toString(),
        currentColor1: current?['color1']?.toString(),
        currentColor2: current?['color2']?.toString(),
      ),
    );
    ref.invalidate(_threadWallpaperProvider(threadId));
  }
}

class _WallpaperSheet extends ConsumerStatefulWidget {
  const _WallpaperSheet({
    required this.threadId,
    required this.name,
    required this.currentUrl,
    required this.currentOpacity,
    this.currentKey,
    this.currentColor1,
    this.currentColor2,
  });

  final String threadId;
  final String name;
  final String? currentUrl;
  final double currentOpacity;
  final String? currentKey;
  final String? currentColor1;
  final String? currentColor2;

  @override
  ConsumerState<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends ConsumerState<_WallpaperSheet> {
  String? _url;
  // فهرس الخلفيات تدرّجات لونية لا صور (color1/color2 وimage_url فارغ)،
  // فالمعاينة والحفظ يتعاملان مع المفتاح لا مع رابط.
  String? _key;
  Color? _c1;
  Color? _c2;
  late double _opacity = widget.currentOpacity;
  bool _busy = false;

  static Color? _hex(Object? v) {
    final s = v?.toString().trim().replaceFirst('#', '') ?? '';
    if (s.length != 6) return null;
    final n = int.tryParse(s, radix: 16);
    return n == null ? null : Color(0xFF000000 | n);
  }

  @override
  void initState() {
    super.initState();
    _url = widget.currentUrl;
    _key = widget.currentKey;
    _c1 = _hex(widget.currentColor1);
    _c2 = _hex(widget.currentColor2);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(m)));

  Future<void> _upload() async {
    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast('تعذّر قراءة الصورة المختارة.');
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final url = await MediaUploadService(bucket: 'media').uploadBytes(
        bytes: bytes,
        fileName: picked.files.single.name,
        folder: 'chat/wallpapers',
        uid: uid,
      );
      if (mounted) {
        setState(() {
          _url = url;
          _key = null;
          _c1 = null;
          _c2 = null;
        });
      }
    } catch (e) {
      if (mounted) _toast(FailureText.action(e, action: 'رفع الصورة'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('set_my_chat_wallpaper', params: {
        'p_thread_id': widget.threadId,
        'p_image_url': clear ? null : _url,
        'p_wallpaper_key': clear ? null : _key,
        if (!clear) 'p_opacity': _opacity,
      });
      if (!mounted) return;
      Navigator.pop(context);
      _toast(clear ? 'أُزيلت الخلفية' : 'حُفظت الخلفية ✓');
    } catch (e) {
      if (!mounted) return;
      // الخادم يرفض بـFEATURE_REQUIRED_CHAT_WALLPAPER لمن لا يملك
      // الخدمة؛ تُترجَم إلى سببها لا إلى رمزها.
      final needsVip =
          e.toString().contains('FEATURE_REQUIRED_CHAT_WALLPAPER');
      _toast(needsVip
          ? 'هذه خدمة VIP — فعّلها من خدمات VIP أولًا.'
          : FailureText.action(e, action: 'حفظ الخلفية'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_wallpaperCatalogProvider).valueOrNull ?? const [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('خلفية محادثة ${widget.name}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if ((_url != null && _url!.isNotEmpty) || _c1 != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  if (_url != null && _url!.isNotEmpty)
                    Image.network(_url!,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            height: 130, color: Colors.white10))
                  else
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [_c1!, _c2 ?? _c1!],
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 1 - _opacity),
                    ),
                  ),
                  const Positioned(
                    bottom: 8,
                    right: 10,
                    child: Text('معاينة بالشفافية المختارة',
                        style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: catalog.isEmpty
                  ? const Center(
                      child: Text('لا خلفيات جاهزة في الفهرس بعد.',
                          style:
                              TextStyle(fontSize: 11, color: Colors.white54)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalog.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final w = catalog[i];
                        final wkey = w['wallpaper_key']?.toString() ?? '';
                        final wurl = w['image_url']?.toString() ?? '';
                        final a = _hex(w['color1']);
                        final b = _hex(w['color2']);
                        final selected = wkey.isNotEmpty && wkey == _key;
                        return InkWell(
                          onTap: wkey.isEmpty
                              ? null
                              : () => setState(() {
                                    _key = wkey;
                                    _url = wurl.isEmpty ? null : wurl;
                                    _c1 = a;
                                    _c2 = b;
                                  }),
                          child: Container(
                            width: 76,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selected
                                      ? Colors.amberAccent
                                      : Colors.white24,
                                  width: selected ? 2 : 1),
                              gradient: (wurl.isEmpty && a != null)
                                  ? LinearGradient(
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomLeft,
                                      colors: [a, b ?? a])
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: wurl.isNotEmpty
                                ? Image.network(wurl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: Colors.white10))
                                : Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Text(
                                        w['name_ar']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 8.5,
                                            color: Colors.white70),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Text('الشفافية', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.05,
                  max: 1,
                  divisions: 19,
                  label: '${(_opacity * 100).round()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('من جهازي'),
                ),
              ),
              const SizedBox(width: 8),
              if ((widget.currentUrl ?? '').isNotEmpty ||
                  (widget.currentKey ?? '').isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => _save(clear: true),
                  child: const Text('إزالة'),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_busy ||
                          ((_url == null || _url!.isEmpty) &&
                              (_key == null || _key!.isEmpty)))
                      ? null
                      : () => _save(),
                  icon: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('حفظ'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
