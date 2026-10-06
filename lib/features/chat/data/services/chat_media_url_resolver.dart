import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMediaUrlResolver {
  const ChatMediaUrlResolver._();

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static bool _isStorageSignUrl(Uri uri) {
    final p = uri.pathSegments;
    return p.length >= 4 &&
        p[0] == 'storage' &&
        p[1] == 'v1' &&
        p[2] == 'object' &&
        p[3] == 'sign';
  }

  static String? _bucketFromStorageUrl(Uri uri) {
    final p = uri.pathSegments;
    final objectIndex = p.indexOf('object');
    if (objectIndex < 0 || p.length <= objectIndex + 2) return null;
    final mode = p[objectIndex + 1];
    if (mode != 'public' && mode != 'authenticated' && mode != 'sign') {
      return null;
    }
    final bucket = p[objectIndex + 2];
    return bucket.isEmpty ? null : bucket;
  }

  static String? _objectPathFromStorageUrl(Uri uri, String bucket) {
    final p = uri.pathSegments;
    final objectIndex = p.indexOf('object');
    if (objectIndex < 0 || p.length <= objectIndex + 3) return null;
    final mode = p[objectIndex + 1];
    if (mode != 'public' && mode != 'authenticated' && mode != 'sign') {
      return null;
    }
    if (p[objectIndex + 2] != bucket) return null;
    final objectPath = p.sublist(objectIndex + 3).join('/');
    return objectPath.isEmpty ? null : objectPath;
  }

  static String? bucketForPath(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw.startsWith('assets/')) return null;

    if (_isHttpUrl(raw)) {
      final uri = Uri.tryParse(raw);
      if (uri == null || _isStorageSignUrl(uri)) return null;
      final bucket = _bucketFromStorageUrl(uri);
      if (bucket == 'chat-voice' || bucket == 'chat-media-plus') {
        return bucket;
      }
      return null;
    }

    // Accept canonical object paths and legacy DB values that included the
    // bucket name as a prefix. The bucket must never become part of the
    // Storage object path.
    if (raw.startsWith('chat-voice/chat/voice_private/')) return 'chat-voice';
    if (raw.startsWith('chat-media-plus/chat/attachments/')) return 'chat-media-plus';
    if (raw.startsWith('voice_private/')) return 'chat-voice';
    if (raw.startsWith('chat/voice_private/')) return 'chat-voice';
    if (raw.startsWith('chat/voice_room/')) return 'media';
    if (raw.startsWith('chat/attachments/')) return 'chat-media-plus';
    return null;
  }

  static Future<String> resolve(String value) async {
    final raw = value.trim();
    if (raw.isEmpty || raw.startsWith('assets/')) return raw;

    final bucket = bucketForPath(raw);
    if (bucket == null) return raw;

    if (_isHttpUrl(raw)) {
      final uri = Uri.tryParse(raw);
      if (uri == null || _isStorageSignUrl(uri)) return raw;

      final objectPath = _objectPathFromStorageUrl(uri, bucket);
      if (objectPath == null) return raw;

      if (bucket == 'media') return raw;

      return Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(objectPath, 3600);
    }

    if (bucket == 'media') {
      final objectPath = raw.startsWith('$bucket/')
          ? raw.substring(bucket.length + 1)
          : raw;
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(objectPath);
    }

    // Normalize legacy private-voice rows before asking Storage for a signed
    // URL. Never pass a relative path to audioplayers on Android: that is the
    // direct cause of the ENOENT/FileInputStream failure seen in older builds.
    var objectPath = raw.startsWith('$bucket/')
        ? raw.substring(bucket.length + 1)
        : raw;
    if (bucket == 'chat-voice' && objectPath.startsWith('voice_private/')) {
      objectPath = 'chat/$objectPath';
    }
    if (bucket == 'chat-voice' && !objectPath.startsWith('chat/voice_private/')) {
      objectPath = objectPath.startsWith('chat/')
          ? objectPath
          : 'chat/voice_private/$objectPath';
    }
    final signed = await Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(objectPath, 3600);
    if (!signed.startsWith('http://') && !signed.startsWith('https://')) {
      throw StateError('VOICE_SIGNED_URL_INVALID');
    }
    return signed;
  }
}
