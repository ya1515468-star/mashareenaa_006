import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../features/store/presentation/profile_cosmetic_store_page.dart';
import '../../features/store/presentation/profile_premium_services_tab.dart';

final globalServerRealtimeSyncProvider = Provider<void>((ref) {
  final client = Supabase.instance.client;
  RealtimeChannel? channel;
  Timer? profileTimer;
  Timer? catalogTimer;
  Timer? ownershipTimer;
  Timer? premiumTimer;

  void scheduleProfileRefresh([String? uid]) {
    profileTimer?.cancel();
    profileTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(currentProfileProvider);
      if (uid != null && uid.isNotEmpty) {
        ref.invalidate(profileByIdProvider(uid));
        ref.invalidate(serverUserIdentityProvider);
        ref.invalidate(serverUserIdentityInRoomProvider);
      } else {
        ref.invalidate(serverUserIdentityProvider);
        ref.invalidate(serverUserIdentityInRoomProvider);
      }
    });
  }

  void scheduleStoreCatalogRefresh() {
    catalogTimer?.cancel();
    catalogTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(serverAvatarFramesProvider);
    });
  }

  void scheduleOwnershipRefresh() {
    ownershipTimer?.cancel();
    ownershipTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(myProfileCosmeticOwnershipProvider);
    });
  }

  void schedulePremiumRefresh() {
    premiumTimer?.cancel();
    premiumTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(profilePremiumServicesOwnedProvider);
    });
  }

  // كان .subscribe() يُستدعى بلا callback حالة إطلاقًا — فأي channelError
  // أو timedOut أو توكن منتهي الصلاحية (لا ينضم القناة بتوكن منعشٍ تلقائيًا؛
  // RealtimeResilience يحدّثه فقط عند عودة التطبيق من الخلفية) كان يصل
  // كـRealtimeSubscribeException غير مُعالَج في الـzone الجذرية — وهذا
  // بالضبط الفئة الأكبر تكرارًا في سجل المراقبة (عشرات المرات). هذه القناة
  // تحديدًا عالمية ولا تُغلَق طوال عمر التطبيق (بخلاف قنوات الشاشات التي
  // تُغلق مع autoDispose)، فهي الأكثر تعرّضًا لانتهاء توكن الجلسة مع طول
  // الجلسة.
  //
  // الحل: callback يبتلع الحالات غير الناجحة بدل تركها تنفلت، ثم يعيد
  // الاشتراك بعد تأخير قصير. كل إعادة محاولة تبني قناة جديدة بالكامل
  // عبر client.channel(...) من جديد — إعادة استدعاء subscribe() على
  // نفس كائن القناة القديم يرمي "tried to subscribe multiple times"
  // (القناة تسمح بنداء subscribe() مرة واحدة فقط طوال عمرها).
  Timer? resubscribeTimer;
  void subscribeChannel() {
    final fresh = client.channel('global-server-sync')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        callback: (change) {
          final uid = change.newRecord['id']?.toString() ?? change.oldRecord['id']?.toString();
          scheduleProfileRefresh(uid);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'avatar_frame_catalog',
        callback: (_) => scheduleStoreCatalogRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profile_cosmetic_catalog',
        callback: (_) => scheduleStoreCatalogRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profile_cosmetic_purchases',
        callback: (_) => scheduleOwnershipRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_profile_services',
        callback: (_) => schedulePremiumRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_inventory',
        callback: (_) => scheduleOwnershipRefresh(),
      );

    channel = fresh.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        resubscribeTimer?.cancel();
        resubscribeTimer = Timer(const Duration(seconds: 5), () {
          unawaited(channel?.unsubscribe());
          subscribeChannel();
        });
      }
    });
  }

  subscribeChannel();
  ref.onDispose(() {
    profileTimer?.cancel();
    catalogTimer?.cancel();
    ownershipTimer?.cancel();
    premiumTimer?.cancel();
    resubscribeTimer?.cancel();
    unawaited(channel?.unsubscribe());
  });
});
