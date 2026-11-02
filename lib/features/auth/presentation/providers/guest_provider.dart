import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مفاتيح صلاحيات الزائر كما هي في `public.feature_flags`.
///
/// المالك أو السوبر أدمن يفتحها ويغلقها من لوحته بلا إصدار جديد من
/// التطبيق، والقرار يُنفَّذ **خادميًا** داخل الدوال نفسها. ما هنا
/// للواجهة فقط: إطفاء زر راحةٌ للمستخدم لا حمايةٌ له.
class GuestFeatures {
  const GuestFeatures._();

  static const String signup = 'guest_signup';
  static const String privateChat = 'guest_private_chat';
  static const String calls = 'guest_calls';
  static const String gifts = 'guest_gifts';
  static const String purchases = 'guest_purchases';
  static const String uploads = 'guest_uploads';
  static const String cosmetics = 'guest_cosmetics';
}

class GuestState {
  /// هل المستخدم الحالي زائر لم يُرقِّ حسابه ببريد مؤكَّد؟
  final bool isGuest;

  /// المفتاح ← (مسموح؟، رسالة القفل كما كتبها المالك).
  final Map<String, ({bool allowed, String message})> features;

  const GuestState({required this.isGuest, required this.features});

  static const empty = GuestState(isGuest: false, features: {});

  /// هل تُسمح هذه الميزة للمستخدم الحالي؟ العضو المسجَّل يمرّ دائمًا.
  bool allows(String flag) {
    if (!isGuest) return true;
    return features[flag]?.allowed ?? false;
  }

  String messageFor(String flag) =>
      features[flag]?.message ?? 'سجّل ببريدك الإلكتروني لتفتح هذه الميزة.';

  factory GuestState.fromRpc(dynamic raw) {
    if (raw is! Map) return empty;
    final featuresRaw = raw['features'];
    final out = <String, ({bool allowed, String message})>{};
    if (featuresRaw is Map) {
      featuresRaw.forEach((key, value) {
        if (value is Map) {
          out[key.toString()] = (
            allowed: value['allowed'] == true,
            message: value['message']?.toString() ??
                'سجّل ببريدك الإلكتروني لتفتح هذه الميزة.',
          );
        }
      });
    }
    return GuestState(isGuest: raw['is_guest'] == true, features: out);
  }
}

/// حالة الزائر وصلاحياته من الخادم عبر استدعاء واحد.
///
/// يُبطَّل بعد الدخول كزائر وبعد اكتمال الترقية، فتُرفَع القيود فورًا
/// بلا إعادة تشغيل التطبيق.
final guestStateProvider = FutureProvider<GuestState>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return GuestState.empty;
  try {
    final raw = await client.rpc('get_my_guest_state');
    return GuestState.fromRpc(raw);
  } catch (_) {
    // فشل القراءة لا يجوز أن يقفل التطبيق على عضو مسجَّل. والمنع
    // الحقيقي خادمي على كل حال، فالافتراض المتساهل هنا آمن.
    return GuestState.empty;
  }
});

/// اختصار متزامن للواجهة: هل أنا زائر؟ يُقرأ من الجلسة مباشرة حتى قبل
/// وصول استدعاء الخادم، فلا تومض الأزرار.
final isGuestSessionProvider = Provider<bool>((ref) {
  final async = ref.watch(guestStateProvider);
  return async.maybeWhen(
    data: (state) => state.isGuest,
    orElse: () => Supabase.instance.client.auth.currentUser?.isAnonymous ?? false,
  );
});

/// هل تُسمح ميزة بعينها؟ للاستعمال المباشر في `ref.watch`.
final guestAllowsProvider = Provider.family<bool, String>((ref, flag) {
  final async = ref.watch(guestStateProvider);
  return async.maybeWhen(
    data: (state) => state.allows(flag),
    // ريثما تصل الحالة: العضو المسجَّل لا يُقيَّد، والزائر يُقيَّد.
    orElse: () =>
        !(Supabase.instance.client.auth.currentUser?.isAnonymous ?? false),
  );
});
