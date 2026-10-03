import 'package:flutter/material.dart';
import '../../features/store/presentation/widgets/store_preview.dart';

/// Animated GIF ambient shell for hero areas.
class AmbientGifWorld extends StatelessWidget {
  final Widget child;
  final String asset;
  const AmbientGifWorld(
      {super.key,
      required this.child,
      this.asset = 'assets/store_gifs/background/background_50.gif'});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            child: Opacity(
                opacity: 0.14,
                child: StoreGifPreview(
                    assetPath: asset, alt: 'Mashareena ambient background'))),
        child,
      ]);
}
