import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../error/exceptions.dart';
import 'supabase_service.dart';

/// Canonical cross-platform upload gateway for all user/admin media.
///
/// It accepts bytes/XFile so the same code works on Android, Web and desktop,
/// validates size/extension/signatures where practical, creates safe unique
/// object names, and delegates the actual Storage operation to
/// [SupabaseService].
class MediaUploadService {
  MediaUploadService({this.bucket = 'media'});

  final String bucket;

  static const Map<String, int> maxBytes = {
    'profile-avatars': 8 * 1024 * 1024,
    'avatar-frames': 8 * 1024 * 1024,
    'name-animations': 8 * 1024 * 1024,
    'chat-sounds': 5 * 1024 * 1024,
    'profile-music': 5 * 1024 * 1024,
    'media': 10 * 1024 * 1024,
    'chat-media-plus': 25 * 1024 * 1024,
    'chat-badges': 8 * 1024 * 1024,
    'chat-welcome-images': 8 * 1024 * 1024,
    'profile-patterns': 15 * 1024 * 1024,
    'profile-products': 25 * 1024 * 1024,
    'store-media': 25 * 1024 * 1024,
  };

  static const Map<String, Set<String>> allowedExtensions = {
    'profile-avatars': {'png', 'jpg', 'jpeg', 'webp', 'gif'},
    'avatar-frames': {'gif', 'png', 'jpg', 'jpeg', 'webp', 'bmp'},
    'name-animations': {'gif'},
    'chat-sounds': {'mp3', 'wav', 'ogg', 'm4a', 'aac', 'webm'},
    'profile-music': {'mp3', 'wav', 'ogg', 'm4a', 'aac', 'webm'},
    'chat-badges': {'gif', 'png', 'jpg', 'jpeg', 'webp'},
    'chat-welcome-images': {'gif'},
    'profile-patterns': {'png', 'jpg', 'jpeg', 'webp', 'gif', 'pdf', 'zip'},
    'profile-products': {'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov'},
    'store-media': {
      'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov',
      'mp3', 'm4a', 'wav', 'ogg', 'aac', 'zip', 'pdf'
    },
    'chat-media-plus': {
      'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov',
      'mp3', 'm4a', 'wav', 'ogg', 'aac', 'pdf', 'zip'
    },
    'media': {
      'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov',
      'mp3', 'm4a', 'wav', 'ogg', 'aac', 'zip', 'pdf'
    },
  };

  /// Uploads using the canonical path convention for ordinary user media.
  Future<String> uploadFile({
    required XFile file,
    required String folder,
    required String uid,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      fileName: file.name,
      folder: folder,
      uid: uid,
    );
  }

  Future<String> uploadBytes({
    required List<int> bytes,
    required String fileName,
    required String folder,
    required String uid,
  }) async {
    final ext = _extension(fileName);
    _validate(bytes: bytes, fileName: fileName, ext: ext, uid: uid);
    final safeFolder = _cleanPart(folder);
    final safeUid = _cleanPart(uid);
    final safeName = _cleanFileName(fileName, ext);
    final path = bucket == 'profile-avatars'
        ? '$safeUid/${_uniqueName(safeName)}'
        : '$safeFolder/$safeUid/${_uniqueName(safeName)}';
    return uploadBytesAtPath(
      bytes: bytes,
      fileName: fileName,
      path: path,
      contentType: _contentTypeFor(ext),
    );
  }

  /// Uploads to an already-authorized canonical path. Admin/room-specific
  /// Storage policies remain authoritative on the server.
  Future<String> uploadBytesAtPath({
    required List<int> bytes,
    required String fileName,
    required String path,
    String? contentType,
  }) async {
    final ext = _extension(fileName);
    _validatePath(path);
    _validate(bytes: bytes, fileName: fileName, ext: ext);
    try {
      return await SupabaseService.uploadBytesToBucket(
        bucket: bucket,
        path: path,
        bytes: bytes,
        contentType: contentType ?? _contentTypeFor(ext),
        upsert: false,
        fileName: _cleanFileName(fileName, ext),
      );
    } catch (e, st) {
      debugPrint('[MediaUploadService] upload failed bucket=$bucket: $e');
      debugPrint(st.toString());
      if (e is ServerException) rethrow;
      throw ServerException(message: 'لم يتم رفع الملف: $e');
    }
  }

  Future<void> deleteFile(String urlOrPath) async {
    final path = _extractStoragePath(urlOrPath.trim()) ??
        (urlOrPath.contains('/') ? urlOrPath : null);
    if (path == null || path.isEmpty) return;
    try {
      await SupabaseService.deleteStoragePath(bucket: bucket, path: path);
    } catch (e, st) {
      debugPrint('[MediaUploadService] failed removing $bucket/$path: $e');
      debugPrint(st.toString());
    }
  }

  void _validate({
    required List<int> bytes,
    required String fileName,
    required String ext,
    String? uid,
  }) {
    if (bytes.isEmpty) {
      throw const ServerException(message: 'الملف فارغ أو غير قابل للقراءة.');
    }
    if (uid != null && uid.trim().isEmpty) {
      throw const ServerException(message: 'جلسة المستخدم غير صالحة.');
    }
    final allowed = allowedExtensions[bucket];
    if (allowed != null && !allowed.contains(ext)) {
      throw const ServerException(message: 'نوع الملف غير مسموح به.');
    }
    final max = maxBytes[bucket];
    if (max != null && bytes.length > max) {
      throw ServerException(
        message: 'حجم الملف يتجاوز الحد المسموح (${(max / 1024 / 1024).round()}MB).',
      );
    }
    _validateSignature(bytes, ext);
  }

  void _validatePath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.startsWith('\\') ||
        normalized.contains('..') ||
        normalized.contains('\\')) {
      throw const ServerException(message: 'مسار الرفع غير صالح.');
    }
    if (bucket == 'avatar-frames' &&
        (!normalized.startsWith('catalog/') ||
            normalized.startsWith('avatar-frames/'))) {
      throw const ServerException(
        message: 'مسار إطار الصورة يجب أن يبدأ بـ catalog/ داخل bucket avatar-frames.',
      );
    }
  }

  void _validateSignature(List<int> bytes, String ext) {
    bool startsWith(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i] != signature[i]) return false;
      }
      return true;
    }

    final valid = switch (ext) {
      'png' => startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      'jpg' || 'jpeg' => startsWith(const [0xFF, 0xD8, 0xFF]),
      'gif' => startsWith(const [0x47, 0x49, 0x46, 0x38, 0x37]) ||
          startsWith(const [0x47, 0x49, 0x46, 0x38, 0x39]),
      'webp' => startsWith(const [0x52, 0x49, 0x46, 0x46]) && bytes.length >= 12 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50,
      'bmp' => startsWith(const [0x42, 0x4D]),
      'pdf' => startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D]),
      'zip' => startsWith(const [0x50, 0x4B, 0x03, 0x04]) ||
          startsWith(const [0x50, 0x4B, 0x05, 0x06]) ||
          startsWith(const [0x50, 0x4B, 0x07, 0x08]),
      _ => true,
    };
    if (!valid) {
      throw const ServerException(message: 'محتوى الملف لا يطابق امتداده.');
    }
  }

  String? _extractStoragePath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final marker = segments.indexOf('public');
    if (marker < 0 || marker + 2 >= segments.length) return null;
    if (segments[marker + 1] != bucket) return null;
    return segments.sublist(marker + 2).join('/');
  }

  String _extension(String name) {
    final n = name.toLowerCase();
    final dot = n.lastIndexOf('.');
    if (dot < 0 || dot == n.length - 1) return 'bin';
    return n.substring(dot + 1);
  }

  String _cleanPart(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  String _cleanFileName(String value, String ext) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final base = cleaned.isEmpty ? 'upload' : cleaned;
    return base.toLowerCase().endsWith('.$ext') ? base : '$base.$ext';
  }

  String _uniqueName(String safeName) =>
      '${DateTime.now().microsecondsSinceEpoch}_${_nonce()}_$safeName';

  String _nonce() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  String _contentTypeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        'json' => 'application/json',
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'zip' => 'application/zip',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
}
