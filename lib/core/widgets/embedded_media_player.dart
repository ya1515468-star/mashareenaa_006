import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/mini_player_provider.dart';
import 'youtube_thumbnail.dart';
import 'tiktok_web_player_stub.dart'
    if (dart.library.html) 'tiktok_web_player_web.dart';

/// يكتشف نوع الرابط الموسيقي/المرئي المُشارَك ويعرضه المناسب:
/// - رابط يوتيوب (watch أو youtu.be): يُضمَّن مباشرة داخل التطبيق
///   عبر WebView مضبوط على وضع التضمين الرسمي (youtube.com/embed).
/// - أي رابط آخر (SoundCloud، Spotify، إلخ): بطاقة تشغيل بسيطة تفتح
///   الرابط في التطبيق الخارجي المناسب عبر url_launcher، لأن تضمين
///   كل منصة موسيقى بمشغلها الخاص يحتاج SDK منفصلًا لكل منصة.
class EmbeddedMediaPlayer extends StatelessWidget {
  final String url;
  const EmbeddedMediaPlayer({super.key, required this.url});

  bool get _youtubeSearch {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return (host == 'youtube.com' || host.endsWith('.youtube.com')) &&
        uri.path == '/results' &&
        (uri.queryParameters['search_query']?.trim().isNotEmpty ?? false);
  }

  String? get _youtubeVideoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return _validId(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }
    if (host == 'youtube.com' || host.endsWith('.youtube.com') || host == 'music.youtube.com') {
      final v = _validId(uri.queryParameters['v']);
      if (v != null) return v;
      final parts = uri.pathSegments;
      if (parts.length >= 2 && (parts[0] == 'shorts' || parts[0] == 'embed' || parts[0] == 'live')) {
        return _validId(parts[1]);
      }
    }
    return null;
  }

  String? _validId(String? id) {
    if (id == null) return null;
    final v = id.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _youtubeVideoId;
    if (videoId != null) {
      return _YoutubeEmbed(videoId: videoId);
    }
    if (_youtubeSearch) return _YoutubeSearchEmbed(url: url);
    final uri = Uri.tryParse(url);
    final isTikTok =
        uri != null && uri.host.toLowerCase().contains('tiktok.com');
    if (isTikTok) {
      if (uri.path.startsWith('/search')) return _TikTokSearchEmbed(url: url);
      if (kIsWeb) return TikTokWebPlayer(url: url);
      return _TikTokEmbed(url: url);
    }
    return _ExternalMusicCard(url: url);
  }
}

class _YoutubeSearchEmbed extends StatefulWidget {
  final String url;
  const _YoutubeSearchEmbed({required this.url});
  @override
  State<_YoutubeSearchEmbed> createState() => _YoutubeSearchEmbedState();
}

class _YoutubeSearchEmbedState extends State<_YoutubeSearchEmbed> {
  WebViewController? _controller;
  String? _selectedVideoId;

  @override
  void initState() {
    super.initState();
    // صفحة نتائج يوتيوب (youtube.com/results) ترسل X-Frame-Options:
    // SAMEORIGIN فعليًا — ترفضها كل متصفحات الويب داخل أي إطار من أصل
    // مختلف، قيد من خوادم يوتيوب لا يُحتال عليه بكود؛ فقط رابط /embed/
    // المخصّص مسموح، وغير مناسب لعرض "نتائج بحث". كذلك webview_flutter
    // بلا تنفيذ على الويب أصلًا (كما في tiktok_web_player_web.dart). على
    // الهاتف (WebView أصلي لا إطار HTML) لا ينطبق أي من القيدين.
    if (kIsWeb) return;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final id = _extractYoutubeVideoId(request.url);
          if (id != null) {
            if (mounted) setState(() => _selectedVideoId = id);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    _controller = c;
  }

  String? _extractYoutubeVideoId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return _validYoutubeId(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }
    if (host.contains('youtube.com')) {
      final watch = uri.queryParameters['v'];
      if (watch != null && watch.isNotEmpty) return _validYoutubeId(watch);
      if (uri.pathSegments.length >= 2 && (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed' || uri.pathSegments.first == 'live')) return _validYoutubeId(uri.pathSegments[1]);
    }
    return null;
  }

  String? _validYoutubeId(String? id) {
    if (id == null) return null;
    final v = id.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _selectedVideoId;
    if (id != null) return _InlineYoutubePlayer(videoId: id);
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 160,
          color: context.palette.surfaceHighlight,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.phone_android_rounded, color: Colors.white38, size: 32),
              const SizedBox(height: 8),
              Text('نتائج بحث يوتيوب تظهر داخل تطبيق الهاتف فقط',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 300,
        color: context.palette.surfaceHighlight,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}

class _YoutubeEmbed extends StatelessWidget {
  final String videoId;
  const _YoutubeEmbed({required this.videoId});
  @override
  Widget build(BuildContext context) => _InlineYoutubePlayer(videoId: videoId);
}

class _InlineYoutubePlayer extends ConsumerWidget {
  final String videoId;
  const _InlineYoutubePlayer({required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(miniPlayerProvider.notifier).state = MiniPlayerTrack(
            videoId: videoId,
            title: 'فيديو يوتيوب',
            autoPlay: true,
          );
        },
        child: Container(
          width: double.infinity,
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                YoutubeThumbnail(videoId: videoId),
                const Center(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFFEF1745),
                        size: 44,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111111),
                      borderRadius: BorderRadius.circular(13),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// سوريا تحديدًا محظورة عن تيك توك بطبقتين: عنوان IP الجغرافي، وقراءة شريحة
/// SIM السورية عبر نظام الهاتف داخل التطبيق الأصلي. الثانية لا تنطبق هنا
/// إطلاقًا (صفحة ويب داخل WebView لا تصل لشريحة الهاتف)، فتمرير الرابط عبر
/// خادم Supabase (خارج سوريا) عبر وكيل الحافة tiktok-proxy يتجاوز العائق
/// الوحيد الفعلي المتبقي: IP الجهاز نفسه.
String _tiktokProxied(String url) =>
    'https://aknksnctyqjcsxcwnvdz.supabase.co/functions/v1/tiktok-proxy?url=${Uri.encodeComponent(url)}';

class _TikTokSearchEmbed extends StatefulWidget {
  final String url;
  const _TikTokSearchEmbed({required this.url});
  @override
  State<_TikTokSearchEmbed> createState() => _TikTokSearchEmbedState();
}

class _TikTokSearchEmbedState extends State<_TikTokSearchEmbed> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.loadRequest(Uri.parse(_tiktokProxied(widget.url)));
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
          height: 300,
          color: context.palette.surfaceHighlight,
          child: WebViewWidget(controller: _controller)));
}

class _TikTokEmbed extends StatefulWidget {
  final String url;
  const _TikTokEmbed({required this.url});

  @override
  State<_TikTokEmbed> createState() => _TikTokEmbedState();
}

class _TikTokEmbedState extends State<_TikTokEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF120B1B));
    }
    _controller.loadRequest(Uri.parse(_tiktokProxied(widget.url)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: p.surfaceHighlight,
        height: 360,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _ExternalMusicCard extends StatelessWidget {
  final String url;
  const _ExternalMusicCard({required this.url});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surfaceHighlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: p.accent,
                child: Icon(Icons.music_note, color: p.background)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.textSecondary, fontSize: 12.5),
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
