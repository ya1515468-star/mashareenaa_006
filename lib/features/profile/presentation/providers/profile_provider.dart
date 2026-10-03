import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';

/// يبث الملف الشخصي للمستخدم الحالي اعتمادًا على
/// [authControllerProvider] — الربط المباشر بين وحدتي Auth وProfile.
final currentProfileProvider = StreamProvider<ProfileEntity?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  final repository = sl<ProfileRepository>();
  return repository.watchProfile(user.uid);
});

/// يجلب ملفًا شخصيًا لأي مستخدم بمعرّفه — يُستخدم لعرض ملفات الآخرين.
final profileByIdProvider =
    FutureProvider.family<ProfileEntity?, String>((ref, uid) async {
  final repository = sl<ProfileRepository>();
  final result = await repository.getProfile(uid);
  return result.fold((failure) {
    throw StateError(failure.message);
  }, (profile) => profile);
});

/// طبقة الخصوصية الخادمية لعرض بروفايل أي مستخدم (قسم 11 من وثيقة
/// التنفيذ): تُرجع فقط الحقول (الموقع، آخر ظهور) اللي مسموح لهذا
/// المشاهد تحديدًا يشوفها حسب إعداد صاحب الحساب وحالة الصداقة، وتُرجع
/// حقول المالك/سوبر أدمن الإضافية (النقاط، الجواهر، بيانات الأمان)
/// فقط لهم — القرار كله من الخادم عبر get_profile_for_viewer، مو من
/// الفلاتر.
final profileForViewerProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, uid) async {
  final raw = await Supabase.instance.client
      .rpc('get_profile_for_viewer', params: {'p_target_user_id': uid});
  return Map<String, dynamic>.from(raw as Map);
});

class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateTypography({required String usernameFontFamily, required String messageFontFamily}) async {
    state = const AsyncLoading();
    final repository = sl<ProfileRepository>();
    final result = await repository.updateTypography(
      usernameFontFamily: usernameFontFamily,
      messageFontFamily: messageFontFamily,
    );
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          ref.invalidate(currentProfileProvider);
          ref.invalidate(profileByIdProvider(uid));
          // Typography is consumed by the authoritative chat identity providers.
          // Invalidate them here so username/message font changes propagate
          // immediately to the public room without waiting for a Realtime event.
          ref.invalidate(serverUserIdentityProvider);
          ref.invalidate(serverUserIdentityInRoomProvider);
        }
        return true;
      },
    );
  }


  Future<bool> updateProfile(ProfileEntity profile) async {
    state = const AsyncLoading();
    final useCase = sl<UpdateProfileUseCase>();
    final result = await useCase(profile);

    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          // Refresh the profile, authoritative chat identity and frame-size
          // consumers immediately; do not wait for a Realtime emission.
          ref.invalidate(currentProfileProvider);
          ref.invalidate(profileByIdProvider(uid));
          ref.invalidate(serverUserIdentityProvider);
          ref.invalidate(serverUserIdentityInRoomProvider);
          DynamicAvatarFrame.invalidateVisualSizeCache(uid);
        }
        return true;
      },
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(
  ProfileController.new,
);


/// Canonical server-backed ownership set for profile cosmetics and remote avatar frames.
/// Kept in the profile layer so store, profile, and gamification widgets share one provider.
final myProfileCosmeticOwnershipProvider =
    FutureProvider<Set<String>>((ref) async {
  final rows = await Supabase.instance.client.rpc(
    'get_my_profile_cosmetic_ownership',
  );
  if (rows is! List) return <String>{};
  return rows
      .whereType<Map>()
      .map((row) => row['item_key']?.toString())
      .whereType<String>()
      .where((key) => key.isNotEmpty)
      .toSet();
});


/// محتوى VIP المعروض للملف: روابط التواصل والمنتجات والمتجر والاستطلاعات
/// والإعلانات/الباترونات التي يسمح الخادم بإظهارها للزائر الحالي.

/// Public, non-sensitive VIP runtime flags used by profile and chat surfaces.
/// The server is authoritative; this provider never grants ownership locally.
final profilePublicVipEffectsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, uid) async {
  final raw = await Supabase.instance.client.rpc(
    'get_public_vip_effects',
    params: {'p_user_id': uid},
  );
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
});

final profileVipContentProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, uid) async {
  final raw = await Supabase.instance.client.rpc(
    'get_profile_vip_content',
    params: {'p_user_id': uid},
  );
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
});
