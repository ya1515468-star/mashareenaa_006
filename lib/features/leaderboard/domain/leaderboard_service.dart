import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

/// صف واحد في أي لائحة صدارة — يكفي uid + القيمة الرقمية، تُجلب
/// بيانات الاسم/الصورة لاحقًا في الواجهة عبر profileByIdProvider
/// (بدل تكرارها هنا) حتى تبقى محدَّثة دائمًا.
class LeaderboardEntry {
  final String uid;
  final int value;
  const LeaderboardEntry({required this.uid, required this.value});
}

/// ميزة 2+3 من القائمة الإضافية: لائحتا صدارة — الأعلى نقاطًا
/// (تراكميًا)، والأعلى إهداءً هذا الأسبوع (من gift_transactions).
class LeaderboardService {
  static Future<List<LeaderboardEntry>> _rpc(String kind,
      {int limit = 50}) async {
    final rows = await Supabase.instance.client.rpc('get_chat_leaderboard',
        params: {'p_kind': kind, 'p_limit': limit});
    return List<Map<String, dynamic>>.from(rows as List)
        .map((row) => LeaderboardEntry(
            uid: row['user_id']?.toString() ?? '',
            value: (row['value'] as num?)?.toInt() ?? 0))
        .where((e) => e.uid.isNotEmpty)
        .toList();
  }

  static Future<List<LeaderboardEntry>> topPoints({int limit = 50}) =>
      _rpc('points', limit: limit);
  static Future<List<LeaderboardEntry>> topGiftersThisWeek({int limit = 50}) =>
      _rpc('gifts', limit: limit);
  static Future<List<LeaderboardEntry>> topGems({int limit = 50}) =>
      _rpc('gems', limit: limit);
  static Future<List<LeaderboardEntry>> topInteractions({int limit = 50}) =>
      _rpc('interactions', limit: limit);
  static Future<List<LeaderboardEntry>> topPresence({int limit = 50}) =>
      _rpc('presence', limit: limit);
}
