import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/media_upload_service.dart';

/// رفع تسجيل صوتي من مساره المحلي وإرجاع رابطه. كانت هذه الدالة جزءًا من
/// ورقة تسجيل منفصلة (VoiceRecorderSheet) أُزيلت بالكامل (البند ٩: لا
/// صفحة صوتية منفصلة، زر تسجيل واحد واضح فقط) — استُخرجت هنا لتبقى
/// مشتركة مع VoiceHoldButton دون إبقاء أي أثر لتلك الصفحة.
class VoiceUploadHelper {
  static Future<String> uploadRecording(String path) async {
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
      fileName: 'voice_.m4a',
      folder: 'chat/audio',
      uid: uid,
    );
  }
}
