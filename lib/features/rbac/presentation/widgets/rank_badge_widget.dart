import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/repositories/rbac_repository.dart';

/// يجلب دور المستخدم الحالي لعرض شارة رتبته (Rank Badge) بجانب
/// اسمه — منفصلة عن شارة العضوية المدفوعة [MembershipBadgeChip]:
/// هذه الشارة تعكس دوره الإداري/الرتبي في المنصة (مالك، مشرف...)
/// وليس اشتراكه المدفوع.
final userRoleProvider =
    FutureProvider.autoDispose.family<RoleEntity?, String>((ref, uid) async {
  final result = await sl<RbacRepository>().getUserRole(uid);
  return result.fold((failure) => null, (role) => role);
});

/// الرتب التي تستحق شارة ظاهرة للعامة — الرتب العادية (عميل،
/// زائر...) لا تُعرض كشارة حتى لا تصبح الواجهة مزدحمة بلا فائدة.
/// الأيقونات والألوان مطابقة للمواصفة المطلوبة: تاج ذهبي بلون أحمر
/// فسفوري للمالك الأعلى، نجمتان للسوبر أدمن، نجمة فضية للأدمن، عين
/// للمشرف.
const _visibleRankBadges = {
  AppRoles.dragon: ('👑', 'مالك المنصة', Color(0xFFD4AF37)),
  AppRoles.superAdmin: ('🌟🌟', 'سوبر أدمن', Color(0xFF7A1F3D)),
  AppRoles.admin: ('⭐', 'أدمن', Color(0xFFC0C0C0)),
  AppRoles.moderator: ('👁️', 'مشرف', Color(0xFF2FBF8E)),
  AppRoles.featuredMember: ('🏵️', 'عضو مميز', Color(0xFFFFC107)),
  'manager': ('🛡️', 'مدير غرفة', Color(0xFF8E7CFF)),
  'room_owner': ('👑', 'مالك الغرفة', Color(0xFFFFB300)),
};

class RankBadgeChip extends StatefulWidget {
  final String roleId;
  final double fontSize;
  const RankBadgeChip({super.key, required this.roleId, this.fontSize = 11});

  @override
  State<RankBadgeChip> createState() => _RankBadgeChipState();
}

class _RankBadgeChipState extends State<RankBadgeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleId = widget.roleId;
    final fontSize = widget.fontSize;
    final entry = _visibleRankBadges[roleId];
    if (entry == null) return const SizedBox.shrink();
    final (emoji, label, color) = entry;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_controller.value * 0.045),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: fontSize + 1)),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: fontSize,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class UserRankBadge extends ConsumerWidget {
  final String uid;
  final double fontSize;
  const UserRankBadge({super.key, required this.uid, this.fontSize = 11});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider(uid));
    return roleAsync.when(
      data: (role) => role == null
          ? const SizedBox.shrink()
          : RankBadgeChip(roleId: role.id, fontSize: fontSize),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

