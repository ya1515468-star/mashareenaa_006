import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../error/failure_text.dart';

/// عارض الوسائط: صور وفيديو بملء الشاشة، مع تقريب وتنزيل ومشاركة.
///
/// كانت صور الإعلانات والمنتجات تُعرَض مقصوصة بارتفاع ثابت ولا تُفتَح،
/// فمن يريد رؤية قماشٍ أو تفصيلًا لا يستطيع — وهو جوهر المنصّة.
/// وزرّ التنزيل لم يكن موجودًا أصلًا.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.title,
  });

  /// روابط الوسائط بالترتيب. الفيديو يُعرَف بامتداده.
  final List<String> items;
  final int initialIndex;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required List<String> items,
    int initialIndex = 0,
    String? title,
  }) {
    final clean =
        items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) return Future.value();
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MediaViewer(
        items: clean,
        initialIndex: initialIndex.clamp(0, clean.length - 1),
        title: title,
      ),
    ));
  }

  static bool isVideo(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.m4v') ||
        u.endsWith('.webm');
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  /// ينزّل الوسيط الحالي إلى مجلّد المستندات ثم يعرض زرّ مشاركة.
  ///
  /// يُكتَب في المستندات لا في المؤقّت: المؤقّت يُمحى بلا إشعار فيجد
  /// المستخدم ما «نزّله» مفقودًا.
  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final url = widget.items[_index];
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw 'HTTP ${res.statusCode}';
      }
      final dir = await getApplicationDocumentsDirectory();
      final ext = () {
        final u = url.toLowerCase().split('?').first;
        for (final e in ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp4', '.mov']) {
          if (u.endsWith(e)) return e;
        }
        return MediaViewer.isVideo(url) ? '.mp4' : '.jpg';
      }();
      final f = File(
          '${dir.path}/mashareena_${DateTime.now().millisecondsSinceEpoch}$ext');
      await f.writeAsBytes(res.bodyBytes);
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(
        content: const Text('تم التنزيل ✓'),
        backgroundColor: const Color(0xFF16A34A),
        action: SnackBarAction(
          label: 'مشاركة',
          textColor: Colors.white,
          onPressed: () => Share.shareXFiles([XFile(f.path)]),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
          SnackBar(content: Text(FailureText.action(e, action: 'التنزيل'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.items.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          many
              ? '${_index + 1} / ${widget.items.length}'
              : (widget.title ?? ''),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              tooltip: 'تنزيل',
              icon: const Icon(Icons.download_rounded),
              onPressed: _download,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _page,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: widget.items.length,
        itemBuilder: (_, i) {
          final url = widget.items[i];
          if (MediaViewer.isVideo(url)) {
            return _InlineVideo(url: url, key: ValueKey(url));
          }
          return InteractiveViewer(
            // التقريب مطلوب فعلًا هنا: تفصيل قماش أو خياطة لا يُرى
            // بحجم الشاشة.
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white24)),
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          color: Colors.white24, size: 48),
                      SizedBox(height: 10),
                      Text('تعذّر تحميل الصورة — تحقّق من الإنترنت',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: many
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Container(
                        width: i == _index ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _index
                              ? const Color(0xFFFFD700)
                              : Colors.white24,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _InlineVideo extends StatefulWidget {
  const _InlineVideo({super.key, required this.url});
  final String url;
  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  VideoPlayerController? _c;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error = FailureText.of(e, subject: 'الفيديو'));
      }
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
    }
    final c = _c;
    if (c == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white24));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: Stack(alignment: Alignment.center, children: [
          VideoPlayer(c),
          _PlayToggle(controller: c),
        ]),
      ),
    );
  }
}

class _PlayToggle extends StatefulWidget {
  const _PlayToggle({required this.controller});
  final VideoPlayerController controller;
  @override
  State<_PlayToggle> createState() => _PlayToggleState();
}

class _PlayToggleState extends State<_PlayToggle> {
  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        playing
            ? await widget.controller.pause()
            : await widget.controller.play();
        if (mounted) setState(() {});
      },
      child: AnimatedOpacity(
        opacity: playing ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
              color: Colors.black45, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 40),
        ),
      ),
    );
  }
}
