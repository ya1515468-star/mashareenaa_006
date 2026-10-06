import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class SongSearchSheet {
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String videoId, String title) onSelected,
    void Function(String videoId, String title)? onPreviewPlay,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongSearchBody(
        onSelected: onSelected,
        onPreviewPlay: onPreviewPlay,
      ),
    );
  }
}

class _SongResult {
  final String id;
  final String title;
  final String thumbnail;
  final String channel;
  final String duration;

  const _SongResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.channel,
    this.duration = '',
  });
}

class _SongSearchBody extends StatefulWidget {
  final Future<void> Function(String videoId, String title) onSelected;
  final void Function(String videoId, String title)? onPreviewPlay;

  const _SongSearchBody({
    required this.onSelected,
    this.onPreviewPlay,
  });

  @override
  State<_SongSearchBody> createState() => _SongSearchBodyState();
}

class _YoutubeBadge extends StatelessWidget {
  const _YoutubeBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xCC111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'YouTube',
          style: TextStyle(
            color: Color(0xFF22C55E),
            fontWeight: FontWeight.w900,
            fontSize: 9,
          ),
        ),
      );
}

class _SongSearchBodyState extends State<_SongSearchBody> {
  final _query = TextEditingController();
  WebViewController? _fallbackController;
  List<_SongResult> _results = const [];
  bool _busy = false;
  String? _selectedVideoId;
  String _selectedTitle = 'فيديو يوتيوب';

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _results = const [];
      _selectedVideoId = null;
      _fallbackController = null;
    });

    List<_SongResult> results = const [];
    try {
      final response = await http.get(
        Uri.https('www.youtube.com', '/results', {
          'search_query': q,
          'hl': 'ar',
          'gl': 'US',
        }),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36',
          'Accept-Language': 'ar,en-US;q=0.8,en;q=0.6',
        },
      );
      if (response.statusCode == 200) {
        results = _parseSearchResults(response.body);
      }
    } catch (_) {}

    if (!mounted) return;
    if (results.isEmpty && !kIsWeb) {
      _fallbackController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final id = _extractVideoId(request.url);
              if (id != null) {
                unawaited(_select(id));
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(
          Uri.https('www.youtube.com', '/results', {
            'search_query': q,
            'hl': 'ar',
            'gl': 'US',
          }),
        );
    }
    setState(() {
      _results = results;
      _busy = false;
    });
  }

  List<_SongResult> _parseSearchResults(String html) {
    try {
      final initial = _extractInitialData(html);
      if (initial == null) return const [];
      final renderers = <Map<String, dynamic>>[];
      final stack = <dynamic>[initial];
      while (stack.isNotEmpty && renderers.length < 16) {
        final node = stack.removeLast();
        if (node is Map) {
          final vr = node['videoRenderer'];
          if (vr is Map && vr['videoId'] != null) {
            renderers.add(Map<String, dynamic>.from(vr));
            continue;
          }
          stack.addAll(node.values);
        } else if (node is List) {
          stack.addAll(node);
        }
      }

      return renderers.map((r) {
        final id = r['videoId']?.toString() ?? '';
        final title = _textNode(r['title']).trim();
        final channel = _textNode(r['ownerText']).trim();
        final duration = _textNode(r['lengthText']).trim();
        final thumbs = r['thumbnail']?['thumbnails'];
        final thumbnail = thumbs is List && thumbs.isNotEmpty
            ? (thumbs.last is Map ? thumbs.last['url']?.toString() ?? '' : '')
            : '';
        return _SongResult(
          id: id,
          title: title.isEmpty ? 'فيديو يوتيوب' : title,
          thumbnail: thumbnail,
          channel: channel.isEmpty ? 'YouTube' : channel,
          duration: duration,
        );
      }).where((e) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(e.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  dynamic _extractInitialData(String html) {
    const markers = [
      'var ytInitialData = ',
      'ytInitialData = ',
    ];
    int markerEnd = -1;
    for (final marker in markers) {
      final i = html.indexOf(marker);
      if (i >= 0) {
        markerEnd = i + marker.length;
        break;
      }
    }
    if (markerEnd < 0) return null;
    final start = html.indexOf('{', markerEnd);
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final c = html.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          inString = false;
        }
        continue;
      }
      if (c == 34) {
        inString = true;
      } else if (c == 123) {
        depth++;
      } else if (c == 125) {
        depth--;
        if (depth == 0) {
          return jsonDecode(html.substring(start, i + 1));
        }
      }
    }
    return null;
  }

  String _textNode(dynamic node) {
    if (node is Map) {
      final simple = node['simpleText'];
      if (simple != null) return simple.toString();
      final runs = node['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((r) => r['text']?.toString() ?? '')
            .join();
      }
    }
    return '';
  }

  String? _extractVideoId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    String? id = (host == 'youtu.be' || host.endsWith('.youtu.be'))
        ? (uri.pathSegments.isEmpty ? null : uri.pathSegments.first)
        : uri.queryParameters['v'];
    if (id == null && host.contains('youtube.com') && uri.pathSegments.length >= 2) {
      if ({'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
        id = uri.pathSegments[1];
      }
    }
    return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
  }

  Future<void> _select(String id, {String? title}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final fetchedTitle = title ?? await _fetchTitle(id);
    if (!mounted) return;
    setState(() {
      _selectedVideoId = id;
      _selectedTitle = fetchedTitle;
      _busy = false;
    });
  }

  Future<String> _fetchTitle(String videoId) async {
    try {
      final res = await http.get(Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['title'] != null) return data['title'].toString();
      }
    } catch (_) {}
    return 'فيديو يوتيوب';
  }

  Future<void> _send() async {
    final id = _selectedVideoId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSelected(id, _selectedTitle);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendResult(_SongResult result) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSelected(result.id, result.title);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _resultCard(_SongResult result) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171126),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF5B4C8A).withValues(alpha: .45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: result.thumbnail.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF2A2038),
                          child: Icon(
                            Icons.ondemand_video_rounded,
                            color: Color(0xFFA78BFA),
                            size: 42,
                          ),
                        )
                      : Image.network(
                          result.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF2A2038),
                            child: Icon(
                              Icons.ondemand_video_rounded,
                              color: Color(0xFFA78BFA),
                              size: 42,
                            ),
                          ),
                        ),
                ),
                const Positioned(
                  top: 8,
                  left: 8,
                  child: _YoutubeBadge(),
                ),
                Positioned.fill(
                  child: Center(
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy
                            ? null
                            : () => widget.onPreviewPlay?.call(
                                  result.id,
                                  result.title,
                                ),
                        child: const SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF2F3E7D),
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (result.duration.isNotEmpty)
                  Positioned(
                    bottom: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        result.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(height: 4),
              Text(result.channel, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
              if (result.duration.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(result.duration, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
              const SizedBox(height: 8),
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _sendResult(result),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('إرسال'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C5CFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => widget.onPreviewPlay?.call(
                                result.id,
                                result.title,
                              ),
                      icon: const Icon(Icons.headphones_rounded, size: 16),
                      label: const Text('تشغيل'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF67E8F9),
                        side: const BorderSide(
                          color: Color(0xFF2DD4BF),
                          width: 1.5,
                        ),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final selected = _selectedVideoId;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          height: MediaQuery.sizeOf(context).height * .86,
          decoration: const BoxDecoration(
            color: Color(0xFF0E0A19),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(width: 46, height: 5, margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17133A), Color(0xFF352078)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF8D6BFF).withValues(alpha: .55),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x552B0A5B),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'PLAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white70,
                              size: 31,
                            ),
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: const Color(0x334A3A83),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x4427194D),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFF8D78C6).withValues(alpha: .65),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'بحث YouTube',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFD9CCFF),
                          size: 31,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن أغنية أو فيديو...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                        ),
                        suffixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFFBDA7FF),
                          size: 28,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF21183A),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F8BFF),
                            width: 2.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF5B8CFF),
                            width: 2.6,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 9),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    onPressed: _busy ? null : _search,
                    icon: const Icon(Icons.search_rounded, size: 23),
                    label: const Text(
                      'بحث',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3F2A75), Color(0xFF21183A)]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: .6)),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network('https://i.ytimg.com/vi/$selected/hqdefault.jpg', width: 94, height: 62, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26, child: SizedBox(width: 94, height: 62))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selectedTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(children: [
                        OutlinedButton.icon(
                          onPressed: () => widget.onPreviewPlay?.call(selected, _selectedTitle),
                          icon: const Icon(Icons.headphones_rounded, size: 17),
                          label: const Text('تشغيل'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF67E8F9)),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded, size: 17),
                          label: const Text('إرسال'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                        ),
                      ]),
                    ])),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isNotEmpty
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .72,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (_, i) => _resultCard(_results[i]),
                    )
                  : kIsWeb
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('البحث عن YouTube غير متاح من المتصفح هنا. استخدم تطبيق الهاتف.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                        ))
                      : _fallbackController != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(14), child: WebViewWidget(controller: _fallbackController!))
                          : const Center(child: Text('اكتب اسم أغنية ثم اضغط بحث', style: TextStyle(color: Colors.white38))),
            ),
            if (_busy)
              const Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }
}
