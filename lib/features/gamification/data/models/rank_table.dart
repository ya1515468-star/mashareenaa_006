import '../../domain/entities/rank_entity.dart';

/// جدول الرتب الثابت — عشر رتب متدرجة حسب نقاط الخبرة التراكمية.
/// [RankTable.forXp] يحدد الرتبة الحالية.
///
/// ⚠️ تحذير مهم: [level] هنا (1, 5, 10, 20, 35, 50, 70) هو تصنيف عرضي
/// مستقل تمامًا، ولا يطابق عمود gamification_stats.rank_level الحقيقي على
/// الخادم إطلاقًا. rank_level الحقيقي يُحسب بالمعادلة floor(xp / 100) + 1
/// (تنمو بسرعة كبيرة — مثلًا عند 4000 نقطة خبرة تكون rank_level حوالي 41،
/// لا 20). لذلك [forLevel] معطّلة الاستخدام فعليًا (تحقّقت: لا يستدعيها أي
/// كود مباشرة أو غير مباشرة) ويجب ألّا تُستخدم أبدًا مع rank_level الحقيقي
/// — العرض الآمن للرتبة هو دائمًا rank_id النصي القادم من الخادم مباشرة
/// (rookie/bronze/silver/...)، لا حساب أي شيء من رقم level محليًا.
class RankTable {
  RankTable._();

  static const List<RankEntity> ranks = [
    RankEntity(
        id: 'rookie',
        name: 'مبتدئ',
        level: 1,
        minXp: 0,
        badgeAsset: 'rank_rookie'),
    RankEntity(
        id: 'bronze',
        name: 'برونزي',
        level: 5,
        minXp: 500,
        badgeAsset: 'rank_bronze'),
    RankEntity(
        id: 'silver',
        name: 'فضي',
        level: 10,
        minXp: 1500,
        badgeAsset: 'rank_silver'),
    RankEntity(
        id: 'gold',
        name: 'ذهبي',
        level: 20,
        minXp: 4000,
        badgeAsset: 'rank_gold'),
    RankEntity(
        id: 'platinum',
        name: 'بلاتيني',
        level: 35,
        minXp: 9000,
        badgeAsset: 'rank_platinum'),
    RankEntity(
        id: 'diamond',
        name: 'ماسي',
        level: 50,
        minXp: 18000,
        badgeAsset: 'rank_diamond'),
    RankEntity(
        id: 'legend',
        name: 'أسطورة',
        level: 70,
        minXp: 35000,
        badgeAsset: 'rank_legend'),
  ];

  /// يعيد أعلى رتبة يستحقها هذا الرصيد من نقاط الخبرة.
  static RankEntity forXp(int xp) {
    RankEntity current = ranks.first;
    for (final rank in ranks) {
      if (xp >= rank.minXp) current = rank;
    }
    return current;
  }

  static RankEntity forLevel(int level) {
    RankEntity current = ranks.first;
    for (final rank in ranks) {
      if (level >= rank.level) current = rank;
    }
    return current;
  }
}
