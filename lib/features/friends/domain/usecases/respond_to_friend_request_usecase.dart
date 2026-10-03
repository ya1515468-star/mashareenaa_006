import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/friend_request_entity.dart';
import '../repositories/friend_repository.dart';

/// respond_friend_request الخادمية تتحقق من أن المستخدم الحالي هو المستلم
/// الحقيقي للطلب (to_uid) قبل أي تغيير، وتُنشئ إشعار القبول/الرفض بنفسها
/// داخل نفس المعاملة — لذلك أُزيل إنشاء إشعار مكرَّر من هنا (كان يظهر
/// للمُرسِل إشعاران متطابقان عند كل قبول صداقة).
class RespondToFriendRequestUseCase {
  final FriendRepository friendRepository;

  const RespondToFriendRequestUseCase({
    required this.friendRepository,
  });

  Future<Either<Failure, void>> call(FriendRequestEntity request,
      {required bool accept}) async {
    return friendRepository.respondToRequest(
        requestId: request.id, accept: accept);
  }
}
