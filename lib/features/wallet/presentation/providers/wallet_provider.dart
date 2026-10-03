import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/get_wallet_history_usecase.dart';
import '../../domain/usecases/transfer_usecase.dart';

final currentWalletProvider = StreamProvider<WalletEntity?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  final repository = sl<WalletRepository>();
  return repository.watchWallet(user.uid);
});

final walletHistoryProvider =
    FutureProvider<List<LedgerEntryEntity>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  final useCase = sl<GetWalletHistoryUseCase>();
  final result = await useCase(user.uid);
  return result.fold((failure) => [], (list) => list);
});

class WalletController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> transfer({
    required String fromUid,
    required String toUid,
    required Money amount,
    String? note,
  }) async {
    state = const AsyncLoading();
    final useCase = sl<TransferUseCase>();
    final result = await useCase(
      TransferParams(
          fromUid: fromUid, toUid: toUid, amount: amount, note: note),
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, void>(
  WalletController.new,
);
