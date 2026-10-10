import 'package:url_launcher/url_launcher.dart';

/// يفتح الروابط الخارجية فقط إذا كانت http/https ولها مضيف صالح.
/// يمنع مخططات خطرة مثل intent: و file: و javascript: و tel: القادمة من
/// محتوى المستخدمين (رسائل، ملفات شخصية، أدلة بلاغات...).
Uri? safeHttpUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final s = uri.scheme.toLowerCase();
  if (s != 'http' && s != 'https') return null;
  return uri;
}

Future<bool> safeLaunch(String? raw,
    {LaunchMode mode = LaunchMode.externalApplication}) async {
  final uri = safeHttpUri(raw);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}
