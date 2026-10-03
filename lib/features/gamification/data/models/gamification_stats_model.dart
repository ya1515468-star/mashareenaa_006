import '../../domain/entities/gamification_stats_entity.dart';
import '../../domain/entities/username_effect.dart';

class GamificationStatsModel extends GamificationStatsEntity {
  const GamificationStatsModel({
    required super.uid,
    required super.xp,
    required super.rankLevel,
    required super.rankId,
    required super.points,
    required super.gems,
    required super.badges,
    required super.usernameEffect,
    required super.dailyRewardStreak,
    super.lastDailyRewardAt,
  });

  factory GamificationStatsModel.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) {
    final rawXp = map['xp'];
    final rawRankLevel = map['rankLevel'];
    final rawPoints = map['points'];
    final rawGems = map['gems'];
    final rawDailyRewardStreak = map['dailyRewardStreak'];

    final rawBadges = map['badges'];

    final badges = rawBadges is List
        ? rawBadges.map((value) => value.toString()).toList(growable: false)
        : const <String>[];

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    }

    return GamificationStatsModel(
      uid: uid,
      xp: rawXp is num ? rawXp.toInt() : 0,
      rankLevel: rawRankLevel is num ? rawRankLevel.toInt() : 1,
      rankId: map['rankId'] as String? ?? 'rookie',
      points: rawPoints is num ? rawPoints.toInt() : 0,
      gems: rawGems is num ? rawGems.toInt() : 0,
      badges: badges,
      usernameEffect: UsernameEffectX.fromWire(
        map['usernameEffect'] as String?,
      ),
      dailyRewardStreak:
          rawDailyRewardStreak is num ? rawDailyRewardStreak.toInt() : 0,
      lastDailyRewardAt: parseDate(
        map['lastDailyRewardAt'],
      ),
    );
  }

  factory GamificationStatsModel.fromEntity(
    GamificationStatsEntity e,
  ) {
    return GamificationStatsModel(
      uid: e.uid,
      xp: e.xp,
      rankLevel: e.rankLevel,
      rankId: e.rankId,
      points: e.points,
      gems: e.gems,
      badges: e.badges,
      usernameEffect: e.usernameEffect,
      dailyRewardStreak: e.dailyRewardStreak,
      lastDailyRewardAt: e.lastDailyRewardAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xp': xp,
      'rankLevel': rankLevel,
      'rankId': rankId,
      'points': points,
      'gems': gems,
      'badges': badges,
      'usernameEffect': usernameEffect.wire,
      'dailyRewardStreak': dailyRewardStreak,
      'lastDailyRewardAt': lastDailyRewardAt?.toIso8601String(),
    };
  }
}
