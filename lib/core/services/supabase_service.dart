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
    // bucket الوسائط الخاص بمستخدمي VIP+ — غير public فعليًا على الخادم،
    // وسياسة RLS للقراءة تتحقق من عضوية القارئ في محادثة الرسالة. كانت
    // chat-media-plus غائبة عن كلا المجموعتين هنا فترمي StateError
    // ("UNKNOWN_BUCKET_VISIBILITY") بعد نجاح كل رفع فعليًا — وهذا بالضبط
    // سبب فشل رفع الرسائل الصوتية/المرفقات لأعضاء VIP+ (مرصود في
    // المراقبة كـ"ليس لديك صلاحية رفع هذا الملف"، رغم أن السبب الحقيقي
    // كان بعد نجاح الرفع لا أثناءه — انظر أيضًا تصحيح مسار المجلد في
    // voice_upload_helper.dart وchat_lobby_page.dart).
    'chat-media-plus',
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

  static final Map<String, _SignedUrlEntry> _signedUrlCache = {};

  /// يُرجِع رابطًا صالحًا للعرض من [pathOrUrl]: إن كان أصلًا رابطًا كاملًا
  /// (bucket عام، كـ"media") يُعاد كما هو بلا أي طلب شبكة إضافي. إن كان
  /// مسار تخزين خامًا (bucket خاص، كـ"chat-media-plus") يُوقَّع عبر جلسة
  /// المستخدم الحالية — محميًا بسياسة RLS نفسها لقراءة ذلك الـbucket (هنا:
  /// التحقق من عضوية القارئ في محادثة الرسالة)، فلا يتجاوز هذا أي صلاحية
  /// لم تكن ممنوحة أصلًا. النتائج تُخزَّن مؤقتًا (أقل من مدة صلاحية
  /// التوقيع الفعلية بهامش أمان) لتفادي توقيع الرابط نفسه مرارًا عند كل
  /// إعادة بناء للودجت.
  static Future<String> resolvePrivateMediaUrl({
    required String bucket,
    required String pathOrUrl,
    int expiresInSeconds = 3600,
  }) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final key = '$bucket:$trimmed';
    final cached = _signedUrlCache[key];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }
    final signed =
        await client.storage.from(bucket).createSignedUrl(trimmed, expiresInSeconds);
    // هامش أمان 10% قبل الانتهاء الفعلي حتى لا يصل رابط شارف على الانتهاء
    // لودجت يعرضه للتو.
    final safeTtl = Duration(seconds: (expiresInSeconds * 0.9).round());
    _signedUrlCache[key] = _SignedUrlEntry(signed, DateTime.now().add(safeTtl));
    return signed;
  }

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

class _SignedUrlEntry {
  final String url;
  final DateTime expiresAt;
  const _SignedUrlEntry(this.url, this.expiresAt);
}
