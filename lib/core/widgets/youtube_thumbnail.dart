import 'package:flutter/material.dart';

/// Reliable YouTube thumbnail with a small fallback chain.
class YoutubeThumbnail extends StatefulWidget {
  final String videoId;
  final String? preferredUrl;
  final BoxFit fit;

  const YoutubeThumbnail({
    super.key,
    required this.videoId,
    this.preferredUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> {
  int _index = 0;

  List<String> get _urls {
    final preferred = widget.preferredUrl?.trim() ?? '';
    return <String>[
      if (preferred.isNotEmpty) preferred,
      'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
      'https://img.youtube.com/vi/${widget.videoId}/maxresdefault.jpg',
      'https://i.ytimg.com/vi/${widget.videoId}/0.jpg',
    ];
  }

  @override
  void didUpdateWidget(covariant YoutubeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.preferredUrl != widget.preferredUrl) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (_index >= urls.length) {
      return const ColoredBox(
        color: Color(0xFF171126),
        child: Center(
          child: Icon(
            Icons.ondemand_video_rounded,
            color: Color(0xFFBDA7FF),
            size: 34,
          ),
        ),
      );
    }

    return Image.network(
      urls[_index],
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (!mounted) return const SizedBox.shrink();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index++);
        });
        return const ColoredBox(
          color: Color(0xFF171126),
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white24,
              size: 26,
            ),
          ),
        );
      },
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF171126),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
        );
      },
    );
  }
}
