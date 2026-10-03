import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/garment_business_profile_entity.dart';
import '../repositories/garment_hub_repository.dart';

/// يسمح بتسجيل/تعديل الملف التجاري فقط لمن يملك دورًا من أدوار
/// الأعمال المتخصصة (factory, workshop, supplier, business_owner)
/// — مستخدم عادي (customer/visitor) لا يستطيع نشر نفسه في دليل
/// Garment Hub حتى لو حاول من الواجهة مباشرة.
class UpsertBusinessProfileUseCase {
  final GarmentHubRepository garmentHubRepository;
  final RbacRepository rbacRepository;

  const UpsertBusinessProfileUseCase({
    required this.garmentHubRepository,
    required this.rbacRepository,
  });

  static const _allowedRoles = {
    AppRoles.factory,
    AppRoles.workshop,
    AppRoles.supplier,
    AppRoles.businessOwner,
    AppRoles.dragon,
  };

  Future<Either<Failure, void>> call(
      GarmentBusinessProfileEntity profile) async {
    if (profile.businessName.trim().isEmpty) {
      return const Left(
          ValidationFailure(message: 'الرجاء إدخال اسم النشاط التجاري'));
    }

    final roleResult = await rbacRepository.getUserRole(profile.uid);
    final roleId = roleResult.fold((failure) => null, (role) => role.id);

    if (roleId == null || !_allowedRoles.contains(roleId)) {
      return const Left(PermissionFailure(
        message:
            'هذه الميزة مقصورة على حسابات المعامل والورش والموردين وأصحاب الأعمال',
      ));
    }

    return garmentHubRepository.upsertBusinessProfile(profile);
  }
}
