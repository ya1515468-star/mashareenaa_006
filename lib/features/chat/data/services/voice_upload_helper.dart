import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/media_upload_service.dart';

/// رفع تسجيل صوتي من مساره المحلي وإرجاع رابطه. كانت هذه الدالة جزءًا من
/// ورقة تسجيل منفصلة (VoiceRecorderSheet) أُزيلت بالكامل (البند ٩: لا
/// صفحة صوتية منفصلة، زر تسجيل واحد واضح فقط) — استُخرجت هنا لتبقى
/// مشتركة مع VoiceHoldButton دون إبقاء أي أثر لتلك الصفحة.
class VoiceUploadHelper {
  /// [extension] يجب أن يطابق الترميز الفعلي الذي سجّل به VoiceHoldButton
  /// (m4a على الجوال، webm على الويب) — تسمية الملف بامتداد لا يطابق
  /// محتواه الحقيقي هي ما كان يكسر التشغيل على الويب (DEMUXER_ERROR).
  static Future<String> uploadRecording(
    String path, {
    String extension = 'm4a',
  }) async {
    final bytes = await XFile(path).readAsBytes();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('لا توجد جلسة مستخدم.');
    final vipRaw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': 'chat_media_plus'},
    );
    final vipPlus = vipRaw is Map && vipRaw['enabled'] == true;
    if (bytes.length > (vipPlus ? 25 : 10) * 1024 * 1024) {
      throw StateError(vipPlus
          ? 'حد الوسائط Plus هو 25MB.'
          : 'الحد الأساسي للوسائط الصوتية 10MB؛ فعّل وسائط Plus للوصول إلى 25MB.');
    }
    return MediaUploadService(bucket: vipPlus ? 'chat-media-plus' : 'media').uploadBytes(
      bytes: bytes,
      fileName: 'voice_.$extension',
      // سياسة RLS على bucket "chat-media-plus" (لمستخدمي VIP+) تفرض شكل
      // المسار حرفيًا: chat/attachments/<uid>/... — أي مجلد آخر هنا كان
      // يُرفَض خادميًا بخطأ 403 "ليس لديك صلاحية رفع هذا الملف" (مرصود
      // فعليًا). bucket "media" العادي لا يتقيّد بهذا، فالتوحيد هنا آمن
      // للطرفين معًا.
      folder: 'chat/attachments',
      uid: uid,
      // audio/webm (لا video/webm العام) — متوافق فعليًا مع عنصر <audio>
      // في كل المتصفحات الحديثة لملف صوتي خالص بامتداد webm.
      contentType: extension == 'webm' ? 'audio/webm' : null,
    );
  }
}
