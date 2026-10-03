import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authoritative numeric rank shown on the avatar in public chat.
/// The score is derived from server-side XP earned through allowed activity
/// events (presence, chat interaction, and purchases).
final serverUserRankBadgeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, uid) async {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return const <String, dynamic>{};

  try {
    final raw = await Supabase.instance.client.rpc(
      'get_user_chat_rank_badge',
      params: <String, dynamic>{'p_user_id': normalizedUid},
    );
    if (raw is Map && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw);
    }
  } catch (_) {
    // The legacy server rank endpoint below is a server-authoritative fallback
    // while the newest rank badge migration is being deployed.
  }

  try {
    final raw = await Supabase.instance.client.rpc(
      'get_live_chat_rank_display',
      params: <String, dynamic>{'p_uid': normalizedUid},
    );
    if (raw is Map && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw);
    }
  } catch (_) {
    // A missing/temporarily unavailable server endpoint must not crash chat.
  }

  return const <String, dynamic>{};
});

class ServerRankBadge extends ConsumerWidget {
  final String uid;
  final double diameter;

  const ServerRankBadge({
    super.key,
    required this.uid,
    this.diameter = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serverUserRankBadgeProvider(uid));
    return async.when(
      data: (rank) {
        final rawScore = rank['score'] ?? rank['rank_score'] ?? rank['xp'] ?? rank['rank'];
        final score = rawScore is num ? rawScore.toInt() : int.tryParse('$rawScore') ?? 0;
        if (score <= 0) return const SizedBox.shrink();

        final rawLevel = rank['rank_level'];
        final level = rawLevel is num ? rawLevel.toInt() : int.tryParse('$rawLevel') ?? 1;
        final size = diameter.clamp(18.0, 22.0).toDouble();

        return Container(
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1FA89A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$score',
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
            semanticsLabel: 'رتبة $score المستوى $level',
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
