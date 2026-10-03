import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

/// ورقة بحث عن أغنية/فيديو على يوتيوب: المستخدم يكتب اسمًا، تظهر نتائج
/// يوتيوب الحقيقية (نفس صفحة نتائجه بالضبط عبر WebView)، والضغط على أي
/// نتيجة يُعيد videoId وعنوانه إلى المستدعي.
///
/// تقنية الاعتراض (منع التنقّل الفعلي عند الضغط على نتيجة، والتقاط رابطها
/// بدلًا من ذلك) مطابقة لِما تستعمله _YoutubeSearchEmbed أصلًا في
/// embedded_media_player.dart لعرض نتائج بحث مُرسَلة كرسالة؛ هذه الورقة
/// تُستعمل قبل الإرسال لا بعده.
class SongSearchSheet {
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String videoId, String title) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongSearchBody(onSelected: onSelected),
    );
  }
}

class _SongSearchBody extends StatefulWidget {
  final Future<void> Function(String videoId, String title) onSelected;
  const _SongSearchBody({required this.onSelected});
  @override
  State<_SongSearchBody> createState() => _SongSearchBodyState();
}

class _SongSearchBodyState extends State<_SongSearchBody> {
  final _query = TextEditingController();
  WebViewController? _controller;
  bool _busy = false;
  bool _webBlocked = false;

  void _search() {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    // صفحة نتائج يوتيوب (youtube.com/results) ترسل X-Frame-Options:
    // SAMEORIGIN فعليًا — يرفضها المتصفح داخل أي إطار من أصل مختلف مهما
    // كتبنا من كود؛ هذا قيد من خوادم يوتيوب نفسها لا يُحتال عليه. فقط
    // رابط /embed/ المخصّص مسموح بتضمينه، وهو غير مناسب لعرض "نتائج بحث".
    // كذلك webview_flutter لا تملك تنفيذًا على الويب أصلًا (المشروع يعرف
    // هذا فعلًا: شاهد tiktok_web_player_web.dart). النتيجتان معًا تجعلان
    // WebViewController هنا يفشل صامتًا على الويب، فتظهر أيقونة الصفحة
    // المكسورة. على الهاتف (WebView أصلي حقيقي لا إطار HTML) لا ينطبق
    // القيدان، فتعمل الميزة بشكل طبيعي.
    if (kIsWeb) {
      setState(() => _webBlocked = true);
      return;
    }
    final url =
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}';
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final id = _extractVideoId(request.url);
          if (id != null) {
            unawaited(_pick(id));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(url));
    setState(() => _controller = c);
  }

  String? _extractVideoId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    String? id;
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host.contains('youtube.com')) {
      id = uri.queryParameters['v'];
      if (id == null &&
          uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' ||
              uri.pathSegments.first == 'embed' ||
              uri.pathSegments.first == 'live')) {
        id = uri.pathSegments[1];
      }
    }
    if (id == null) return null;
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
  }

  /// يوتيوب يوفّر نقطة oEmbed عامة (بلا مفتاح API) تُرجع عنوان الفيديو
  /// الحقيقي؛ بدونها لا سبيل لمعرفة اسم الأغنية من رابط الفيديو وحده.
  Future<String> _fetchTitle(String videoId) async {
    try {
      final res = await http.get(Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['title']?.toString() ?? 'فيديو يوتيوب';
      }
    } catch (_) {}
    return 'فيديو يوتيوب';
  }

  Future<void> _pick(String videoId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final title = await _fetchTitle(videoId);
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onSelected(videoId, title);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          height: MediaQuery.sizeOf(context).height * .82,
          decoration: const BoxDecoration(
            color: Color(0xFF120A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن اسم أغنية أو فيديو…',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
                  onPressed: _search,
                  child: const Text('بحث', style: TextStyle(color: Colors.black)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(children: [
                if (_webBlocked)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.phone_android_rounded, color: Colors.white38, size: 40),
                        SizedBox(height: 10),
                        Text('البحث عن الأغاني يعمل داخل تطبيق الهاتف فقط',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        SizedBox(height: 6),
                        Text('يرفض يوتيوب تضمين صفحة نتائج البحث داخل متصفح الويب — قيد من خوادمه نفسها.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ]),
                    ),
                  )
                else if (_controller != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: WebViewWidget(controller: _controller!),
                  )
                else
                  const Center(
                    child: Text('اكتب اسم أغنية ثم اضغط بحث',
                        style: TextStyle(color: Colors.white38)),
                  ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
