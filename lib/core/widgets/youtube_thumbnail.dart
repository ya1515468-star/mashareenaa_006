import 'package:flutter/material.dart';

/// YouTube thumbnail with deterministic fallback URLs.
/// The fallback chain avoids depending on a single image host/quality.
class YoutubeThumbnail extends StatelessWidget {
  final String videoId;
  final String? preferredUrl;
  final BoxFit fit;

  const YoutubeThumbnail({
    super.key,
    required this.videoId,
    this.preferredUrl,
    this.fit = BoxFit.cover,
  });

  List<String> get _urls {
    final preferred = preferredUrl?.trim() ?? '';
    return <String>[
      if (preferred.isNotEmpty) preferred,
      'https://i.ytimg.com/vi/$videoId/hq720.jpg',
      'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/sddefault.jpg',
      'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/0.jpg',
    ];
  }

  Widget _image(int index, List<String> urls) {
    if (index >= urls.length) {
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
      urls[index],
      fit: fit,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
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
      errorBuilder: (_, __, ___) => _image(index + 1, urls),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (videoId.trim().isEmpty) {
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
    return _image(0, _urls);
  }
}
