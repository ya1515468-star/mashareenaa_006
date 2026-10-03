import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final vipPresencePlusProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, uid) async {
  final rows = await Supabase.instance.client
      .from('user_presence')
      .select('is_online,last_seen,online_started_at,total_online_seconds')
      .eq('user_id', uid)
      .limit(1);
  if (rows.isNotEmpty) {
    return Map<String, dynamic>.from(rows.first);
  }
  return <String, dynamic>{};
});

class VipPresencePlus extends ConsumerWidget {
  final String uid;
  const VipPresencePlus({super.key, required this.uid});

  String _duration(dynamic seconds) {
    final s = (seconds as num?)?.toInt() ?? 0;
    if (s < 60) return '$s ث';
    if (s < 3600) return '${s ~/ 60} د';
    return '${s ~/ 3600} س';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(vipPresencePlusProvider(uid)).valueOrNull ?? const <String, dynamic>{};
    final online = data['is_online'] == true;
    final total = _duration(data['total_online_seconds']);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 7, color: online ? Colors.greenAccent : Colors.white38),
        const SizedBox(width: 4),
        Text(online ? 'متصل • جلسة $total' : 'إجمالي الحضور $total',
            style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
      ],
    );
  }
}
