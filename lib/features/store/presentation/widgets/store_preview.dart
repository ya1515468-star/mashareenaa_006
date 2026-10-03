import 'package:flutter/material.dart';

class StoreGifPreview extends StatelessWidget {
  final String assetPath;
  final String alt;
  final bool interactionPrompt;

  const StoreGifPreview({
    super.key,
    required this.assetPath,
    this.alt = '',
    this.interactionPrompt = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        color: const Color(0xFF100B1D),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          semanticLabel: alt,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.auto_awesome, size: 36, color: Colors.white70),
        ),
      ),
    );
  }
}

class ProductGifViewer extends StatelessWidget {
  final String assetPath;
  final String productName;

  const ProductGifViewer({
    super.key,
    required this.assetPath,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) =>
      StoreGifPreview(assetPath: assetPath, alt: productName);
}
