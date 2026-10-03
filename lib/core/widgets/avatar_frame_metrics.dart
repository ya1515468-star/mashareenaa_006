import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Measured opening geometry for an avatar frame asset.
/// Values are normalized to the frame's full raster dimensions.
class AvatarFrameMetrics {
  final double innerOpeningRatio;
  final double innerCenterX;
  final double innerCenterY;
  final bool detectedFromTransparency;

  const AvatarFrameMetrics({
    required this.innerOpeningRatio,
    required this.innerCenterX,
    required this.innerCenterY,
    required this.detectedFromTransparency,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'inner_opening_ratio': innerOpeningRatio,
        'inner_center_x': innerCenterX,
        'inner_center_y': innerCenterY,
        'detected_from_transparency': detectedFromTransparency,
      };

  static AvatarFrameMetrics fromMap(Map<String, dynamic>? map) {
    final ratio = (map?['inner_opening_ratio'] as num?)?.toDouble() ?? 0.74;
    final cx = (map?['inner_center_x'] as num?)?.toDouble() ?? 0.5;
    final cy = (map?['inner_center_y'] as num?)?.toDouble() ?? 0.5;
    return AvatarFrameMetrics(
      innerOpeningRatio: ratio.clamp(0.45, 0.94).toDouble(),
      innerCenterX: cx.clamp(0.08, 0.92).toDouble(),
      innerCenterY: cy.clamp(0.08, 0.92).toDouble(),
      detectedFromTransparency: map?['detected_from_transparency'] == true,
    );
  }
}

class AvatarFrameMetricsDetector {
  const AvatarFrameMetricsDetector._();

  static Future<AvatarFrameMetrics> detect(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return _fallback();
      return _detectFromRgba(data, image.width, image.height);
    } catch (_) {
      return _fallback();
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static AvatarFrameMetrics _detectFromRgba(ByteData data, int width, int height) {
    final pixels = data.buffer.asUint8List();
    final minSide = math.min(width, height).toDouble();
    final half = minSide / 2.0;
    const angleCount = 24;
    final candidates = <({double x, double y})>[];
    final cx0 = width * 0.5;
    final cy0 = height * 0.5;
    final stepX = width * 0.035;
    final stepY = height * 0.035;

    for (var iy = -2; iy <= 2; iy++) {
      for (var ix = -2; ix <= 2; ix++) {
        candidates.add((x: cx0 + ix * stepX, y: cy0 + iy * stepY));
      }
    }

    double bestClearance = -1;
    double bestX = cx0;
    double bestY = cy0;
    for (final candidate in candidates) {
      var clearance = half;
      for (var i = 0; i < angleCount; i++) {
        final angle = (math.pi * 2 * i) / angleCount;
        final dx = math.cos(angle);
        final dy = math.sin(angle);
        var lastTransparent = 0.0;
        for (var r = 0.0; r <= half; r += math.max(1.0, minSide / 256.0)) {
          final x = (candidate.x + dx * r).round();
          final y = (candidate.y + dy * r).round();
          if (x < 0 || x >= width || y < 0 || y >= height) break;
          final index = (y * width + x) * 4;
          final alpha = pixels[index + 3];
          if (alpha <= 48) {
            lastTransparent = r;
            continue;
          }
          clearance = math.min(clearance, lastTransparent);
          break;
        }
      }
      if (clearance > bestClearance) {
        bestClearance = clearance;
        bestX = candidate.x;
        bestY = candidate.y;
      }
    }

    if (bestClearance < minSide * 0.10) return _fallback();

    final ratio = ((bestClearance * 2) / minSide).clamp(0.45, 0.94).toDouble();
    return AvatarFrameMetrics(
      innerOpeningRatio: ratio,
      innerCenterX: (bestX / width).clamp(0.08, 0.92).toDouble(),
      innerCenterY: (bestY / height).clamp(0.08, 0.92).toDouble(),
      detectedFromTransparency: true,
    );
  }

  static AvatarFrameMetrics _fallback() => const AvatarFrameMetrics(
        innerOpeningRatio: 0.74,
        innerCenterX: 0.5,
        innerCenterY: 0.5,
        detectedFromTransparency: false,
      );
}
