import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../gamification/domain/repositories/gamification_repository.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/gift_entity.dart';
import '../entities/gift_transaction_entity.dart';
import '../repositories/gift_repository.dart';

/// نسبة الجواهر التي يكسبها مستقبِل الهدية من سعرها بالنقاط —
/// نموذج ربح شائع في تطبيقات الهدايا الحيّة (الراسل يدفع نقاطًا،
/// المستقبِل يكسب جزءًا منها كجواهر قابلة للتحويل لاحقًا).
const double kGiftReceiverGemsShare = 0.7;

class SendGiftUseCase {
  final GamificationRepository gamificationRepository;
  final RbacRepository rbacRepository;
  final GiftRepository giftRepository;

  const SendGiftUseCase({
    required this.gamificationRepository,
    required this.rbacRepository,
    required this.giftRepository,
  });

  Future<Either<Failure, GiftTransactionEntity>> call({
    required String fromUid,
    required String toUid,
    required GiftEntity gift,
    String? roomId,
  }) async {
    if (fromUid == toUid) {
      return const Left(ValidationFailure(message: 'لا يمكن إهداء نفسك'));
    }

    final txResult = await giftRepository.recordGiftTransaction(
      giftId: gift.id,
      fromUid: fromUid,
      toUid: toUid,
      pricePoints: gift.pricePoints,
      roomId: roomId,
    );

    // The server-side gift RPC is authoritative. The chat layer adds the
    // single private gift message after the transaction succeeds.

    return txResult;
  }
}
