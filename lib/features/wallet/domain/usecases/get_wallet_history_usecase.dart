import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/ledger_entry_entity.dart';
import '../repositories/wallet_repository.dart';

class GetWalletHistoryUseCase {
  final WalletRepository repository;

  const GetWalletHistoryUseCase(this.repository);

  Future<Either<Failure, List<LedgerEntryEntity>>> call(String uid,
      {int limit = 50}) {
    return repository.getHistory(uid, limit: limit);
  }
}
