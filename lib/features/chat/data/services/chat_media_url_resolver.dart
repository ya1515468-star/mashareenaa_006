import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMediaUrlResolver {
  const ChatMediaUrlResolver._();

  static bool _isAbsolute(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String? bucketForPath(String value) {
    if (_isAbsolute(value) || value.startsWith('assets/')) return null;
    if (value.startsWith('chat/voice_private/')) return 'chat-voice';
    if (value.startsWith('chat/attachments/')) return 'chat-media-plus';
    return null;
  }

  static Future<String> resolve(String value) async {
    final raw = value.trim();
    if (raw.isEmpty || _isAbsolute(raw) || raw.startsWith('assets/')) return raw;
    final bucket = bucketForPath(raw);
    if (bucket == null) return raw;
    return Supabase.instance.client.storage.from(bucket).createSignedUrl(raw, 3600);
  }
}
