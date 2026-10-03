import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gamification_stats_entity.dart';
import '../entities/points_package_entity.dart';
import '../entities/rank_entity.dart';

abstract class GamificationRepository {
  Future<Either<Failure, GamificationStatsEntity>> getStats(String uid);

  Stream<GamificationStatsEntity> watchStats(String uid);

  /// يضيف نقاط خبرة ويعيد احتساب الرتبة تلقائيًا إن تجاوز الحد —
  /// يُستدعى داخليًا من وحدات أخرى مستقبلية (المشاريع، السوق،
  /// الرسائل...) عند إتمام إجراء يستحق خبرة، وليس من الواجهة مباشرة.
  Future<Either<Failure, GamificationStatsEntity>> addXp(
    String uid, {
    required String eventType,
    String? referenceType,
    String? referenceId,
  });

  /// يمنح مكافأة الدخول اليومي (نقاط + خبرة) ويحدّث تتابع الأيام —
  /// يرفض العملية إن كانت المكافأة قد استُلمت اليوم بالفعل.
  /// [multiplier] يُحسب في طبقة الـ UseCase من مستوى عضوية المستخدم
  /// الحالي (1 مجاني، 2 بريميوم، 3 VIP).
  Future<Either<Failure, GamificationStatsEntity>> claimDailyReward(
    String uid, {
    required int multiplier,
  });

  /// يخصم نقاطًا من رصيد المستخدم. إن كان المستخدم يملك صلاحية
  /// unlimited_resources، لا يُخصم شيء فعليًا ويُعاد نجاح فوري — لا
  /// رقم ضخم يُستهلك، بل تجاوز كامل لعملية الخصم نفسها.
  Future<Either<Failure, void>> spendPoints({
    required String uid,
    required int amount,
    required bool unlimited,
  });

  Future<Either<Failure, void>> spendGems({
    required String uid,
    required int amount,
    required bool unlimited,
  });

  /// يضيف جواهر لرصيد المستخدم — يُستخدم عند استلام هدية (Gifts)
  /// كنسبة من سعرها، تحويلًا لنموذج ربح شائع في تطبيقات الدردشة
  /// الحيّة (الراسل يدفع نقاطًا، المستقبِل يكسب جواهر).
  Future<Either<Failure, void>> creditGems(
      {required String uid, required int amount});

  /// يضيف نقاطًا مباشرة (بلا خصم من أي طرف) — يُستخدم للمكافآت
  /// (الإحالة، الإنجازات، عجلة الحظ) وليس للتحويل بين الأعضاء.
  Future<Either<Failure, void>> creditPoints(
      {required String uid, required int amount});

  /// يضيف وسامًا (Achievement Badge) لقائمة أوسمة المستخدم إن لم
  /// يكن موجودًا مسبقًا (عملية idempotent — لا يتكرر الوسام).
  Future<Either<Failure, void>> unlockBadge(
      {required String uid, required String badgeId});

  Future<Either<Failure, int>> spinMysteryBox(String uid);

  Future<Either<Failure, void>> transferPoints({
    required String fromUid,
    required String toUid,
    required int amount,
    required bool bypassChecks,
  });

  /// يشتري حزمة نقاط بعملة شام كاش: خصم ذري من رصيد المحفظة وإضافة
  /// النقاط معًا ضمن معاملة طبقة بيانات Supabase واحدة (كلا الحقلين يعيشان في
  /// نفس مستند accounts) — إما ينجح الاثنان معًا أو يفشلان معًا.
  Future<Either<Failure, List<PointsPackageEntity>>> listPointsPackages();
  Future<Either<Failure, void>> updatePointsPackagePrice(
      {required String packageId,
      required int priceMinorUnits,
      required bool enabled,
      required String updatedBy});

  Future<Either<Failure, GamificationStatsEntity>> purchasePointsPackage({
    required String uid,
    required String packageId,
  });

  RankEntity rankForLevel(int level);
}
