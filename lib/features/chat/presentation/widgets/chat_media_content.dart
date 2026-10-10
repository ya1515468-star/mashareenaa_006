import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../domain/entities/chat_message_entity.dart';
import 'voice_message_player.dart';
import '../../data/gif_catalog.dart';

class ChatMediaContent extends StatelessWidget {
  final ChatMessageEntity message;
  final double maxWidth;
  final bool vipPlus;

  /// يفتح قائمة الفقاعة (رد، اقتباس، مشاركة، حذف) من عارض الصورة.
  final VoidCallback? onMore;

  /// الضغط على سمايل متحرك مرسَل يرسله مرة أخرى فورًا (نفس السمايل، بلا
  /// نافذة اختيار) — الخاص يرسل فورًا بخلاف الغرفة التي تضعه في الصندوق أولًا.
  final ValueChanged<String>? onGifTap;
  const ChatMediaContent(
      {super.key,
      required this.message,
      required this.maxWidth,
      this.vipPlus = false,
      this.onMore,
      this.onGifTap});
  bool get _asset => message.mediaUrl?.startsWith('assets/') == true;

  /// mediaUrl المخزَّن قد يكون مسار تخزين خامًا (لا رابطًا جاهزًا) حين
  /// يأتي من bucket خاص — تحديدًا chat-media-plus لمستخدمي VIP+، الذي
  /// يتطلّب توقيعًا عبر جلسة القارئ الحالية (محميًا بسياسة RLS التي تتحقق
  /// من عضويته في محادثة الرسالة) قبل أن يصلح لأي عرض فعلي. bucket
  /// "media" العام يُعيد رابطًا كاملًا جاهزًا دائمًا فلا يمر بهذا المسار
  /// إطلاقًا — صفر تغيير سلوك للحالة الشائعة.
  bool get _needsSigning =>
      !_asset &&
      !(message.mediaUrl?.startsWith('http://') == true ||
          message.mediaUrl?.startsWith('https://') == true);

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_needsSigning) {
      return FutureBuilder<String>(
        future: SupabaseService.resolvePrivateMediaUrl(
            bucket: 'chat-media-plus', pathOrUrl: url),
        builder: (context, snap) {
          if (!snap.hasData) {
            const side = 40.0;
            return const SizedBox(
              width: side,
              height: side,
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return _buildForUrl(context, snap.data!);
        },
      );
    }
    return _buildForUrl(context, url);
  }

  Widget _buildForUrl(BuildContext context, String url) {
    switch (message.type) {
      case MessageType.gif:
        // Match the visual footprint of normal WhatsApp-style chat emojis.
        // GIF smileys are media, but their box stays the same compact size.
        final banner = isMashareenaBannerGif(url);
        final smileySize = 22.0;
        final tile = SizedBox(
          width: banner ? 150.0 : smileySize,
          height: banner ? 47.0 : smileySize,
          child: _box(_asset
              ? Image.asset(url, fit: BoxFit.contain)
              : Image.network(url, fit: BoxFit.contain)),
        );
        // كان بلا أي onTap هنا؛ الميزة (الضغط على سمايل مرسَل يرسله مرة
        // أخرى فورًا) لم تكن موجودة في الخاص إطلاقًا، رغم وجودها في
        // الغرف. لقمة لمس 40×40 حول الصورة 22×22 حتى لا يحتاج الضغط دقة
        // بكسل.
        //
        final gifWidget = onGifTap == null
            ? tile
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onGifTap!(url),
                child: SizedBox(width: banner ? 150.0 : 40, height: banner ? 47.0 : 40, child: Center(child: tile)),
              );
        // الـColumn المحيطة بمحتوى الفقاعة في message_bubble.dart تستعمل
        // CrossAxisAlignment.stretch (لازمة لعناصر أخرى فيها)، فتُجبر حتى
        // SizedBox ذات عرض صريح (40) على التمدد لعرض الفقاعة الكامل —
        // فيظهر السمايل في المنتصف (مع Center الداخلي) أو يسارًا بحسب
        // اتجاه الفقاعة المحيط، لا يمينًا كبقية عناصر التطبيق. Align
        // بمحاذاة مطلقة (لا تابعة للاتجاه) يفرض الموضع الصحيح بصرف النظر
        // عن تمدد الأب.
        return Align(alignment: Alignment.centerRight, child: gifWidget);
      case MessageType.image:
        // الضغط يفتح الصورة كاملة بملء الشاشة.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _asset ? null : () => showFullscreenImage(context, url, onMore: onMore),
          child: _box(_asset
              ? Image.asset(url,
                  width: maxWidth, height: maxWidth * (vipPlus ? .82 : .72), fit: BoxFit.cover)
              : Image.network(url,
                  width: maxWidth, height: maxWidth * (vipPlus ? .82 : .72), fit: BoxFit.cover)),
        );
      case MessageType.video:
        return _VideoPreview(url: url, width: maxWidth);
      case MessageType.audio:
        // كانت تُفتح خارج التطبيق عبر launchUrl — لا مشغّل داخلي إطلاقًا.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: VoiceMessagePlayer(url: url),
        );
      case MessageType.file:
        return _OpenCard(
            icon: Icons.insert_drive_file,
            label: message.text.isEmpty ? 'ملف مرفق' : message.text,
            url: url);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _box(Widget c) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(color: Colors.black12, child: c));
}

class _OpenCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  const _OpenCard({required this.icon, required this.label, required this.url});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(label,
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, size: 16)
            ])),
      );
}

class _VideoPreview extends StatefulWidget {
  final String url;
  final double width;
  const _VideoPreview({required this.url, required this.width});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  WebViewController? _webController;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    // webview_flutter ليست له أي تطبيق فعلي على الويب لكل الواجهة —
    // setNavigationDelegate الداخلي (يُستدعى ضمنًا حتى بلا طلبه صراحةً)
    // يستدعي setOnPageStarted فيرمي UnimplementedError هناك تحديدًا؛
    // هذا بالضبط ما رُصد في المراقبة على نسخة الويب. على الويب نستعمل
    // video_player (مدعومة أصلًا) بدل تضمين WebView لعرض وسم <video>
    // HTML؛ الجوال والسطح يبقيان على مسار WebView نفسه بلا أي تغيير.
    if (kIsWeb) {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _videoController = c;
      c.setLooping(false);
      c.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    } else {
      final src = Uri.encodeFull(widget.url);
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadHtmlString(
            '<html><body style="margin:0;background:#000"><video src="$src" controls playsinline style="width:100%;height:100%;object-fit:contain"></video></body></html>');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * .72;
    final webController = _webController;
    if (webController != null) {
      return SizedBox(
          width: widget.width,
          height: height,
          child: WebViewWidget(controller: webController));
    }
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) {
      return SizedBox(
        width: widget.width,
        height: height,
        child: const ColoredBox(
          color: Colors.black26,
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        vc.value.isPlaying ? vc.pause() : vc.play();
      }),
      child: SizedBox(
        width: widget.width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(alignment: Alignment.center, children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: vc.value.size.width,
                height: vc.value.size.height,
                child: VideoPlayer(vc),
              ),
            ),
            AnimatedOpacity(
              opacity: vc.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                color: Colors.black26,
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
