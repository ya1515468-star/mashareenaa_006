import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/gift_transaction_entity.dart';
import '../../domain/usecases/send_gift_usecase.dart';

class GiftController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String? lastError;

  Future<GiftTransactionEntity?> sendGift({
    required String fromUid,
    required String toUid,
    required GiftEntity gift,
    String? roomId,
  }) async {
    lastError = null;

    final result = await sl<SendGiftUseCase>().call(
      fromUid: fromUid,
      toUid: toUid,
      gift: gift,
      roomId: roomId,
    );

    return result.fold(
      (failure) {
        lastError = failure.message;
        return null;
      },
      (tx) {
        lastError = null;
        return tx;
      },
    );
  }
}

final giftControllerProvider =
    AsyncNotifierProvider<GiftController, void>(GiftController.new);
