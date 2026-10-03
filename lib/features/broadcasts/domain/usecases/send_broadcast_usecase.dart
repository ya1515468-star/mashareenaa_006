import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/broadcast_repository.dart';

class SendBroadcastUseCase {
  final BroadcastRepository broadcastRepository;
  final RbacRepository rbacRepository;

  const SendBroadcastUseCase(
      {required this.broadcastRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call(
      {required String message, required String sentByUid}) async {
    if (message.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'لا يمكن بث رسالة فارغة'));
    }

    final permissionCheck = await rbacRepository.hasPermission(
      uid: sentByUid,
      permission: AppPermissions.broadcastMessages,
    );
    final allowed = permissionCheck.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return broadcastRepository.sendBroadcast(
        message: message.trim(), sentByUid: sentByUid);
  }
}
