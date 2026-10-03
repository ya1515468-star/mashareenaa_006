import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../../core/services/supabase_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/gif_inspector.dart';
import '../../../../core/widgets/avatar_frame_metrics.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/upload_progress.dart';

class AvatarFrameUploadRequest {
  final Uint8List bytes;
  final String filename;
  final String name;
  final String gender;
  final int pricePoints;
  final int priceGems;
  final List<String> allowedRoles;
  final int minRank;
  final int? maxRank;
  final AvatarFrameMetrics? metrics;
  final String frameEffect;

  const AvatarFrameUploadRequest({
    required this.bytes,
    required this.filename,
    required this.name,
    required this.gender,
    required this.pricePoints,
    required this.priceGems,
    required this.allowedRoles,
    required this.minRank,
    required this.maxRank,
    this.metrics,
    this.frameEffect = 'pulse_glow',
  });
}

/// Production avatar-frame upload path.
///
/// GIF files remain untouched so animation is preserved. Static image formats
/// are also accepted; the circular inner opening and visual animation are
/// applied at render time, so the source asset never needs to be rewritten.
class AvatarFrameUploadService {
  const AvatarFrameUploadService();

  static const _contentTypes = <String, String>{
    'gif': 'image/gif',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
  };

  static String _extension(String filename) {
    final clean = filename.split('?').first.trim().toLowerCase();
    final dot = clean.lastIndexOf('.');
    return dot < 0 ? '' : clean.substring(dot + 1);
  }

  static bool _hasMagic(Uint8List bytes, String ext) {
    if (bytes.length < 12) return false;
    switch (ext) {
      case 'gif':
        return bytes.length >= 6 &&
            String.fromCharCodes(bytes.sublist(0, 6))
                .startsWith('GIF');
      case 'png':
        return bytes.length >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E &&
            bytes[3] == 0x47 && bytes[4] == 0x0D && bytes[5] == 0x0A &&
            bytes[6] == 0x1A && bytes[7] == 0x0A;
      case 'jpg':
      case 'jpeg':
        return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 &&
            bytes[2] == 0xFF;
      case 'webp':
        return bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      case 'bmp':
        return bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;
      default:
        return false;
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<Map<String, dynamic>> uploadAndCreate(
    AvatarFrameUploadRequest input,
  ) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) throw StateError('AUTH_REQUIRED');
    if (input.bytes.isEmpty) throw StateError('FRAME_EMPTY');
    if (input.bytes.length > 8 * 1024 * 1024) {
      throw StateError('FRAME_SIZE_INVALID');
    }

    final ext = _extension(input.filename);
    final contentType = _contentTypes[ext];
    if (contentType == null) {
      throw StateError('UNSUPPORTED_FRAME_FORMAT:$ext');
    }
    if (!_hasMagic(input.bytes, ext)) {
      throw StateError('INVALID_FRAME_FORMAT:$ext');
    }

    String canonicalGender(String value) {
      switch (value.trim().toLowerCase()) {
        case '':
        case 'all':
        case 'unisex':
        case 'للجميع':
          return 'unisex';
        case 'male':
        case 'man':
        case 'men':
        case 'ذكر':
        case 'رجال':
          return 'male';
        case 'female':
        case 'woman':
        case 'women':
        case 'أنثى':
        case 'نساء':
          return 'female';
        default:
          throw StateError('INVALID_GENDER');
      }
    }

    final normalizedGender = canonicalGender(input.gender);
    var width = 0;
    var height = 0;
    var frames = 1;
    var durationMs = 0;
    final isAnimatedSource = ext == 'gif';

    if (isAnimatedSource) {
      final info = GifInspector.inspect(input.bytes);
      if (info == null) throw StateError('INVALID_GIF');
      width = info.width;
      height = info.height;
      frames = info.numFrames;
      durationMs = info.durationMs;
      if (frames < 1 || frames > 120) {
        throw StateError('FRAME_TOO_MANY_FRAMES:$frames');
      }
      if (durationMs < 16 || durationMs > 120000) {
        throw StateError('FRAME_INVALID_DURATION:$durationMs');
      }
    } else {
      try {
        final image = await _decodeImage(input.bytes);
        width = image.width;
        height = image.height;
        image.dispose();
      } catch (_) {
        throw StateError('INVALID_FRAME_IMAGE');
      }
    }

    if (width < 64 || width > 2048 || height < 64 || height > 2048) {
      throw StateError('FRAME_SIZE_INVALID:${width}x$height');
    }
    if (input.name.trim().isEmpty) throw StateError('FRAME_NAME_REQUIRED');
    if (input.pricePoints < 0 || input.priceGems < 0) {
      throw StateError('INVALID_PRICE');
    }
    final maxRank = input.maxRank;
    if (input.minRank < 0 || (maxRank != null && maxRank < input.minRank)) {
      throw StateError('INVALID_RANK_RANGE');
    }
    final metrics = input.metrics ?? await AvatarFrameMetricsDetector.detect(input.bytes);

    // The catalog RPC requires a positive duration even for static frames.
    // For static sources this is metadata only; visual motion/effects are renderer-side.
    final catalogDurationMs = isAnimatedSource ? durationMs : 1000;
    final storagePath = 'catalog/${const Uuid().v4()}.$ext';
    Object? lastError;
    StackTrace? lastStack;
    final uploadId = UploadId.next();
    UploadProgressBus.begin(
      id: uploadId,
      fileName: input.filename,
      bucket: 'avatar-frames',
      totalBytes: input.bytes.length,
    );

    try {
      await MediaUploadService(bucket: 'avatar-frames').uploadBytesAtPath(
        bytes: input.bytes,
        fileName: input.filename,
        path: storagePath,
        contentType: contentType,
      );

      final assetUrl = SupabaseService.publicUrlFromBucketPath(
        'avatar-frames',
        storagePath,
      );
      final frameKeyPrefix = isAnimatedSource ? 'frame_gif_' : 'frame_static_';
      final frameKey = '$frameKeyPrefix${storagePath.substring(8, 44).replaceAll('-', '')}';

      final dynamic rpc = await client.rpc(
        'admin_create_avatar_frame',
        params: {
          'p_frame_key': frameKey,
          'p_name_ar': input.name.trim(),
          'p_gender': normalizedGender,
          'p_asset_url': assetUrl,
          'p_storage_path': storagePath,
          'p_duration_ms': catalogDurationMs,
          'p_price_points': input.pricePoints,
          'p_price_gems': input.priceGems,
          'p_allowed_role_codes': input.allowedRoles,
          'p_min_rank_level': input.minRank,
          'p_max_rank_level': maxRank,
          'p_animation_mode': isAnimatedSource ? 'gif' : 'static_effect',
          'p_frame_effect': input.frameEffect,
          'p_frame_metrics': metrics.toJson(),
        },
      );

      final body = rpc is Map
          ? Map<String, dynamic>.from(rpc)
          : <String, dynamic>{'ok': true};
      if (body['ok'] != true) throw StateError('FRAME_CATALOG_CREATE_FAILED');

      await UploadProgressBus.success(
        id: uploadId,
        fileName: input.filename,
        bucket: 'avatar-frames',
        totalBytes: input.bytes.length,
      );
      return <String, dynamic>{
        ...body,
        'frame_key': body['frame_key'] ?? frameKey,
        'asset_url': assetUrl,
        'storage_path': storagePath,
        'source_width': width,
        'source_height': height,
        'width': width,
        'height': height,
        'frames': frames,
        'duration_ms': catalogDurationMs,
        'source_format': ext,
        'source_animated': isAnimatedSource,
        'transparency_fixed': !isAnimatedSource,
        'inner_opening': 'circle',
        'inner_opening_ratio': metrics.innerOpeningRatio,
        'inner_center_x': metrics.innerCenterX,
        'inner_center_y': metrics.innerCenterY,
        'inner_opening_detected': metrics.detectedFromTransparency,
        'processing_mode': isAnimatedSource
            ? 'original-gif-circular-render-v5'
            : 'static-image-circular-render-v5',
        'frame_effect': input.frameEffect,
      };
    } on PostgrestException catch (e, st) {
      lastError = StateError('FRAME_CATALOG_CREATE_FAILED: ${e.message}');
      lastStack = st;
      try {
        await SupabaseService.deleteStoragePath(bucket: 'avatar-frames', path: storagePath);
      } catch (_) {}
    } on StorageException catch (e, st) {
      lastError = StateError('STORAGE_UPLOAD_FAILED: ${e.message}');
      lastStack = st;
      try {
        await SupabaseService.deleteStoragePath(bucket: 'avatar-frames', path: storagePath);
      } catch (_) {}
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      try {
        await SupabaseService.deleteStoragePath(bucket: 'avatar-frames', path: storagePath);
      } catch (_) {}
    }

    final error = lastError;
    final stack = lastStack;
    await UploadProgressBus.failure(
      id: uploadId,
      fileName: input.filename,
      bucket: 'avatar-frames',
      totalBytes: input.bytes.length,
      error: error,
    );
    Error.throwWithStackTrace(error, stack);
  }
}
