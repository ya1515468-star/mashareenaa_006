import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'server_fonts.dart';

/// خط رسائل عضو بعينه، للمحادثات الخاصة.
///
/// سياسة قراءة `profiles` تقصر كل عضو على صفّه وحده، فلا يمكن للعميل
/// قراءة `message_font_key` لمحدّثه مباشرة — ولذلك يمرّ هذا عبر الدالة
/// الخادمية `get_message_font_key` التي تُرجع المفتاح وحده.
///
/// المزوّد يضمن أيضًا تنزيل الخط وتسجيله (ServerFonts.ensure) بمجرد معرفة
/// مفتاحه، فيكفي أن تستمع الواجهة إلى ServerFonts.revision لتُعاد البناء
/// بعد جهوزية الخط.
final serverMessageFontKeyProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  try {
    final raw = await Supabase.instance.client
        .rpc('get_message_font_key', params: {'p_uid': uid});
    final key = raw?.toString().trim();
    if (key == null || key.isEmpty) return null;
    await ServerFonts.ensure(key);
    return key;
  } catch (_) {
    // بلا مفتاح يبقى الخط الافتراضي؛ لا يُعطَّل شيء.
    return null;
  }
});

/// يحوّل مفتاح خادمي إلى اسم عائلة جاهز للاستعمال، أو null إن لم يكن
/// الخط محمَّلًا بعد (فيُستعمل الاحتياطي ريثما يجهز).
String? loadedServerFontFamily(String? key) =>
    (key != null && key.isNotEmpty && ServerFonts.isLoaded(key))
        ? ServerFonts.family(key)
        : null;
