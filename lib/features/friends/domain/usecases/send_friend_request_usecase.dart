import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../social_graph/domain/repositories/social_graph_repository.dart';
import '../repositories/friend_repository.dart';

/// send_friend_request الخادمية تتحقق الآن من الحظر بنفسها (كانت الفحص
/// موجودًا في التطبيق فقط، ويمكن تجاوزه بنداء مباشر)، وتُنشئ إشعار الطلب
/// بنفسها داخل المعاملة نفسها — أُزيل إنشاء إشعار مكرَّر من هنا.
class SendFriendRequestUseCase {
  final FriendRepository friendRepository;
  final SocialGraphRepository socialGraphRepository;

  const SendFriendRequestUseCase({
    required this.friendRepository,
    required this.socialGraphRepository,
  });

  Future<Either<Failure, void>> call(
      {required String fromUid, required String toUid}) async {
    if (fromUid == toUid) {
      return const Left(
          ValidationFailure(message: 'لا يمكن إرسال طلب صداقة لنفسك'));
    }

    // فحص محلي سريع لتحسين تجربة المستخدم (رسالة فورية بلا انتظار الخادم)؛
    // الفحص الحقيقي والحاسم أصبح على الخادم أيضًا الآن ولا يمكن تجاوزه.
    final blockResult = await socialGraphRepository.hasBlockEitherDirection(
        uidA: fromUid, uidB: toUid);
    final blocked = blockResult.getOrElse(() => false);
    if (blocked) {
      return const Left(PermissionFailure(
          message: 'لا يمكن إرسال طلب صداقة بسبب وجود حظر بين الطرفين'));
    }

    return friendRepository.sendRequest(fromUid: fromUid, toUid: toUid);
  }
}
