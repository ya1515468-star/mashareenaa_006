import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

/// تحديث الملف الشخصي لحساب المستخدم نفسه.
/// الصلاحية الفعلية تُحسم داخل Supabase عبر `sync_my_public_profile`
/// باستخدام `auth.uid()`، لذلك لا نضع حاجز RBAC محليًا يعتمد على اسم
/// صلاحية قد لا تكون موجودة في مخطط الإنتاج (`edit_own_profile`).
class UpdateProfileUseCase {
  final ProfileRepository profileRepository;

  const UpdateProfileUseCase({required this.profileRepository});

  Future<Either<Failure, ProfileEntity>> call(ProfileEntity profile) async {
    return profileRepository.updateProfile(profile);
  }
}
