import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../entities/currency.dart';
import '../repositories/wallet_repository.dart';

class TransferParams extends Equatable {
  final String fromUid;
  final String toUid;
  final Money amount;
  final String? note;

  const TransferParams({
    required this.fromUid,
    required this.toUid,
    required this.amount,
    this.note,
  });

  @override
  List<Object?> get props => [fromUid, toUid, amount, note];
}

/// يتحقق من شروط أساسية قبل أي استدعاء لـ طبقة بيانات Supabase: عدم التحويل
/// للنفس، ومبلغ موجب — الفحوصات الأعمق (كفاية الرصيد) تتم داخل
/// معاملة الـ Repository نفسها لأنها تحتاج قراءة الرصيد اللحظي.
class TransferUseCase {
  final WalletRepository repository;

  const TransferUseCase(this.repository);

  Future<Either<Failure, void>> call(TransferParams params) async {
    if (params.fromUid == params.toUid) {
      return const Left(
          ValidationFailure(message: 'لا يمكن التحويل إلى نفس الحساب'));
    }
    if (params.amount.minorUnits <= 0) {
      return const Left(
          ValidationFailure(message: 'يجب أن يكون مبلغ التحويل أكبر من صفر'));
    }

    return repository.transfer(
      fromUid: params.fromUid,
      toUid: params.toUid,
      amount: params.amount,
      note: params.note,
    );
  }
}
