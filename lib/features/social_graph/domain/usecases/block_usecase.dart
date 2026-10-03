import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/social_graph_repository.dart';

/// الحظر يقطع علاقة المتابعة تلقائيًا بالاتجاهين — لا يبقى أي طرف
/// يتابع من حظره أو من حظره الطرف الآخر، فهذا هو المعنى الفعلي
/// للحظر وليس مجرد وثيقة منفصلة لا تُغيّر شيئًا آخر.
class BlockUseCase {
  final SocialGraphRepository repository;

  const BlockUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String blockerUid, required String targetUid}) async {
    if (blockerUid == targetUid) {
      return const Left(ValidationFailure(message: 'لا يمكن حظر نفسك'));
    }

    final blockResult =
        await repository.block(blockerUid: blockerUid, targetUid: targetUid);
    if (blockResult.isLeft()) return blockResult;

    await repository.unfollow(followerUid: blockerUid, targetUid: targetUid);
    await repository.unfollow(followerUid: targetUid, targetUid: blockerUid);

    return blockResult;
  }
}
