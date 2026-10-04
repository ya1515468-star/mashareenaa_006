import '../../../../core/widgets/fullscreen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/services/chat_media_url_resolver.dart';
import '../../domain/entities/chat_message_entity.dart';
import 'voice_message_player.dart';

class ChatMediaContent extends StatelessWidget {
  final ChatMessageEntity message;
  final double maxWidth;
  final bool vipPlus;
  final VoidCallback? onMore;
  final ValueChanged<String>? onGifTap;
  const ChatMediaContent({
    super.key,
    required this.message,
    required this.maxWidth,
    this.vipPlus = false,
    this.onMore,
    this.onGifTap,
  });

  bool get _asset => message.mediaUrl?.startsWith('assets/') == true;
  bool _private(String value) => ChatMediaUrlResolver.bucketForPath(value) != null;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_private(url)) {
      return _ResolvedChatMedia(
        rawUrl: url,
        builder: (resolved) => _buildWithUrl(context, resolved),
      );
    }
    return _buildWithUrl(context, url);
  }

  Widget _buildWithUrl(BuildContext context, String url) {
    switch (message.type) {
      case MessageType.gif:
        const smileySize = 22.0;
        final tile = SizedBox(
          width: smileySize,
          height: smileySize,
          child: _box(
            _asset
                ? Image.asset(url, fit: BoxFit.contain)
                : Image.network(url, fit: BoxFit.contain),
          ),
        );
        final child = SizedBox(
          width: 40,
          height: 40,
          child: Center(child: tile),
        );
        return Align(
          alignment: Alignment.centerRight,
          child: onGifTap == null
              ? child
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onGifTap!(url),
                  child: child,
                ),
        );
      case MessageType.image:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _asset ? null : () => showFullscreenImage(context, url, onMore: onMore),
          child: _box(_asset
              ? Image.asset(url, width: maxWidth, height: maxWidth * (vipPlus ? .82 : .72), fit: BoxFit.cover)
              : Image.network(url, width: maxWidth, height: maxWidth * (vipPlus ? .82 : .72), fit: BoxFit.cover)),
        );
      case MessageType.video:
        return _VideoPreview(url: url, width: maxWidth);
      case MessageType.audio:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: VoiceMessagePlayer(url: url),
        );
      case MessageType.file:
        return _OpenCard(
          icon: Icons.insert_drive_file,
          label: message.text.isEmpty ? 'ملف مرفق' : message.text,
          url: url,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _box(Widget c) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(color: Colors.black12, child: c),
      );
}

class _ResolvedChatMedia extends StatefulWidget {
  final String rawUrl;
  final Widget Function(String) builder;
  const _ResolvedChatMedia({required this.rawUrl, required this.builder});
  @override
  State<_ResolvedChatMedia> createState() => _ResolvedChatMediaState();
}

class _ResolvedChatMediaState extends State<_ResolvedChatMedia> {
  late Future<String> _future;
  @override
  void initState() {
    super.initState();
    _future = ChatMediaUrlResolver.resolve(widget.rawUrl);
  }
  @override
  void didUpdateWidget(covariant _ResolvedChatMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl) _future = ChatMediaUrlResolver.resolve(widget.rawUrl);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _future,
        builder: (_, snap) {
          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.lock_outline_rounded, color: Colors.white38),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return widget.builder(snap.data!);
        },
      );
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
          final resolved = await ChatMediaUrlResolver.resolve(url);
          final uri = Uri.tryParse(resolved);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 16),
          ]),
        ),
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
  WebViewController? _controller;
  @override
  void initState() {
    super.initState();
    _load(widget.url);
  }
  Future<void> _load(String raw) async {
    final src = await ChatMediaUrlResolver.resolve(raw);
    if (!mounted) return;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString('<html><body style="margin:0;background:#000"><video src="${Uri.encodeFull(src)}" controls playsinline style="width:100%;height:100%;object-fit:contain"></video></body></html>');
    setState(() => _controller = c);
  }
  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return SizedBox(
      width: widget.width,
      height: widget.width * .72,
      child: c == null ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : WebViewWidget(controller: c),
    );
  }
}
