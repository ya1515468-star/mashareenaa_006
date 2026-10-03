import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'upload_progress.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static SupabaseQueryBuilder table(String name) {
    return client.from(name);
  }

  /// Upload raw bytes through the official Supabase Storage SDK.
  /// The SDK handles multipart encoding, content negotiation and platform
  /// differences consistently on Android/iOS/Web/desktop.
  static Future<String> uploadBinaryToBucket({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
    String? fileName,
  }) => uploadBytesToBucket(
    bucket: bucket,
    path: path,
    bytes: bytes,
    contentType: contentType,
    upsert: false,
    fileName: fileName,
  );

  static Future<String> uploadBytesToBucket({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
    bool upsert = false,
    String? fileName,
  }) async {
    final uid = client.auth.currentUser?.id;
    final session = client.auth.currentSession;
    if (session == null || session.accessToken.isEmpty || uid == null) {
      throw StateError('AUTH_REQUIRED');
    }
    if (bytes.isEmpty) {
      throw StateError('EMPTY_UPLOAD');
    }

    final uploadId = UploadId.next();
    final displayName = fileName ?? path.split('/').last;
    final total = bytes.length;
    UploadProgressBus.begin(
      id: uploadId,
      fileName: displayName,
      bucket: bucket,
      totalBytes: total,
    );

    try {
      final storedPath = await client.storage.from(bucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          cacheControl: '3600',
          contentType: contentType,
          upsert: false,
        ),
      );

      // uploadBinary does not expose transport-level progress. Do not report
      // simulated percentages; only mark the transfer complete once Storage
      // has accepted the object.
      UploadProgressBus.update(
        id: uploadId,
        fileName: displayName,
        bucket: bucket,
        sentBytes: total,
        totalBytes: total,
      );
      await UploadProgressBus.success(
        id: uploadId,
        fileName: displayName,
        bucket: bucket,
        totalBytes: total,
      );

      // Public buckets can safely use a public URL. Private buckets must keep
      // the storage path so readers can obtain a short-lived signed URL from
      // the server; persisting a public URL for them would never work.
      if (_publicBuckets.contains(bucket)) {
        final normalizedStoredPath = storedPath.trim().replaceFirst(RegExp(r'^/+'), '').replaceFirst(RegExp('^${RegExp.escape(bucket)}/'), '');
        final public = client.storage.from(bucket).getPublicUrl(normalizedStoredPath);
        debugPrint('[SupabaseService] upload successful, publicUrl=$public');
        return public;
      }
      if (!_privateBuckets.contains(bucket)) {
        throw StateError('UNKNOWN_BUCKET_VISIBILITY');
      }
      debugPrint('[SupabaseService] upload successful, privatePath=$storedPath');
      return storedPath;
    } on StorageException catch (e) {
      debugPrint('[SupabaseService] storage upload failed: ${e.message}');
      if (currentUploadIdIsActive(uploadId)) {
        await UploadProgressBus.failure(
          id: uploadId,
          fileName: displayName,
          bucket: bucket,
          totalBytes: total,
          error: e,
        );
      }
      throw StateError(_storageExceptionMessage(e));
    } catch (e) {
      debugPrint('[SupabaseService] upload exception: ${e.toString()}');
      if (currentUploadIdIsActive(uploadId)) {
        await UploadProgressBus.failure(
          id: uploadId,
          fileName: displayName,
          bucket: bucket,
          totalBytes: total,
          error: e,
        );
      }
      rethrow;
    }
  }

  static const Set<String> _privateBuckets = {
    'profile-patterns',
    'profile-products',
  };

  static const Set<String> _publicBuckets = {
    'profile-avatars',
    'profile-music',
    'chat-sounds',
    'chat-welcome-images',
    'chat-badges',
    'media',
    'store-media',
    'avatar-frames',
    'name-animations',
  };

  static String _storageExceptionMessage(StorageException error) {
    final status = error.statusCode.toString();
    if (status == '401' || status == '403') {
      return 'ليس لديك صلاحية رفع هذا الملف إلى الخادم.';
    }
    if (status == '413') {
      return 'حجم الملف أكبر من الحد المسموح به لهذا المخزن.';
    }
    if (status == '400') {
      return error.message.isEmpty ? 'ملف أو مسار الرفع غير صالح.' : error.message;
    }
    return error.message.isEmpty
        ? 'تعذر رفع الملف إلى Supabase Storage.'
        : error.message;
  }

  static Future<void> deleteStoragePath({
    required String bucket,
    required String path,
  }) async {
    if (path.trim().isEmpty) return;
    await client.storage.from(bucket).remove([path]);
  }

  static bool currentUploadIdIsActive(String id) => currentUploadProgressId() == id;

  static String? currentUploadProgressId() => UploadProgressBus.current.value?.id;


  /// Helper to construct same public URL from existing SDK getPublicUrl responses
  /// or to compute path extraction if callers only have the full URL.
  static String publicUrlFromBucketPath(String bucket, String path) {
    final cleanPath = path.trim().replaceAll(RegExp(r'^/+'), '');
    if (cleanPath.isEmpty ||
        cleanPath.startsWith('$bucket/') ||
        cleanPath.contains('\\') ||
        cleanPath.contains('..')) {
      throw StateError('INVALID_STORAGE_OBJECT_PATH');
    }
    final base = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
    return '$base/storage/v1/object/public/$bucket/$cleanPath';
  }
}
