import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/usecases/check_permission_usecase.dart';
import '../../domain/usecases/get_user_role_usecase.dart';

/// يجلب دور المستخدم الحالي تلقائيًا اعتمادًا على
/// [authControllerProvider] — الرابط المباشر بين وحدتي Auth وRBAC.
final currentUserRoleProvider = FutureProvider<RoleEntity?>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;

  final useCase = sl<GetUserRoleUseCase>();
  final result = await useCase(user.uid);

  return result.fold((failure) => null, (role) => role);
});

/// يُستخدم مباشرة داخل الشاشات عبر [PermissionGate] للتحقق من صلاحية
/// محددة للمستخدم الحالي.
final hasPermissionProvider =
    FutureProvider.family<bool, String>((ref, permission) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return false;

  final useCase = sl<CheckPermissionUseCase>();
  final result = await useCase(
      CheckPermissionParams(uid: user.uid, permission: permission));

  return result.fold((failure) => false, (allowed) => allowed);
});
