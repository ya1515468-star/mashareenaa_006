import '../../../gamification/domain/entities/username_effect.dart';
import '../../../gamification/presentation/widgets/username_effect_text.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/monitoring/error_monitor.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canonical server-authoritative user identity used by chat/profile surfaces.
/// The optional roomId is required whenever a room-specific role/priority is
/// expected. The server remains the only authority for role/rank/permissions.
typedef ServerIdentityRequest = ({String uid, String? roomId});

Future<Map<String, dynamic>> _fetchServerIdentity(
  String uid,
  String? roomId,
) async {
  final raw = await Supabase.instance.client.rpc(
    'get_user_chat_identity',
    params: <String, dynamic>{
      'p_user_id': uid,
      'p_room_id': roomId,
    },
  );
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

final serverUserIdentityProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, uid) async {
  return _fetchServerIdentity(uid, null);
});

final serverUserIdentityInRoomProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ServerIdentityRequest>((ref, request) async {
  return _fetchServerIdentity(request.uid, request.roomId);
});

class ServerUserIdentityBadges extends ConsumerWidget {
  final String uid;
  final String? roomId;
  final double fontSize;
  final bool showAchievements;
  final bool compact;
  final bool ownerOnlyRole;
  final bool showChatBadge;

  /// يُخفي شارة الرتبة تحديدًا حين تُرسَم في مكان آخر (تحت الأفاتار
  /// في الشات، مثلًا) لتجنّب ازدواجها بجانب الاسم في الوقت نفسه.
  final bool hideRole;

  const ServerUserIdentityBadges({
    super.key,
    required this.uid,
    this.roomId,
    this.fontSize = 10,
    this.showAchievements = false,
    this.compact = true,
    this.ownerOnlyRole = false,
    this.showChatBadge = true,
    this.hideRole = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = roomId == null
        ? ref.watch(serverUserIdentityProvider(uid))
        : ref.watch(
            serverUserIdentityInRoomProvider((uid: uid, roomId: roomId)));

    return async.when(
      data: (identity) => _IdentityView(
        identity: identity,
        fontSize: fontSize,
        showAchievements: showAchievements,
        compact: compact,
        ownerOnlyRole: ownerOnlyRole,
        showChatBadge: showChatBadge,
        hideRole: hideRole,
      ),
      loading: () => const SizedBox.shrink(),
      // نفس علاج server_username_display: تسجيل بدل الابتلاع الصامت.
      error: (e, st) {
        unawaited(ErrorMonitor.report(e,
            stack: st, screen: 'server_user_identity_badges', source: 'identity_fetch'));
        return const SizedBox.shrink();
      },
    );
  }
}

class _IdentityView extends StatelessWidget {
  final Map<String, dynamic> identity;
  final double fontSize;
  final bool showAchievements;
  final bool compact;
  final bool ownerOnlyRole;
  final bool showChatBadge;
  final bool hideRole;

  const _IdentityView({
    required this.identity,
    required this.fontSize,
    required this.showAchievements,
    required this.compact,
    required this.ownerOnlyRole,
    required this.showChatBadge,
    this.hideRole = false,
  });

  static const _rankVisuals = <String, (String, String, Color)>{
    'rookie': ('◉', 'مبتدئ', Color(0xFF9E9E9E)),
    'bronze': ('◆', 'برونزي', Color(0xFFCD7F32)),
    'silver': ('◆', 'فضي', Color(0xFFC0C0C0)),
    'gold': ('★', 'ذهبي', Color(0xFFFFC107)),
    'platinum': ('✦', 'بلاتيني', Color(0xFF80CBC4)),
    'diamond': ('◇', 'ماسي', Color(0xFF7DD3FC)),
    'legend': ('♛', 'أسطورة', Color(0xFFFF8A65)),
  };

  static const _achievementLabels = <String, String>{
    'verified_email': 'موثّق',
    'first_gift_sent': 'أول هدية',
    'week_streak': 'أسبوع',
    'month_streak': 'شهر',
    'century_streak': '100 يوم',
    'referred_friend': 'دعا صديقًا',
    'first_chat': 'أول محادثة',
  };

  Widget _chip({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1.5 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: fontSize + 1, color: color)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = identity['role'] is Map
        ? Map<String, dynamic>.from(identity['role'] as Map)
        : const <String, dynamic>{};
    final rank = identity['rank'] is Map
        ? Map<String, dynamic>.from(identity['rank'] as Map)
        : const <String, dynamic>{};
    final badge = identity['chat_badge'] is Map
        ? Map<String, dynamic>.from(identity['chat_badge'] as Map)
        : const <String, dynamic>{};

    final roleCode = role['code']?.toString().trim() ?? 'user';
    final roleName = role['name']?.toString().trim() ?? '';
    final roleBadge = identity['role_badge'] is Map
        ? Map<String, dynamic>.from(identity['role_badge'] as Map)
        : const <String, dynamic>{};
    final businessTitle =
        identity['business_title']?.toString().trim() ?? '';
    final rolePriority = (role['priority'] as num?)?.toInt() ?? 0;
    final rankId = rank['id']?.toString().trim() ?? 'rookie';
    final rankLevel = (rank['level'] as num?)?.toInt() ?? 1;
    final rankName = rank['name']?.toString().trim() ??
        _rankVisuals[rankId]?.$2 ??
        rankId;
    final visual = _rankVisuals[rankId] ??
        ('◉', rankName, const Color(0xFF9E9E9E));
    final badgeUrl = badge['url']?.toString().trim();

    final isDragon = roleCode == 'dragon';
    // DRAGON is the platform owner identity, not a progression rank.
    // Every non-owner starts visibly at L1 and progresses server-side.
    final showRole = !hideRole &&
        (isDragon || (!ownerOnlyRole && roleCode != 'user' && roleCode != 'visitor'));
    // شارة الرتبة/المستوى (★ ذهبي • L74) مخفيّة بطلب المالك.
    const showRank = false;

    final achievementRaw = identity['achievement_badges'];
    final achievements = achievementRaw is List
        ? achievementRaw
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .take(3)
            .toList()
        : const <String>[];

    if (!showRole &&
        !showRank &&
        (badgeUrl == null || badgeUrl.isEmpty) &&
        (!showAchievements || achievements.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showChatBadge && !isDragon && badgeUrl != null && badgeUrl.isNotEmpty)
          Container(
            width: compact ? 19 : 24,
            height: compact ? 19 : 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _TinyChatBadgeImage(url: badgeUrl),
            ),
          ),
        // شارة الرتبة: الإيموجي واللون يأتيان الآن من جدول roles
        // (badge_emoji/badge_color) الذي يضبطه المالك — نجمة ذهبية
        // لامعة لسوبر أدمن، فضية لأدمن، برونزية لمشرف. والاسم عربي
        // من roles.name بدل 'DRAGON' الإنجليزية المثبّتة سابقًا.
        // شارة الرتبة: كل الرتب تظهر هنا، والتمييز في الأسلوب لا
        // الموضع. رتب السلطة (مالك/سوبر أدمن/أدمن/مشرف) تأخذ خلفية
        // إطار اسم مصغّرة بلونَي الكتالوج، والمهنية تأخذ مؤثر اسم
        // ملوّنًا. المالك يُسنِد أيّ عنصر لأيّ رتبة خادميًا.
        if (showRole)
          RoleStyleChip(
              badge: roleBadge, fallbackName: roleName, fontSize: fontSize),

        // لقب المنشأة الذي يكتبه المالك للعضو
        if (businessTitle.isNotEmpty)
          _chip(
            icon: '🏷️',
            label: businessTitle,
            color: const Color(0xFF34D399),
          ),
        if (showRank)
          _chip(
            icon: visual.$1,
            label: '$rankName • L$rankLevel',
            color: visual.$3,
          ),
        if (showAchievements)
          // شارة "أول محادثة" مخفيّة عن الجميع بناءً على طلب صريح — تُستثنى
          // هنا فقط (لا تُحذف من بيانات gamification_stats.badges على
          // الخادم، فقط لا تُعرَض بصريًا)، بقية الإنجازات تظهر كما هي.
          for (final id in achievements.where((a) => a != 'first_chat'))
            _chip(
              icon: '🏅',
              label: _achievementLabels[id] ?? id,
              color: const Color(0xFF66BB6A),
            ),
        if (rolePriority >= 1000 && roleCode == 'dragon')
          const SizedBox.shrink(),
      ],
    );
  }
}


class _TinyChatBadgeImage extends StatefulWidget {
  final String url;
  const _TinyChatBadgeImage({required this.url});

  @override
  State<_TinyChatBadgeImage> createState() => _TinyChatBadgeImageState();
}

class _TinyChatBadgeImageState extends State<_TinyChatBadgeImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final pulse = 1 + math.sin(_controller.value * math.pi * 2) * .07;
        return Transform.scale(scale: pulse, child: child);
      },
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// يحوّل "#RRGGBB" القادم من roles.badge_color إلى Color، ويعود
/// للافتراضي عند أي قيمة غير صالحة.
Color _hexOr(String? hex, Color fallback) {
  final h = (hex ?? '').replaceAll('#', '').trim();
  if (h.length != 6) return fallback;
  final n = int.tryParse('FF$h', radix: 16);
  return n == null ? fallback : Color(n);
}

/// شريحة الرتبة بأسلوبها المُسنَد من الخادم.
///
/// authority  → خلفية متدرّجة بلونَي الكتالوج + وهج إن كان glow،
///              فتبدو كشارة سلطة بارزة (نسخة مصغّرة من خلفية الاسم).
/// professional → نص ملوّن بتدرّج بلا خلفية، تمييز بلا سلطة.
class RoleStyleChip extends StatelessWidget {
  final Map<String, dynamic> badge;
  final String fallbackName;
  final double fontSize;
  const RoleStyleChip(
      {super.key, required this.badge, required this.fallbackName, this.fontSize = 9.5});

  @override
  Widget build(BuildContext context) {
    final label = (badge['name']?.toString().trim().isNotEmpty ?? false)
        ? badge['name'].toString()
        : fallbackName;
    if (label.isEmpty) return const SizedBox.shrink();

    final emoji = badge['emoji']?.toString() ?? '';
    final isAuthority = badge['style_kind']?.toString() == 'authority';
    final c1 = _hexOr(badge['style_color1']?.toString(),
        _hexOr(badge['color']?.toString(), const Color(0xFF8E7CFF)));
    final c2 = _hexOr(badge['style_color2']?.toString(), c1);
    final glow = badge['glow'] == true;

    // اختيار العضو من المتجر: مؤثر من مؤثرات الاسم + خلفية إطار اسم. إن وُجدا
    // يُرسمان بالمحرّك نفسه الذي يرسم اسم المستخدم، ويتقدّمان على نمط الرتبة.
    final customFx = badge['custom_effect']?.toString();
    final customBg = badge['custom_bg'] is Map ? badge['custom_bg'] as Map : null;
    if ((customFx != null && customFx.isNotEmpty) || customBg != null) {
      final b1 = _hexOr(customBg?['color1']?.toString(), c1);
      final b2 = _hexOr(customBg?['color2']?.toString(), b1);
      final labelText = emoji.isEmpty ? label : '$emoji $label';
      final Widget inner = (customFx != null && customFx.isNotEmpty)
          ? UsernameEffectText(
              name: labelText,
              effect: UsernameEffectX.fromWire(customFx),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            )
          : Text(labelText,
              style: TextStyle(
                  fontSize: fontSize, height: 1.1, fontWeight: FontWeight.w900,
                  color: Colors.white));
      if (customBg == null) {
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: inner);
      }
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: (fontSize * .7).clamp(6, 12),
            vertical: (fontSize * .25).clamp(2, 5)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(colors: [b1, b2]),
          boxShadow: [BoxShadow(color: b1.withValues(alpha: .45), blurRadius: 6)],
        ),
        child: inner,
      );
    }

    final text = Text(
      emoji.isEmpty ? label : '$emoji $label',
      style: TextStyle(
        fontSize: fontSize,
        height: 1.1,
        fontWeight: FontWeight.w900,
        color: isAuthority ? Colors.white : c1,
      ),
    );

    if (!isAuthority) {
      // مؤثر ملوّن: تدرّج على النص نفسه بلا خلفية
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ShaderMask(
          shaderCallback: (r) =>
              LinearGradient(colors: [c1, c2]).createShader(r),
          child: text,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: (fontSize * .7).clamp(6, 12),
          vertical: (fontSize * .25).clamp(2, 5)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(colors: [c1, c2]),
        boxShadow: glow
            ? [BoxShadow(color: c1.withValues(alpha: .55), blurRadius: 7)]
            : null,
      ),
      child: text,
    );
  }
}

/// شارة الرتبة وحدها، بلا اسم ولا شارات أخرى — لعرضها تحت الأفاتار
/// في صف رسالة الشات، منفصلة عن ServerUsernameDisplay كليًا حتى لا
/// تُعاد رسمها مرتين (بجانب الاسم وتحت الأفاتار معًا).
class ServerRoleBadgeUnderAvatar extends ConsumerWidget {
  final String uid;
  final String? roomId;
  const ServerRoleBadgeUnderAvatar({super.key, required this.uid, this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = roomId == null
        ? ref.watch(serverUserIdentityProvider(uid))
        : ref.watch(serverUserIdentityInRoomProvider((uid: uid, roomId: roomId)));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (identity) {
        final roleBadge = identity['role_badge'] is Map
            ? Map<String, dynamic>.from(identity['role_badge'] as Map)
            : const <String, dynamic>{};
        final roleName = (identity['role'] is Map)
            ? (identity['role'] as Map)['name']?.toString() ?? ''
            : '';
        if (roleBadge.isEmpty && roleName.isEmpty) return const SizedBox.shrink();
        // حجم أصغر من الاستعمال بجانب الاسم — هذا فراغ ضيق تحت أفاتار
        // صغير (نحو 42-50px)، لا مساحة سطر كامل.
        return RoleStyleChip(badge: roleBadge, fallbackName: roleName, fontSize: 8.0);
      },
    );
  }
}
