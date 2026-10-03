import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed profile visitor tracking.
class ProfileVisitorsService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<void> recordVisit({
    required String profileUid,
    required String visitorUid,
  }) async {
    if (profileUid == visitorUid) return;
    final currentUid = _sb.auth.currentUser?.id;
    if (currentUid == null || currentUid != visitorUid) {
      throw const AuthException('جلسة المستخدم غير صالحة');
    }
    await _sb.rpc('record_profile_visit', params: {
      'p_profile_uid': profileUid,
    });
  }

  // كانت watchVisitorsCount/watchRecentVisitorUids تقرآن مباشرة من جدول
  // profile_visitors عبر سياسة RLS التي تتحقق فقط من "هل هذا ملفك"، بلا أي
  // فحص لملكية خدمة VIP "معرفة زوار الملف" (profile_visitors) — بخلاف
  // get_my_profile_visitors الخادمية التي تتحقق من الملكية أولًا وترفض
  // بوضوح إن لم تكن مملوكة. المسارين لم يكونا نفس المسار: كانت هذه الدوال
  // كودًا غير مستخدَم حاليًا في أي شاشة حقيقية (تأكدت بالبحث)، لكنها كانت
  // نافذة ملتوية جاهزة تمنح ميزة مدفوعة مجانًا لأي مطوّر يستخدمها لاحقًا
  // ظانًّا أنها الطريق الصحيح. حُوّلت لتستخدم الدالة الخادمية المحمية نفسها،
  // فلا يبقى مسار غير محمي في المشروع إطلاقًا لهذه البيانات.
  static Future<int> fetchVisitorsCount(String profileUid) async {
    final rows = await _sb.rpc('get_my_profile_visitors', params: {'p_limit': 200});
    return (rows as List).length;
  }

  static Future<List<String>> fetchRecentVisitorUids(
    String profileUid, {
    int limit = 20,
  }) async {
    final rows = await _sb.rpc('get_my_profile_visitors',
        params: {'p_limit': limit.clamp(1, 200)});
    return (rows as List)
        .map((r) => (r as Map)['visitor_uid'].toString())
        .toList();
  }
}

final recordProfileVisitProvider = FutureProvider.autoDispose
    .family<void, ({String profileUid, String visitorUid})>((ref, args) {
  return ProfileVisitorsService.recordVisit(
    profileUid: args.profileUid,
    visitorUid: args.visitorUid,
  );
});

final profileVisitorsCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) {
  return ProfileVisitorsService.fetchVisitorsCount(uid);
});
