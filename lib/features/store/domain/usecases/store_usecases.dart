import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/store_item_entity.dart';
import '../repositories/store_repository.dart';

/// ═══════════════════════════════════════════════════════════════
/// قائمة كتالوج المتجر
/// ═══════════════════════════════════════════════════════════════
class ListStoreCatalogUseCase {
  final StoreRepository repository;

  const ListStoreCatalogUseCase(this.repository);

  Future<Either<Failure, List<StoreItemEntity>>> call() {
    return repository.listCatalog();
  }
}

/// ═══════════════════════════════════════════════════════════════
/// شراء عنصر من المتجر
/// ═══════════════════════════════════════════════════════════════
class PurchaseStoreItemUseCase {
  final StoreRepository storeRepository;
  const PurchaseStoreItemUseCase({
    required this.storeRepository,
  });

  Future<Either<Failure, void>> call({
    required String uid,
    required StoreItemEntity item,
  }) async {
    if (uid.trim().isEmpty) {
      return const Left(
        ValidationFailure(
          message: 'معرّف المستخدم غير صالح',
        ),
      );
    }

    if (!item.enabled) {
      return const Left(
        ValidationFailure(
          message: 'هذا العنصر غير متاح للشراء حاليًا',
        ),
      );
    }

    return storeRepository.purchaseItem(
      uid: uid,
      itemId: item.id,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// إدارة سعر وحالة عنصر المتجر
///
/// حصريًا:
///
///     AppRoles.platformOwner
///
/// لا تعتمد هذه العملية على:
///
///     grantMembershipFeatures
///     manageRoles
///     unlimitedResources
///
/// ولا يكفي إخفاء زر الإدارة من الواجهة.
/// ═══════════════════════════════════════════════════════════════
class UpdateStoreItemUseCase {
  final StoreRepository storeRepository;
  final RbacRepository rbacRepository;

  const UpdateStoreItemUseCase({
    required this.storeRepository,
    required this.rbacRepository,
  });

  Future<Either<Failure, void>> call({
    required String itemId,
    required int pricePoints,
    required int priceGems,
    required bool enabled,
    required String requestedByUid,
  }) async {
    // ═══════════════════════════════════════════════════════════
    // التحقق من المدخلات
    // ═══════════════════════════════════════════════════════════

    final normalizedItemId = itemId.trim();
    final normalizedUid = requestedByUid.trim();

    if (normalizedItemId.isEmpty) {
      return const Left(
        ValidationFailure(
          message: 'معرّف عنصر المتجر غير صالح',
        ),
      );
    }

    if (normalizedUid.isEmpty) {
      return const Left(
        ValidationFailure(
          message: 'معرّف مالك المنصة غير صالح',
        ),
      );
    }

    if (pricePoints < 0 || priceGems < 0) {
      return const Left(
        ValidationFailure(
          message: 'أسعار عنصر المتجر لا يمكن أن تكون سالبة',
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // التحقق من الصلاحية
    // ═══════════════════════════════════════════════════════════
    //
    // أول حاجز:
    // manageStorePricing
    //
    // هذه الصلاحية يجب أن تكون موجودة حصريًا في platform_owner.
    //
    // ═══════════════════════════════════════════════════════════

    final permissionResult = await rbacRepository.hasPermission(
      uid: normalizedUid,
      permission: AppPermissions.manageStorePricing,
    );

    final allowedByPermission = permissionResult.getOrElse(() => false);

    if (!allowedByPermission) {
      return const Left(
        PermissionFailure(),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // تنفيذ التعديل
    // ═══════════════════════════════════════════════════════════

    return storeRepository.updateItem(
      itemId: normalizedItemId,
      pricePoints: pricePoints,
      priceGems: priceGems,
      enabled: enabled,
      updatedBy: normalizedUid,
    );
  }
}

class CreateStoreItemUseCase {
  final StoreRepository storeRepository;
  final RbacRepository rbacRepository;
  const CreateStoreItemUseCase(this.storeRepository, this.rbacRepository);

  Future<Either<Failure, void>> call(
      {required StoreItemEntity item, required String requestedByUid}) async {
    final check = await rbacRepository.hasPermission(
        uid: requestedByUid, permission: AppPermissions.manageStorePricing);
    if (!check.getOrElse(() => false)) return const Left(PermissionFailure());
    return storeRepository.createItem(item: item, createdBy: requestedByUid);
  }
}

class GrantStoreItemUseCase {
  final StoreRepository storeRepository;
  final RbacRepository rbacRepository;
  const GrantStoreItemUseCase(this.storeRepository, this.rbacRepository);

  Future<Either<Failure, void>> call(
      {required String targetUid,
      required String itemId,
      required String requestedByUid}) async {
    final check = await rbacRepository.hasPermission(
        uid: requestedByUid, permission: AppPermissions.manageStorePricing);
    if (!check.getOrElse(() => false)) return const Left(PermissionFailure());
    return storeRepository.grantItem(
        targetUid: targetUid, itemId: itemId, performedBy: requestedByUid);
  }
}
