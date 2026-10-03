import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gift_transaction_entity.dart';

abstract class GiftRepository {
  /// يسجّل معاملة هدية مكتملة بالفعل (بعد خصم/إضافة الأرصدة في
  /// SendGiftUseCase) — هذا الـ Repository مسؤول فقط عن مجموعة
  /// gift_transactions نفسها، وليس منطق الخصم/الإضافة عبر الوحدات
  /// الأخرى (ذلك من مسؤولية SendGiftUseCase الذي ينسّق بين
  /// GamificationRepository وChatRepository وهذا الـ Repository).
  Future<Either<Failure, GiftTransactionEntity>> recordGiftTransaction({
    required String giftId,
    required String fromUid,
    required String toUid,
    required int pricePoints,

    /// معرّف الغرفة عند الإهداء من داخلها: يجعل الخادم ينشر إعلان الهدية
    /// في الغرفة نفسها. من محادثة خاصة يبقى null فلا يتغيّر شيء.
    String? roomId,
  });

  /// بث لحظي بأي هدية جديدة تصل لهذا المستخدم — يُستخدم لتشغيل
  /// [GiftAnimationOverlay] بملء الشاشة فور الاستلام، حتى خارج شاشة
  /// الدردشة تلك تحديدًا.
  Stream<GiftTransactionEntity> watchIncomingGifts(String uid);
}
