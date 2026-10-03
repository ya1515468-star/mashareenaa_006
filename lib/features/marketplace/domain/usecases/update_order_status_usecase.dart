import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/order_entity.dart';
import '../repositories/marketplace_repository.dart';

class UpdateOrderStatusUseCase {
  final MarketplaceRepository repository;

  const UpdateOrderStatusUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required OrderEntity order,
    required OrderStatus newStatus,
    required String requestedByUid,
  }) async {
    if (order.sellerUid != requestedByUid) {
      return const Left(
          PermissionFailure(message: 'البائع فقط يستطيع تحديث حالة الطلب'));
    }
    return repository.updateOrderStatus(orderId: order.id, status: newStatus);
  }
}
