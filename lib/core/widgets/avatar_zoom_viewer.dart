import 'package:flutter/material.dart';

/// Full-screen avatar viewer with explicit zoom-in / zoom-out buttons.
///
/// Pinch-to-zoom alone is not discoverable (and is awkward with a mouse on
/// web), so the buttons drive the same transformation the gestures do — both
/// paths write to one controller, so the two can never disagree.
Future<void> showAvatarZoomViewer(
  BuildContext context, {
  required String? imageUrl,
  String? title,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _AvatarZoomViewer(imageUrl: imageUrl, title: title),
  );
}

class _AvatarZoomViewer extends StatefulWidget {
  final String? imageUrl;
  final String? title;
  const _AvatarZoomViewer({required this.imageUrl, this.title});

  @override
  State<_AvatarZoomViewer> createState() => _AvatarZoomViewerState();
}

class _AvatarZoomViewerState extends State<_AvatarZoomViewer> {
  final TransformationController _controller = TransformationController();

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _step = 0.5;

  double get _scale => _controller.value.getMaxScaleOnAxis();

  void _setScale(double target) {
    final clamped = target.clamp(_minScale, _maxScale).toDouble();
    setState(() {
      _controller.value = Matrix4.identity()..scaleByDouble(clamped, clamped, clamped, 1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl?.trim() ?? '';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: _minScale,
              maxScale: _maxScale,
              // Keeps the buttons and the gesture in sync.
              onInteractionEnd: (_) => setState(() {}),
              child: Center(
                child: url.isEmpty
                    ? const Icon(Icons.person, size: 120, color: Colors.white38)
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 90,
                          color: Colors.white38,
                        ),
                      ),
              ),
            ),
          ),
          if (widget.title != null && widget.title!.trim().isNotEmpty)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Text(
                widget.title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Positioned(
            top: 30,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              tooltip: 'إغلاق',
            ),
          ),
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ZoomButton(
                  icon: Icons.zoom_out,
                  tooltip: 'تصغير',
                  enabled: _scale > _minScale + 0.01,
                  onTap: () => _setScale(_scale - _step),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_scale * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                _ZoomButton(
                  icon: Icons.zoom_in,
                  tooltip: 'تكبير',
                  enabled: _scale < _maxScale - 0.01,
                  onTap: () => _setScale(_scale + _step),
                ),
                const SizedBox(width: 14),
                _ZoomButton(
                  icon: Icons.restart_alt,
                  tooltip: 'إعادة الضبط',
                  enabled: _scale > _minScale + 0.01,
                  onTap: () => _setScale(_minScale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white24 : Colors.white10,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        tooltip: tooltip,
        icon: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: 26),
      ),
    );
  }
}
