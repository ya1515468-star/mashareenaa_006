import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Facebook-style manual avatar crop: the user chooses the visible part of
/// the image before upload. The crop is always square so the final avatar can
/// be rendered consistently at 58x58 with the decorative frame above it.
Future<XFile?> cropAvatarBeforeUpload(BuildContext context, XFile source) async {
  final bytes = await source.readAsBytes();
  if (bytes.isEmpty || !context.mounted) return null;
  final cropped = await showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ManualAvatarCropDialog(bytes: bytes),
  );
  if (cropped == null || cropped.isEmpty) return null;
  return XFile.fromData(
    cropped,
    name: 'avatar_${DateTime.now().millisecondsSinceEpoch}.png',
    mimeType: 'image/png',
  );
}

class _ManualAvatarCropDialog extends StatefulWidget {
  final Uint8List bytes;
  const _ManualAvatarCropDialog({required this.bytes});

  @override
  State<_ManualAvatarCropDialog> createState() => _ManualAvatarCropDialogState();
}

class _ManualAvatarCropDialogState extends State<_ManualAvatarCropDialog> {
  ui.Image? _image;
  Rect? _imageRect;
  Rect? _cropRect;
  bool _resizing = false;
  Offset? _lastFocal;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.bytes, (image) {
      if (!mounted) return;
      setState(() => _image = image);
    });
  }

  Rect _fitImage(Size size, ui.Image image) {
    final scale = math.min(size.width / image.width, size.height / image.height);
    final fitted = Size(image.width * scale, image.height * scale);
    return Rect.fromLTWH(
      (size.width - fitted.width) / 2,
      (size.height - fitted.height) / 2,
      fitted.width,
      fitted.height,
    );
  }

  void _ensureCrop(Rect imageRect) {
    if (_cropRect != null && _cropRect!.overlaps(imageRect)) return;
    final side = math.min(imageRect.width, imageRect.height) * .68;
    _cropRect = Rect.fromCenter(center: imageRect.center, width: side, height: side);
  }

  void _moveCrop(Offset delta, Rect bounds) {
    final current = _cropRect!;
    var next = current.shift(delta);
    if (next.left < bounds.left) next = next.shift(Offset(bounds.left - next.left, 0));
    if (next.top < bounds.top) next = next.shift(Offset(0, bounds.top - next.top));
    if (next.right > bounds.right) next = next.shift(Offset(bounds.right - next.right, 0));
    if (next.bottom > bounds.bottom) next = next.shift(Offset(0, bounds.bottom - next.bottom));
    _cropRect = next;
  }

  void _resizeCrop(Offset localPosition, Rect bounds) {
    final c = _cropRect!;
    final minSide = math.min(96.0, math.min(bounds.width, bounds.height) * .24);
    final maxSide = math.min(bounds.width, bounds.height);
    final center = c.center;
    var side = math.max((localPosition.dx - c.left).abs(), (localPosition.dy - c.top).abs()) * 2;
    side = side.clamp(minSide, maxSide);
    var next = Rect.fromCenter(center: center, width: side, height: side);
    if (next.left < bounds.left) next = next.shift(Offset(bounds.left - next.left, 0));
    if (next.top < bounds.top) next = next.shift(Offset(0, bounds.top - next.top));
    if (next.right > bounds.right) next = next.shift(Offset(bounds.right - next.right, 0));
    if (next.bottom > bounds.bottom) next = next.shift(Offset(0, bounds.bottom - next.bottom));
    _cropRect = next;
  }

  Future<Uint8List?> _exportCrop() async {
    final image = _image;
    final imageRect = _imageRect;
    final crop = _cropRect;
    if (image == null || imageRect == null || crop == null) return null;
    final sx = image.width / imageRect.width;
    final sy = image.height / imageRect.height;
    final source = Rect.fromLTRB(
      ((crop.left - imageRect.left) * sx).clamp(0, image.width.toDouble()),
      ((crop.top - imageRect.top) * sy).clamp(0, image.height.toDouble()),
      ((crop.right - imageRect.left) * sx).clamp(0, image.width.toDouble()),
      ((crop.bottom - imageRect.top) * sy).clamp(0, image.height.toDouble()),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const output = 512.0;
    canvas.drawImageRect(image, source, const Rect.fromLTWH(0, 0, output, output), Paint());
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(output.toInt(), output.toInt());
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return AlertDialog(
      title: const Text('تحديد صورة البروفايل'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: image == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final imageRect = _fitImage(constraints.biggest, image);
                  _imageRect = imageRect;
                  _ensureCrop(imageRect);
                  final crop = _cropRect!;
                  return GestureDetector(
                    onPanStart: (details) {
                      _lastFocal = details.localPosition;
                      _resizing = (details.localPosition - crop.bottomRight).distance < 32;
                    },
                    onPanUpdate: (details) {
                      final last = _lastFocal ?? details.localPosition;
                      final delta = details.localPosition - last;
                      _lastFocal = details.localPosition;
                      setState(() {
                        if (_resizing) {
                          _resizeCrop(details.localPosition, imageRect);
                        } else {
                          _moveCrop(delta, imageRect);
                        }
                      });
                    },
                    onPanEnd: (_) => _lastFocal = null,
                    child: CustomPaint(
                      painter: _CropPainter(image: image, imageRect: imageRect, cropRect: crop),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: () async {
            final result = await _exportCrop();
            if (context.mounted) Navigator.pop(context, result);
          },
          icon: const Icon(Icons.check),
          label: const Text('اعتماد الجزء المحدد'),
        ),
      ],
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final Rect cropRect;
  const _CropPainter({required this.image, required this.imageRect, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withValues(alpha: .78);
    canvas.drawRect(Offset.zero & size, bg);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), imageRect, Paint());

    final shade = Paint()..color = Colors.black.withValues(alpha: .48);
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(outside..fillType = PathFillType.evenOdd, shade);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRect(cropRect, border);

    final handle = Paint()..color = Colors.white;
    canvas.drawCircle(cropRect.bottomRight, 8, handle);
    canvas.drawLine(
      Offset(cropRect.right - 24, cropRect.bottomRight.dy - 2),
      Offset(cropRect.right - 3, cropRect.bottomRight.dy - 2),
      Paint()..color = Colors.black54..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.imageRect != imageRect || oldDelegate.cropRect != cropRect;
}
