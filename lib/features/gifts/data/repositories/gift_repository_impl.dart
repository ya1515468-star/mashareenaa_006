import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/gift_transaction_entity.dart';
import '../../domain/repositories/gift_repository.dart';
import '../datasources/gift_remote_data_source.dart';

class GiftRepositoryImpl implements GiftRepository {
  final GiftRemoteDataSource remoteDataSource;
  GiftRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, GiftTransactionEntity>> recordGiftTransaction({
    required String giftId,
    required String fromUid,
    required String toUid,
    required int pricePoints,
    String? roomId,
  }) async {
    try {
      final result = await remoteDataSource.recordGiftTransaction(
        giftId: giftId,
        fromUid: fromUid,
        toUid: toUid,
        pricePoints: pricePoints,
        roomId: roomId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<GiftTransactionEntity> watchIncomingGifts(String uid) =>
      remoteDataSource.watchIncomingGifts(uid);
}
