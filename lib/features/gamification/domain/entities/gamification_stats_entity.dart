import 'package:equatable/equatable.dart';
import 'username_effect.dart';

/// إحصائيات التلعيب لكل مستخدم — تُخزَّن في نفس مستند accounts
/// (rankId, rankLevel, rankBadge حسب المخطط الرسمي) بالإضافة إلى
/// حقول XP/Points/Gems/Daily Reward الخاصة بالبند 5 (Gamification).
class GamificationStatsEntity extends Equatable {
  final String uid;
  final int xp;
  final int rankLevel;
  final String rankId;
  final int points;
  final int gems;
  final List<String> badges;
  final UsernameEffect usernameEffect;
  final int dailyRewardStreak;
  final DateTime? lastDailyRewardAt;

  const GamificationStatsEntity({
    required this.uid,
    required this.xp,
    required this.rankLevel,
    required this.rankId,
    required this.points,
    required this.gems,
    required this.badges,
    required this.usernameEffect,
    required this.dailyRewardStreak,
    this.lastDailyRewardAt,
  });

  /// هل يحق للمستخدم المطالبة بمكافأة اليوم؟ (لم يطالب بعد اليوم).
  bool canClaimDailyReward(DateTime now) {
    if (lastDailyRewardAt == null) return true;
    final last = lastDailyRewardAt!;
    return last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
  }

  static GamificationStatsEntity initial(String uid) => GamificationStatsEntity(
        uid: uid,
        xp: 0,
        rankLevel: 1,
        rankId: 'rookie',
        points: 0,
        gems: 0,
        badges: const [],
        usernameEffect: UsernameEffect.none,
        dailyRewardStreak: 0,
        lastDailyRewardAt: null,
      );

  @override
  List<Object?> get props => [
        uid,
        xp,
        rankLevel,
        rankId,
        points,
        gems,
        badges,
        usernameEffect,
        dailyRewardStreak,
        lastDailyRewardAt,
      ];
}
