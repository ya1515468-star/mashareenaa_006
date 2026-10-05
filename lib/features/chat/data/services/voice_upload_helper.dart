import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/media_upload_service.dart';

class VoiceUploadHelper {
  static Future<String> uploadRecording(
    String path, {
    required bool privateChat,
  }) async {
    final bytes = await XFile(path).readAsBytes();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('لا توجد جلسة مستخدم.');
    if (bytes.isEmpty) throw StateError('التسجيل الصوتي فارغ.');

    // Both room and private voice messages use the same private bucket.
    // The previous room path used the public media bucket and caused 403 uploads.
    const bucket = 'chat-voice';
    final maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw StateError('حجم الرسالة الصوتية يتجاوز 10MB.');
    }

    // انتبه: MediaUploadService.uploadBytes() ينظف اسم المجلد كوحدة واحدة
    // ويستبدل '/' بـ '_'، لذلك لا نمرر هنا مجلدًا يحتوي شرطات مائلة.
    // المسار الصريح يطابق سياسة chat-voice الخاصة للغرف والخاص معًا.
    final safeUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final unique = DateTime.now().microsecondsSinceEpoch;
    const folder = 'voice_private';
    final objectPath = 'chat/$folder/$safeUid/voice_$unique.m4a';

    return MediaUploadService(bucket: bucket).uploadBytesAtPath(
      bytes: bytes,
      fileName: 'voice.m4a',
      path: objectPath,
      contentType: 'audio/mp4',
    );
  }
}
