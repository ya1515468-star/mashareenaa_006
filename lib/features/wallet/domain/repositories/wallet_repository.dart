import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/currency.dart';
import '../entities/ledger_entry_entity.dart';
import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Future<Either<Failure, WalletEntity>> getWallet(String uid);

  Stream<WalletEntity> watchWallet(String uid);

  Future<Either<Failure, List<LedgerEntryEntity>>> getHistory(String uid,
      {int limit = 50});

  /// يحوّل مبلغًا بين مستخدمين ضمن معاملة طبقة بيانات Supabase واحدة (Atomic):
  /// يُخصم من المرسل ويُضاف للمستقبل ويُسجَّل قيدان في السجل، أو لا
  /// يحدث شيء إطلاقًا عند أي فشل — لا حالة وسطى ممكنة.
  Future<Either<Failure, void>> transfer({
    required String fromUid,
    required String toUid,
    required Money amount,
    String? note,
  });

  /// يضيف مبلغًا مباشرة لمحفظة مستخدم (شحن رصيد، مكافأة، استرداد)
  /// مع تسجيل قيد في السجل — لا يخصم من أي طرف آخر.
  Future<Either<Failure, void>> credit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  });

  /// يخصم مبلغًا من محفظة مستخدم (شراء) — يفشل إن كان الرصيد غير
  /// كافٍ برسالة [ValidationFailure] واضحة.
  Future<Either<Failure, void>> debit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  });
}
