import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/store_item_entity.dart';

abstract class StoreRepository {
  /// يجلب الكتالوج الكامل — من طبقة بيانات Supabase إن كان مهيَّأً، وإلا يُهيَّأ
  /// تلقائيًا من [StoreCatalogGenerator.fullCatalog] عند أول استدعاء
  /// (Seed مرة واحدة، بنفس نمط RbacRepository.listRoles تمامًا).
  Future<Either<Failure, List<StoreItemEntity>>> listCatalog();

  /// DRAGON فقط (manage_sponsored_ads أو grant_membership_features)
  /// يعدّل سعر أو تفعيل عنصر.
  Future<Either<Failure, void>> updateItem({
    required String itemId,
    required int pricePoints,
    required int priceGems,
    required bool enabled,
    required String updatedBy,
  });

  /// يشتري عنصرًا من المصدر السلطوي في Supabase. السعر والعملة والصلاحيات
  /// تُحدد بالكامل على الخادم ولا تُقبل من العميل كمرجع للحساب.
  Future<Either<Failure, void>> purchaseItem({
    required String uid,
    required String itemId,
  });

  Future<Either<Failure, void>> createItem(
      {required StoreItemEntity item, required String createdBy});
  Future<Either<Failure, void>> grantItem(
      {required String targetUid,
      required String itemId,
      required String performedBy});

  Stream<List<String>> watchOwnedItemIds(String uid);

  Stream<List<StoreItemEntity>> watchCatalog();
}
