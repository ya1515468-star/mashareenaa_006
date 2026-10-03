import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/supabase_document_compat.dart';
import '../../subscriptions/domain/entities/subscription_tier_entity.dart';

/// عضو واحد في "طاقم الإدارة" — uid ورمز رتبته الإدارية، تُجلب بيانات
/// الاسم/الصورة لاحقًا في الواجهة عبر profileByIdProvider (نفس نمط
/// LeaderboardEntry) حتى تبقى محدَّثة دائمًا.
class DirectoryEntry {
  final String uid;
  final String label;
  const DirectoryEntry({required this.uid, required this.label});
}

/// استعلامات مباشرة على جداول Supabase الخام (user_roles/roles) بنفس
/// البنية المستخدمة فعليًا في RbacRemoteDataSourceImpl — عناصر قائمة
/// الشات 8 و10 و11 (العرش الملكي، طاقم الإدارة، التواصل مع DRAGON)
/// لا تستحق كل واحدة منها Repository/UseCase كامل، فهذه خدمة قراءة
/// خفيفة مخصَّصة لواجهة الشات فقط، على غرار LeaderboardService.
class LobbyDirectoryService {
  LobbyDirectoryService._();

  static const _adminRoleCodes = [
    AppRoles.dragon,
    AppRoles.superAdmin,
    AppRoles.admin,
    AppRoles.moderator,
    AppRoles.support,
    AppRoles.auditor,
  ];

  static const _roleLabelsAr = {
    AppRoles.dragon: 'مالك المنصة — DRAGON',

    AppRoles.superAdmin: 'مشرف عام',
    AppRoles.admin: 'إداري',
    AppRoles.moderator: 'مراقب',
    AppRoles.support: 'دعم فني',
    AppRoles.auditor: 'مدقق',
  };

  /// "طاقم الإدارة الذين يختارهم صاحب المنصة" — كل من يحمل رتبة
  /// إدارية فعلية حاليًا (وليس قائمة يدوية منفصلة، لتبقى متزامنة مع
  /// شاشة "الأدوار والصلاحيات" في لوحة الإدارة دون ازدواج مصدر).
  static Future<List<DirectoryEntry>> fetchAdminTeam({int limit = 50}) async {
    final db = Supabase.instance.client;
    final roleRows = await db
        .from('roles')
        .select('id, code, priority')
        .inFilter('code', _adminRoleCodes);
    final rows = List<Map<String, dynamic>>.from(roleRows);
    if (rows.isEmpty) return const [];

    rows.sort((a, b) =>
        ((b['priority'] as num?) ?? 0).compareTo((a['priority'] as num?) ?? 0));
    final codeByRoleId = {for (final r in rows) r['id']: r['code'] as String?};

    final userRoleRows = await db
        .from('user_roles')
        .select('user_id, role_id')
        .inFilter('role_id', rows.map((r) => r['id']).toList());

    final entries = <DirectoryEntry>[];
    for (final row in List<Map<String, dynamic>>.from(userRoleRows)) {
      final uid = row['user_id'] as String?;
      final code = codeByRoleId[row['role_id']];
      if (uid == null || code == null) continue;
      entries.add(DirectoryEntry(uid: uid, label: _roleLabelsAr[code] ?? code));
    }
    if (entries.length > limit) return entries.sublist(0, limit);
    return entries;
  }

  /// التواصل مع مدير المنصة يعتمد حصراً على حامل رتبة DRAGON.
  static Future<String?> findPlatformOwnerUid() async {
    final db = Supabase.instance.client;
    final roleRow = await db
        .from('roles')
        .select('id')
        .eq('code', AppRoles.dragon)
        .maybeSingle();
    final roleId = roleRow?['id'];
    if (roleId == null) return null;
    final userRow = await db
        .from('user_roles')
        .select('user_id')
        .eq('role_id', roleId)
        .limit(1)
        .maybeSingle();
    return userRow?['user_id'] as String?;
  }

  /// "العرش الملكي للعضويات المدفوعة" — أعلى الأعضاء عضويةً حاليًا
  /// (وليس تراكميًا)، مرتَّبين حسب رتبة الفئة في SubscriptionCatalog
  /// (الأعلى سعرًا/مزايا أولًا). يقرأ accounts.subscription.tierId
  /// مباشرة لأن هذا الحقل غير مفهرَس في قاعدة صدارة منفصلة.
  static Future<List<DirectoryEntry>> fetchTopSubscribers(
      {int limit = 25}) async {
    final tierRank = <String, int>{
      for (var i = 0; i < SubscriptionCatalog.all.length; i++)
        SubscriptionCatalog.all[i].id: i,
    };
    final tierNames = <String, String>{
      for (final t in SubscriptionCatalog.all) t.id: t.name,
    };
    final snap = await SupabaseDocumentStore.instance
        .collection(BackendCollections.accounts)
        .get();

    // (uid, tierId, rank) قبل التحويل لـ DirectoryEntry — نحتفظ برتبة
    // الفئة صراحةً بدل استرجاعها لاحقًا من الاسم، تجنّبًا لأي التباس
    // إن تشابهت أسماء فئتين مستقبلًا.
    final ranked = <({String uid, String tierId, int rank})>[];
    for (final doc in snap.docs) {
      final sub = doc.data()['subscription'];
      final tierId = sub is Map ? sub['tierId'] as String? : null;
      if (tierId == null ||
          tierId == SubscriptionCatalog.freeTierId ||
          !tierRank.containsKey(tierId)) {
        continue;
      }
      ranked.add((uid: doc.id, tierId: tierId, rank: tierRank[tierId]!));
    }
    ranked.sort((a, b) => b.rank.compareTo(a.rank));
    final top = ranked.length > limit ? ranked.sublist(0, limit) : ranked;
    return top
        .map((e) =>
            DirectoryEntry(uid: e.uid, label: tierNames[e.tierId] ?? e.tierId))
        .toList();
  }
}


