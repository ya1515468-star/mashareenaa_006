import 'package:equatable/equatable.dart';

/// كيان الرتبة — نظام مستويات مستقل عن أدوار RBAC (وحدة RBAC تتحكم
/// بالصلاحيات، بينما الرتبة هنا تعكس تقدّم المستخدم عبر نقاط الخبرة
/// XP، وتُعرض كشارة بجانب اسمه). يطابق حقول rankId/rankLevel/
/// rankBadge في مخطط مجموعة accounts الرسمي.
class RankEntity extends Equatable {
  final String id;
  final String name;
  final int level;
  final int minXp;
  final String badgeAsset;

  const RankEntity({
    required this.id,
    required this.name,
    required this.level,
    required this.minXp,
    required this.badgeAsset,
  });

  @override
  List<Object?> get props => [id, name, level, minXp, badgeAsset];
}
