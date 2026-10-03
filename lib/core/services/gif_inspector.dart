import 'dart:typed_data';

/// Lightweight GIF parser used only for client-side upload validation.
///
/// It intentionally has no third-party dependencies so Flutter Web/Android
/// installs are not coupled to archive/POSIX transitive packages.
class GifInfo {
  final int width;
  final int height;
  final int numFrames;
  final int durationMs;

  const GifInfo({
    required this.width,
    required this.height,
    required this.numFrames,
    required this.durationMs,
  });
}

class GifInspector {
  const GifInspector._();

  static GifInfo? inspect(Uint8List bytes) {
    if (bytes.length < 13) return null;
    final header = String.fromCharCodes(bytes.sublist(0, 6));
    if (header != 'GIF87a' && header != 'GIF89a') return null;

    final width = _u16(bytes, 6);
    final height = _u16(bytes, 8);
    if (width <= 0 || height <= 0) return null;

    final packed = bytes[10];
    var offset = 13;
    if ((packed & 0x80) != 0) {
      final entries = 1 << ((packed & 0x07) + 1);
      final tableBytes = entries * 3;
      if (offset + tableBytes > bytes.length) return null;
      offset += tableBytes;
    }

    var frameCount = 0;
    var totalDuration = 0;
    var pendingDelayMs = 100;
    var sawTrailer = false;

    try {
      while (offset < bytes.length) {
        final block = bytes[offset++];
        switch (block) {
          case 0x3B: // Trailer
            sawTrailer = true;
            offset = bytes.length;
            break;

          case 0x21: // Extension
            if (offset >= bytes.length) return null;
            final label = bytes[offset++];
            switch (label) {
              case 0xF9: // Graphic Control Extension
                if (offset >= bytes.length || bytes[offset++] != 4) return null;
                if (offset + 4 > bytes.length) return null;
                final delayCs = _u16(bytes, offset + 1);
                pendingDelayMs = delayCs <= 0 ? 100 : delayCs * 10;
                offset += 4;
                if (offset >= bytes.length || bytes[offset++] != 0) return null;
                break;

              case 0x01: // Plain Text Extension: fixed 12-byte header, then sub-blocks.
                if (offset >= bytes.length) return null;
                final blockSize = bytes[offset++];
                if (blockSize != 12 || offset + blockSize > bytes.length) return null;
                offset += blockSize;
                offset = _skipSubBlocks(bytes, offset);
                if (offset < 0) return null;
                break;

              case 0xFF: // Application Extension: fixed 11-byte header, then sub-blocks.
                if (offset >= bytes.length) return null;
                final blockSize = bytes[offset++];
                if (blockSize != 11 || offset + blockSize > bytes.length) return null;
                offset += blockSize;
                offset = _skipSubBlocks(bytes, offset);
                if (offset < 0) return null;
                break;

              case 0xFE: // Comment Extension: sub-blocks immediately follow.
                offset = _skipSubBlocks(bytes, offset);
                if (offset < 0) return null;
                break;

              default:
                // Unknown extension labels are safely skipped as sub-blocks.
                offset = _skipSubBlocks(bytes, offset);
                if (offset < 0) return null;
                break;
            }
            break;

          case 0x2C: // Image Descriptor
            if (offset + 9 > bytes.length) return null;
            final frameWidth = _u16(bytes, offset + 4);
            final frameHeight = _u16(bytes, offset + 6);
            final imagePacked = bytes[offset + 8];
            if (frameWidth <= 0 || frameHeight <= 0) return null;
            offset += 9;

            if ((imagePacked & 0x80) != 0) {
              final entries = 1 << ((imagePacked & 0x07) + 1);
              final tableBytes = entries * 3;
              if (offset + tableBytes > bytes.length) return null;
              offset += tableBytes;
            }

            if (offset >= bytes.length) return null;
            final lzwMinimumCodeSize = bytes[offset++];
            if (lzwMinimumCodeSize < 2 || lzwMinimumCodeSize > 8) return null;
            offset = _skipSubBlocks(bytes, offset);
            if (offset < 0) return null;

            frameCount++;
            totalDuration += pendingDelayMs.clamp(10, 5000);
            pendingDelayMs = 100;
            break;

          default:
            return null;
        }
      }
    } on RangeError {
      return null;
    }

    if (!sawTrailer || frameCount < 1) return null;
    return GifInfo(
      width: width,
      height: height,
      numFrames: frameCount,
      durationMs: totalDuration,
    );
  }

  static int _u16(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _skipSubBlocks(Uint8List bytes, int offset) {
    while (true) {
      if (offset >= bytes.length) return -1;
      final size = bytes[offset++];
      if (size == 0) return offset;
      if (offset + size > bytes.length) return -1;
      offset += size;
    }
  }
}

