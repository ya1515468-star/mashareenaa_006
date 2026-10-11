import 'package:mashareena/core/utils/safe_launch.dart';
import 'dart:async';
import 'youtube_control_bar.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/youtube_origin.dart';
import '../theme/app_theme.dart';
import '../providers/mini_player_provider.dart';
import '../services/youtube_guard.dart';
import 'tiktok_web_player_stub.dart'
    if (dart.library.html) 'tiktok_web_player_web.dart';

/// يكتشف نوع الرابط الموسيقي/المرئي المُشارَك ويعرضه المناسب:
/// - رابط يوتيوب (watch أو youtu.be): يُضمَّن مباشرة داخل التطبيق
///   عبر WebView مضبوط على وضع التضمين الرسمي (youtube.com/embed) —
///   إلا إن طُلب [routeYoutubeToFloatingPlayer]، فتُعرَض بطاقة مصغّرة
///   تُشغِّل الأغنية حصرًا عبر المشغّل العائم العام بدل تضمينها هنا
///   (مطلوب لرسائل الشات تحديدًا: "تشغيله حصرًا بمشغل عائم").
/// - أي رابط آخر (SoundCloud، Spotify، إلخ): بطاقة تشغيل بسيطة تفتح
///   الرابط في التطبيق الخارجي المناسب عبر url_launcher، لأن تضمين
///   كل منصة موسيقى بمشغلها الخاص يحتاج SDK منفصلًا لكل منصة.
class EmbeddedMediaPlayer extends StatelessWidget {
  final String url;
  /// true لرسائل الشات (غرفة أو خاص): يوتيوب يفتح عبر المشغّل العائم
  /// فقط، لا تضمينًا داخل الفقاعة. false (الافتراضي) يحافظ على السلوك
  /// القديم في السياقات الأخرى (الملف الشخصي، حائط الأصدقاء) التي لم
  /// يطلب أحد تغييرها.
  final bool routeYoutubeToFloatingPlayer;
  const EmbeddedMediaPlayer({
    super.key,
    required this.url,
    this.routeYoutubeToFloatingPlayer = false,
  });

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
      if (routeYoutubeToFloatingPlayer) {
        return _YoutubeFloatingLaunchCard(videoId: videoId);
      }
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

/// بطاقة مصغّرة لرابط يوتيوب داخل رسائل الشات: لا تضمين فيديو هنا إطلاقًا
/// — الضغط عليها يُشغِّل الأغنية حصرًا عبر المشغّل العائم العام
/// (miniPlayerProvider)، المستمر في الخلفية وعبر التنقّل بين الشاشات،
/// بدل مشغّل مضمَّن مستقل داخل كل فقاعة رسالة على حدة.
class _YoutubeFloatingLaunchCard extends ConsumerStatefulWidget {
  final String videoId;
  const _YoutubeFloatingLaunchCard({required this.videoId});
  @override
  ConsumerState<_YoutubeFloatingLaunchCard> createState() =>
      _YoutubeFloatingLaunchCardState();
}

class _YoutubeFloatingLaunchCardState
    extends ConsumerState<_YoutubeFloatingLaunchCard> {
  String? _title;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchTitle());
  }

  /// يوتيوب يوفّر نقطة oEmbed عامة (بلا مفتاح API) تُرجع عنوان الفيديو
  /// الحقيقي؛ بدونها لا سبيل لمعرفة اسم الأغنية من مجرّد رابط مُرسَل كنص.
  Future<void> _fetchTitle() async {
    try {
      final res = await http.get(Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${widget.videoId}&format=json'));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _title = data['title']?.toString());
      }
    } catch (_) {
      // عنوان افتراضي يكفي؛ هذا تجميل لا أكثر.
    }
  }

  void _playInFloatingPlayer() {
    ref.read(miniPlayerProvider.notifier).state = MiniPlayerTrack(
      videoId: widget.videoId,
      title: _title ?? 'فيديو يوتيوب',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final nowPlaying =
        ref.watch(miniPlayerProvider)?.videoId == widget.videoId;
    const gold = Color(0xFFFFD700);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _playInFloatingPlayer,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.surfaceHighlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: nowPlaying ? gold : p.divider),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
              width: 56,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 40,
                color: Colors.black26,
                child: const Icon(Icons.music_note, color: Colors.white38, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title ?? 'فيديو يوتيوب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  nowPlaying ? 'قيد التشغيل في المشغّل العائم' : 'اضغط للتشغيل في المشغّل العائم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: nowPlaying ? gold : p.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Icon(
            nowPlaying ? Icons.graphic_eq_rounded : Icons.play_circle_fill_rounded,
            color: nowPlaying ? gold : p.accent,
            size: 26,
          ),
        ]),
      ),
    );
  }
}

class _InlineYoutubePlayer extends StatefulWidget {
  final String videoId;
  const _InlineYoutubePlayer({required this.videoId});
  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer> {
  // ثلاث محاولات متتالية هنا أخطأت، وأوثّقها حتى لا تتكرر الدائرة نفسها:
  //   ١) الإعداد الافتراضي للمكتبة → "This video is unavailable, 152-4".
  //   ٢) ضبط origin على نطاق التطبيق، ظنًّا أنه Referer فقط → اتضح من
  //      مصدر المكتبة (assets/player.html) أن نفس القيمة تُستعمل أيضًا
  //      كـhost الذي يُحمَّل منه مشغّل يوتيوب نفسه، وهو نطاق وهمي غير
  //      موجود، فلم يُحمَّل أي شيء — الصندوق الأسود.
  //   ٣) إبقاء host الحقيقي، ثم إعادة تحميل المشغّل مرة واحدة بعد
  //      جهوزيته بـbaseUrl مختلف لتصحيح الـReferer → هذه إعادة التحميل
  //      نفسها قاطعت تهيئة جلسة يوتيوب في منتصفها، فأنتج يوتيوب خطأه
  //      العام "An error occurred. (Playback ID: …)" — جلسة بدأت فعلًا
  //      (host صحيح) لكن تعطّلت بسبب تدخّلي، لا بسبب يوتيوب.
  //
  // لا مزيد من التدخل اليدوي بمسار المصادقة. هذا هو الاستعمال القياسي
  // للمكتبة بإعدادها الافتراضي تمامًا — نفس ما تستعمله غالبية التطبيقات
  // المنشورة بهذه الحزمة بنجاح لفيديوهات يوتيوب العامة العادية.
  late final YoutubePlayerController _controller = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: true,
    params: const YoutubePlayerParams(
          origin: kYoutubeEmbedOrigin,
      showControls: true,
      showFullscreenButton: true,
      // Browsers commonly block autoplay with sound; start muted so the link starts immediately,
      // while YouTube's own controls allow the user to unmute.
      mute: true,
      strictRelatedVideos: false,
    ),
  );

  // يوتيوب يستخدم WebView داخليًا، والـWebView يبقى حيًّا لحظيًا بعد
  // dispose() ريثما يُنظَّف الـplatform view. أي frame callback مجدوَل
  // منه (كتحديث لون الخلفية) قد يُستدعى بعد أن صار الـState
  // "defunct" فيحاول الوصول إلى context ويرمي "This widget has been
  // unmounted". العلم يمنع أي عمل إضافي بعد التفكيك بلا الحاجة لتغيير
  // الحزمة نفسها.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // فحص خادمي: إن كان الفيديو ممنوع التضمين نبدّله ببديل قابل للتضمين.
    final asked = widget.videoId;
    YoutubeGuard.resolve(asked, '').then((r) {
      if (_disposed || !mounted) return;
      if (r.replaced && widget.videoId == asked) {
        _controller.loadVideoById(videoId: r.videoId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_disposed) return;
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadVideoById(videoId: widget.videoId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      // يوتيوب يشترط ألا يقل المشغّل المضمَّن عن 200×200 بكسل. في فقاعة الشات
      // كان ارتفاعه بنسبة 16:9 حوالي 146 فقط (عرض الفقاعة ~258)، فيُرفض.
      // النسبة تُحسب بحيث لا يقل الارتفاع عن 200 مهما كان عرض الفقاعة.
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : 320.0;
          final h = (w * 9 / 16) < 200 ? 200.0 : w * 9 / 16;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            YoutubePlayer(controller: _controller, aspectRatio: w / h),
            Container(
              color: const Color(0xFF14101F),
              width: double.infinity,
              child: YoutubeControlBar(controller: _controller),
            ),
          ]);
        },
      ),
    );
  }
}

/// سوريا تحديدًا محظورة عن تيك توك بطبقتين: عنوان IP الجغرافي، وقراءة شريحة
/// SIM السورية عبر نظام الهاتف داخل التطبيق الأصلي. الثانية لا تنطبق هنا
/// إطلاقًا (صفحة ويب داخل WebView لا تصل لشريحة الهاتف)، فتمرير الرابط عبر
/// خادم Supabase (خارج سوريا) عبر وكيل الحافة tiktok-proxy يتجاوز العائق
/// الوحيد الفعلي المتبقي: IP الجهاز نفسه.
String _tiktokProxied(String url) {
  // الوكيل يشترط جلسة مستخدم صالحة (توكن في الرابط لأن WebView لا يرسل
  // رأس Authorization بطلب التنقل الأول).
  final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
  return 'https://aknksnctyqjcsxcwnvdz.supabase.co/functions/v1/tiktok-proxy?t=${Uri.encodeComponent(token)}&url=${Uri.encodeComponent(url)}';
}

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
          safeLaunch(url),
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
