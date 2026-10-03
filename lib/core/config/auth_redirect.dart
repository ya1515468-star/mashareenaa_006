import 'package:flutter/foundation.dart' show kIsWeb;

/// إلى أين يعود المستخدم بعد الضغط على رابط تأكيد البريد.
/// على الهاتف: رابط عميق يفتح التطبيق (مسجّل في AndroidManifest.xml).
/// على الويب: أصل الصفحة نفسها.
/// يجب إضافة القيمتين إلى Authentication → URL Configuration → Redirect URLs
/// في لوحة Supabase، وإلا تجاهلهما Supabase وحوّل إلى Site URL.
const String kMobileAuthRedirect = 'com.mashareena.mashareena://login-callback';

String authRedirectUrl() => kIsWeb ? Uri.base.origin : kMobileAuthRedirect;
