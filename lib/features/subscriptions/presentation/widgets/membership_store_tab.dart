import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/data/supabase_document_compat.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/monitoring/error_monitor.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rbac/presentation/providers/rbac_provider.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../../gamification/domain/entities/username_effect.dart';
import '../../domain/entities/subscription_tier_entity.dart';

import '../providers/subscription_provider.dart';
import 'store_membership_card.dart';

/// أسعار العضويات بالنقاط والجواهر: tierId -> [points, gems].
final _tierPricesProvider =
    FutureProvider<Map<String, List<int>>>((ref) async {
  final snap = await SupabaseDocumentStore.instance
      .collection('subscription_tiers')
      .get();
  final out = <String, List<int>>{};
  for (final doc in snap.docs) {
    final d = doc.data();
    out[doc.id] = [
      (d['pricePoints'] as num?)?.toInt() ?? 0,
      (d['priceGems'] as num?)?.toInt() ?? 0,
    ];
  }
  return out;
});

String _tierPriceText(List<int>? p) {
  if (p == null) return '';
  final parts = <String>[
    if (p[0] > 0) '${p[0]} ⭐',
    if (p[1] > 0) '${p[1]} 💎',
  ];
  return parts.join('  أو  ');
}

final _membershipCatalogProvider =
    FutureProvider<List<SubscriptionTierEntity>>((ref) async {
  final snap = await SupabaseDocumentStore.instance
      .collection('subscription_tiers')
      .get();
  final rows = <Map<String, dynamic>>[];
  for (final doc in snap.docs) {
    final raw = doc.data();
    rows.add({'id': doc.id, 'data': Map<String, dynamic>.from(raw)});
  }
  rows.sort((a, b) {
    final ad = (a['data'] as Map)['displayOrder'];
    final bd = (b['data'] as Map)['displayOrder'];
    return ((ad as num?)?.toInt() ?? 99999)
        .compareTo((bd as num?)?.toInt() ?? 99999);
  });

  final result = <SubscriptionTierEntity>[];
  for (final row in rows) {
    final id = row['id'].toString();
    final data = Map<String, dynamic>.from(row['data'] as Map);
    if (data['enabled'] == false) continue;
    final template = SubscriptionCatalog.byId(id);
    final minor = (data['priceMinorUnits'] as num?)?.toInt() ??
        template?.price.minorUnits ??
        0;
    final currency = CurrencyX.fromWire(data['currency']?.toString());
    final duration = (data['durationDays'] as num?)?.toInt() ??
        template?.durationDays ??
        30;
    result.add(SubscriptionTierEntity(
      id: id,
      name: data['name']?.toString() ?? template?.name ?? id,
      description: data['description']?.toString() ?? '',
      price: Money(minorUnits: minor, currency: currency),
      durationDays: duration,
      unlockedEffects: template?.unlockedEffects ?? const [UsernameEffect.none],
      dailyRewardMultiplier:
          template?.dailyRewardMultiplier ?? 1,
      // A real, owner-settable badge now wins over both the hardcoded
      // template AND the generic ⭐ fallback — a custom-named tier that
      // matches none of the five built-in templates used to be permanently
      // stuck showing ⭐ with no way to change it.
      // صورة الشارة (badgeImageUrl) تسبق الإيموجي، والإيموجي يسبق
      // القالب. ⭐ لم تعد الخيار الوحيد حين لا يطابق المستوى قالبًا.
      badge: MembershipBadge(
        emoji: (data['badgeEmoji']?.toString().trim().isNotEmpty ?? false)
            ? data['badgeEmoji'].toString().trim()
            : (template?.badge.emoji ?? ''),
        imageUrl: (data['badgeImageUrl']?.toString().trim().isNotEmpty ?? false)
            ? data['badgeImageUrl'].toString().trim()
            : null,
        labelAr: data['name']?.toString() ?? id,
        color: data['badgeColor'] is num
            ? Color((data['badgeColor'] as num).toInt())
            : (template?.badge.color ?? const Color(0xFFD4AF37)),
      ),
      features: template?.features ?? const MembershipFeatures(),
      pointsGranted: (data['pointsGranted'] as num?)?.toInt() ?? 0,
      gemsGranted: (data['gemsGranted'] as num?)?.toInt() ?? 0,
      grantedCosmeticKeys: ((data['grantedCosmeticKeys'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      grantedAnimationKeys: ((data['grantedAnimationKeys'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      grantedServiceKeys: ((data['grantedServiceKeys'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      enabled: data['enabled'] != false,
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      trial: data['trial'] == true,
      trialDays: (data['trialDays'] as num?)?.toInt() ?? 0,
      autoRenew: data['autoRenew'] == true,
      level: (data['level'] as num?)?.toInt() ?? 1,
      unlockedServiceCount: (data['unlockedServiceCount'] as num?)?.toInt() ?? 0,
    ));
  }
  return result;
});

class MembershipStoreTab extends ConsumerWidget {
  const MembershipStoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final canManage = ref
            .watch(hasPermissionProvider(AppPermissions.manageStorePricing))
            .valueOrNull ??
        false;
    final current = user == null
        ? null
        : ref.watch(currentSubscriptionProvider).valueOrNull;
    // NOTE: this used to be `.valueOrNull ?? []`, which silently rendered an
    // EMPTY tab whenever the catalog failed to load or was still loading —
    // the tab looked broken with no explanation. The real state is shown now.
    final tiersAsync = ref.watch(_membershipCatalogProvider);
    final dynamicTiers = tiersAsync.valueOrNull ?? const <SubscriptionTierEntity>[];

    // Silent-failure checkpoint. An empty tab throws no exception, so nothing
    // would ever be recorded — the owner would only learn about it if a user
    // happened to complain. These two reports turn that silence into a real
    // entry in the error monitor.
    if (tiersAsync.hasError) {
      unawaited(ErrorMonitor.report(
        tiersAsync.error ?? 'unknown',
        stack: tiersAsync.stackTrace,
        screen: 'memberships_tab',
        source: 'subscription_tiers_load',
      ));
    } else if (!tiersAsync.isLoading && dynamicTiers.isEmpty) {
      unawaited(ErrorMonitor.reportExpectation(
        what: 'تبويب العضويات: تم التحميل بنجاح لكن لم تصل أي عضوية (0 عنصر)',
        source: 'subscription_tiers_empty',
        screen: 'memberships_tab',
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Text('👑 الميزات والميزات المدفوعة',
            style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        // النص التوضيحي عن استثناءات المالك أُزيل: تفاصيل إدارية
        // داخلية لا تعني العضو، وتشوّش على ما يهمّه فعلًا.
        const SizedBox(height: 14),
        if (tiersAsync.isLoading && dynamicTiers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (tiersAsync.hasError)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Text(
              'تعذر تحميل العضويات: ${tiersAsync.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        if (!tiersAsync.isLoading && !tiersAsync.hasError && dynamicTiers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'لا توجد عضويات مفعّلة حاليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ...dynamicTiers.map((tier) => StoreMembershipCard(
              tier: tier,
              currentTierId: current?.tierId,
              ownerMode: canManage,
              priceText: _tierPriceText(ref.watch(_tierPricesProvider).valueOrNull?[tier.id]),
              onPurchase: () => _purchase(context, ref, tier),
              onGift: canManage ? () => _gift(context, tier) : null,
              onEditPrice: canManage ? () => _openFullEditor(context, ref, tier) : null,
              onDelete: canManage ? () => _deleteTier(context, ref, tier) : null,
              onChangeBadge:
                  canManage ? () => _changeBadge(context, ref, tier) : null,
            )),
        if (canManage)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () => _revoke(context),
              icon: const Icon(Icons.block, color: Colors.redAccent),
              label: const Text('إيقاف عضوية مستخدم'),
            ),
          ),
        const SizedBox(height: 20),
        _FeatureLegend(),
      ],
    );
  }

  Future<void> _purchase(
      BuildContext context, WidgetRef ref, SubscriptionTierEntity tier) async {
    final prices = (await ref.read(_tierPricesProvider.future))[tier.id];
    final points = prices?[0] ?? 0;
    final gems = prices?[1] ?? 0;
    if (!context.mounted) return;
    if (points <= 0 && gems <= 0) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('سعر هذه العضوية غير محدّد بعد.')));
      return;
    }
    final currency = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('شراء ${tier.name} لمدة ${tier.durationDays} يوم'),
            ),
            if (points > 0)
              ListTile(
                leading: const Text('⭐', style: TextStyle(fontSize: 22)),
                title: Text('الدفع بالنقاط ($points)'),
                onTap: () => Navigator.pop(ctx, 'points'),
              ),
            if (gems > 0)
              ListTile(
                leading: const Text('💎', style: TextStyle(fontSize: 22)),
                title: Text('الدفع بالجواهر ($gems)'),
                onTap: () => Navigator.pop(ctx, 'gems'),
              ),
          ]),
        ),
      ),
    );
    if (currency == null || !context.mounted) return;
    try {
      final callable =
          SupabaseFunctionsCompat.instance.httpsCallable('purchaseMembership');
      await callable.call({
        'tierId': tier.id,
        'requestId': const Uuid().v4(),
        'currency': currency,
      });
      if (!context.mounted) return;
      ref.invalidate(currentSubscriptionProvider);
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text(
              'تم تفعيل ${tier.name} لمدة ${tier.durationDays} يوم، وخُصم ${currency == 'points' ? '$points نقطة' : '$gems جوهرة'}')));
    } on SupabaseFunctionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text(_membershipError(e.message))));
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_membershipError(e.message))));
    }
  }

  String _membershipError(String? m) => switch (m ?? '') {
        'INSUFFICIENT_POINTS' => 'رصيد النقاط غير كافٍ.',
        'INSUFFICIENT_GEMS' => 'رصيد الجواهر غير كافٍ.',
        'PRICE_NOT_SET' => 'سعر العضوية بهذه العملة غير محدّد.',
        'SERVICE_DISABLED' => 'هذه العضوية غير متاحة حاليًا.',
        '' => 'تعذّر شراء العضوية',
        final x => x,
      };

  Future<void> _revoke(BuildContext context) async {
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إيقاف عضوية مستخدم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'UID المستخدم')),
          const SizedBox(height: 8),
          const Text(
              'تتوقف مزايا العضوية والخدمات المضمّنة فيها فورًا، وتبقى الخدمات التي اشتراها المستخدم بنفسه.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('إيقاف العضوية')),
        ],
      ),
    );
    controller.dispose();
    if (target == null || target.isEmpty) return;
    try {
      await Supabase.instance.client.rpc('admin_revoke_membership', params: {
        'p_target_uid': target,
        'p_request_id': const Uuid().v4(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text('تم إيقاف عضوية المستخدم $target وأُرسل له إشعار')));
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text(e.message.contains('NO_ACTIVE_MEMBERSHIP')
              ? 'لا توجد عضوية فعّالة لهذا المستخدم.'
              : 'تعذّر الإيقاف: ${e.message}')));
    }
  }

  Future<void> _gift(BuildContext context, SubscriptionTierEntity tier) async {
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إهداء ${tier.name}'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'UID المستلم')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('منح')),
        ],
      ),
    );
    controller.dispose();
    if (target == null || target.isEmpty) return;
    try {
      final callable = SupabaseFunctionsCompat.instance
          .httpsCallable('adminGrantMembershipTier');
      await callable.call({'targetUid': target, 'tierId': tier.id, 'requestId': const Uuid().v4()});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text(
              'تم الإهداء ✓ — عضوية ${tier.name} لمدة ${tier.durationDays} يوم، وأُرسل إشعار فوري للمستخدم $target')));
    } on SupabaseFunctionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(e.message ?? 'تعذّر الإهداء')));
    }
  }

  /// رفع صورة شارة للمستوى — للمالك وحده.
  ///
  /// الصورة تُرفع إلى bucket `tier-badges` (سياسته تسمح بالكتابة
  /// للمالك فقط)، ثم owner_set_tier_badge تحفظ رابطها خادميًا في
  /// subscription_tiers. تمرير رابط فارغ يمسحها ويعيد الإيموجي.
  Future<void> _changeBadge(
      BuildContext context, WidgetRef ref, SubscriptionTierEntity tier) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('شارة ${tier.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: Color(0xFFFFD700)),
              title: const Text('رفع صورة'),

              onTap: () => Navigator.pop(ctx, 'upload'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_rounded,
                  color: Color(0xFFFFD700)),
              title: const Text('استخدام إيموجي'),
              onTap: () => Navigator.pop(ctx, 'emoji'),
            ),
            if (tier.badge.imageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (action == null) return;

    try {
      if (action == 'clear') {
        await Supabase.instance.client.rpc('owner_set_tier_badge',
            params: {'p_tier_id': tier.id, 'p_image_url': null});
      } else if (action == 'emoji') {
        if (!context.mounted) return;
        final emoji = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final c = TextEditingController(text: tier.badge.emoji);
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('إيموجي الشارة'),
                content: TextField(
                  controller: c,
                  autofocus: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                  decoration: const InputDecoration(
                      hintText: '👑', counterText: ''),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, c.text.trim()),
                      child: const Text('حفظ')),
                ],
              ),
            );
          },
        );
        if (emoji == null) return;
        await Supabase.instance.client.rpc('owner_set_tier_badge', params: {
          'p_tier_id': tier.id,
          'p_image_url': null,
          'p_emoji': emoji,
        });
      } else {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 90);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final path = '${tier.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await Supabase.instance.client.storage.from('tier-badges').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                  contentType: 'image/$ext', upsert: true),
            );
        final url = Supabase.instance.client.storage
            .from('tier-badges')
            .getPublicUrl(path);

        await Supabase.instance.client.rpc('owner_set_tier_badge',
            params: {'p_tier_id': tier.id, 'p_image_url': url});
      }

      ref.invalidate(_membershipCatalogProvider);
      messenger?.showSnackBarSfx(const SnackBar(
          content: Text('حُدّثت الشارة'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      messenger?.showSnackBarSfx(SnackBar(
          content: Text(e.toString().contains('OWNER_ONLY')
              ? 'هذا الإجراء للمالك فقط.'
              : 'تعذّر تحديث الشارة: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _deleteTier(
      BuildContext context, WidgetRef ref, SubscriptionTierEntity tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف العضوية'),
        content: Text(
            'سيُحذف "${tier.name}" من المتجر نهائيًا. من يملكها حاليًا يبقى محتفظًا بها حتى انتهائها. هل تريد الاستمرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .rpc('admin_delete_membership_tier', params: {'p_tier_id': tier.id});
      ref.invalidate(_membershipCatalogProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تم حذف ${tier.name}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تعذّر الحذف: $e')));
    }
  }

  /// The real "edit everything" dialog — replaces what used to be JUST a
  /// price field behind a button whose tooltip promised full editing. Covers
  /// every field admin_upsert_membership_tier now accepts: identity, pricing,
  /// behaviour, one-time grants, and three kinds of ongoing grants (VIP
  /// services, cosmetics, name animations) plus a real custom badge instead
  /// of the generic ⭐ fallback.
  Future<void> _openFullEditor(
      BuildContext context, WidgetRef ref, SubscriptionTierEntity tier) async {
    final nameCtrl = TextEditingController(text: tier.name);
    final descCtrl = TextEditingController(text: tier.description);
    final priceCtrl = TextEditingController(text: tier.price.value.toStringAsFixed(2));
    final durationCtrl = TextEditingController(text: tier.durationDays.toString());
    final trialDaysCtrl = TextEditingController(text: tier.trialDays.toString());
    final orderCtrl = TextEditingController(text: tier.displayOrder.toString());
    final levelCtrl = TextEditingController(text: tier.level.toString());
    final unlockedCtrl = TextEditingController(text: tier.unlockedServiceCount.toString());
    final pointsCtrl = TextEditingController(text: tier.pointsGranted.toString());
    final gemsCtrl = TextEditingController(text: tier.gemsGranted.toString());
    final curPrices = ref.read(_tierPricesProvider).valueOrNull?[tier.id];
    final pricePointsCtrl =
        TextEditingController(text: (curPrices?[0] ?? 0).toString());
    final priceGemsCtrl =
        TextEditingController(text: (curPrices?[1] ?? 0).toString());
    final emojiCtrl = TextEditingController(text: tier.badge.emoji);

    bool enabled = tier.enabled;
    bool trial = tier.trial;
    bool autoRenew = tier.autoRenew;
    // Real per-tier features, resolved server-side via
    // get_membership_tier_features so this always shows the same values the
    // app actually grants — never a locally-guessed default.
    Map<String, dynamic> initialFeatures = {};
    try {
      final raw = await Supabase.instance.client.rpc(
          'get_membership_tier_features', params: {'p_tier_id': tier.id});
      initialFeatures = raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (e) {
      unawaited(ErrorMonitor.report(e,
          screen: 'membership_full_editor', source: 'load_features'));
    }
    final features = <String, bool>{
      'profileMusic': initialFeatures['profileMusic'] == true,
      'animatedProfilePhoto': initialFeatures['animatedProfilePhoto'] == true,
      'profileBackground': initialFeatures['profileBackground'] == true,
      'avatarFrame': initialFeatures['avatarFrame'] == true,
      'animatedSmileyNextToName': initialFeatures['animatedSmileyNextToName'] == true,
      'canCreateAds': initialFeatures['canCreateAds'] == true,
      'canHideOnlineStatus': initialFeatures['canHideOnlineStatus'] == true,
    };
    const featureLabelsAr = {
      'profileMusic': 'موسيقى في الملف الشخصي',
      'animatedProfilePhoto': 'صورة شخصية متحركة',
      'profileBackground': 'خلفية للملف الشخصي',
      'avatarFrame': 'إطار الصورة الشخصية',
      'animatedSmileyNextToName': 'سمايل متحرك بجانب الاسم',
      'canCreateAds': 'نشر إعلانات ممولة',
      'canHideOnlineStatus': 'إخفاء حالة الاتصال',
    };
    Color badgeColor = tier.badge.color;
    final serviceKeys = {...tier.grantedServiceKeys};
    final cosmeticKeys = {...tier.grantedCosmeticKeys};
    final animationKeys = {...tier.grantedAnimationKeys};

    // Fetched once per dialog open — these lists are the SOURCE for the two
    // checklists and the searchable cosmetic picker below.
    List<Map<String, dynamic>> allServices = [];
    List<Map<String, dynamic>> allAnimations = [];
    List<Map<String, dynamic>> allCosmetics = [];
    try {
      final sb = Supabase.instance.client;
      allServices = List<Map<String, dynamic>>.from(await sb
          .from('profile_service_catalog')
          .select('feature_key,name_ar')
          .eq('is_active', true)
          .order('feature_key'));
      // الخدمات المحددة تُقرأ من قواعد العضوية الفعلية (نفس مصدر نافذة
      // قواعد الخدمات) كي لا يختلف المحرران، وتنتهي بانتهاء العضوية.
      try {
        final rules = await sb.rpc('admin_get_membership_service_rules',
            params: {'p_tier_id': tier.id});
        serviceKeys
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(rules as List)
              .where((r) => r['included'] == true && r['enabled'] != false)
              .map((r) => r['feature_key'].toString()));
      } catch (_) {}
      allAnimations = List<Map<String, dynamic>>.from(await sb
          .from('name_animation_catalog')
          .select('effect_key,name_ar')
          .eq('is_active', true)
          .order('effect_key'));
      allCosmetics = List<Map<String, dynamic>>.from(await sb
          .from('profile_cosmetic_catalog')
          .select('item_key,name_ar,category')
          .eq('is_active', true)
          .order('item_key'));
    } catch (e) {
      unawaited(ErrorMonitor.report(e,
          screen: 'membership_full_editor', source: 'load_catalogs'));
    }

    String cosmeticSearch = '';

    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          final filteredCosmetics = cosmeticSearch.trim().isEmpty
              ? const <Map<String, dynamic>>[]
              : allCosmetics
                  .where((c) => (c['name_ar']?.toString() ?? c['item_key'].toString())
                      .toLowerCase()
                      .contains(cosmeticSearch.toLowerCase()))
                  .take(20)
                  .toList();

          Widget sectionTitle(String t) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              );

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 560,
              height: 680,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                          child: Text('تعديل ${tier.name} بالكامل',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                      IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        sectionTitle('البيانات الأساسية'),
                        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
                        const SizedBox(height: 8),
                        TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'الوصف')),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'السعر شام كاش'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: durationCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'المدة (يوم)'))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: emojiCtrl,
                              decoration: const InputDecoration(
                                labelText: 'أيقونة العضوية',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<Color>(
                                context: dialogContext,
                                builder: (c) => AlertDialog(
                                  title: const Text('لون الشارة'),
                                  content: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      0xFFCD7F32, 0xFFC0C0C0, 0xFFD4AF37, 0xFFB9F2FF,
                                      0xFF7A1F3D, 0xFF6E4B8E, 0xFF4FA88B, 0xFFC8503F,
                                    ]
                                        .map((v) => GestureDetector(
                                              onTap: () => Navigator.pop(c, Color(v)),
                                              child: Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                      color: Color(v), shape: BoxShape.circle)),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              );
                              if (picked != null) setLocal(() => badgeColor = picked);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: badgeColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24)),
                            ),
                          ),
                        ]),
                        sectionTitle('السلوك'),
                        SwitchListTile(
                            dense: true,
                            title: const Text('مفعّلة (تظهر في المتجر)'),
                            value: enabled,
                            onChanged: (v) => setLocal(() => enabled = v)),
                        SwitchListTile(
                            dense: true,
                            title: const Text('تجديد تلقائي'),
                            value: autoRenew,
                            onChanged: (v) => setLocal(() => autoRenew = v)),
                        sectionTitle('مزايا العضوية الفعلية'),
                        const Text(
                          'هذه هي المزايا التي يحصل عليها المشترك فعليًا — تُقرأ وتُحفظ من الخادم مباشرة.',
                          style: TextStyle(fontSize: 10.5, color: Colors.white38),
                        ),
                        ...featureLabelsAr.entries.map((entry) => CheckboxListTile(
                              dense: true,
                              title: Text(entry.value, style: const TextStyle(fontSize: 12)),
                              value: features[entry.key] ?? false,
                              onChanged: (v) => setLocal(() => features[entry.key] = v ?? false),
                            )),
                        SwitchListTile(
                            dense: true,
                            title: const Text('تتضمن تجربة مجانية'),
                            value: trial,
                            onChanged: (v) => setLocal(() => trial = v)),
                        if (trial)
                          TextField(
                              controller: trialDaysCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'أيام التجربة')),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: orderCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'ترتيب العرض'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: levelCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'المستوى'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: unlockedCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'عدد الخدمات المفتوحة'))),
                        ]),
                        sectionTitle('سعر الشراء من رصيد المستخدم (0 = غير متاح بهذه العملة)'),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: pricePointsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'السعر بالنقاط ⭐'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: priceGemsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'السعر بالجواهر 💎'))),
                        ]),
                        sectionTitle('منح فوري عند الشراء'),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: pointsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'نقاط'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: gemsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'جواهر'))),
                        ]),
                        sectionTitle('خدمات VIP ضمن العضوية — تتوقف بانتهائها (${serviceKeys.length})'),
                        SizedBox(
                          height: 220,
                          child: allServices.isEmpty
                              ? const Center(child: Text('لا توجد خدمات', style: TextStyle(fontSize: 12)))
                              : ListView(
                                  children: allServices.map((s) {
                                    final key = s['feature_key'].toString();
                                    return CheckboxListTile(
                                      dense: true,
                                      title: Text(s['name_ar']?.toString() ?? key,
                                          style: const TextStyle(fontSize: 12)),
                                      value: serviceKeys.contains(key),
                                      onChanged: (v) => setLocal(() {
                                        if (v == true) {
                                          serviceKeys.add(key);
                                        } else {
                                          serviceKeys.remove(key);
                                        }
                                      }),
                                    );
                                  }).toList(),
                                ),
                        ),
                        sectionTitle('حيوانات الاسم المرافقة (${animationKeys.length})'),
                        ...allAnimations.map((a) {
                          final key = a['effect_key'].toString();
                          return CheckboxListTile(
                            dense: true,
                            title: Text(a['name_ar']?.toString() ?? key,
                                style: const TextStyle(fontSize: 12)),
                            value: animationKeys.contains(key),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                animationKeys.add(key);
                              } else {
                                animationKeys.remove(key);
                              }
                            }),
                          );
                        }),
                        sectionTitle(
                            'إطارات وتأثيرات وخلفيات (${cosmeticKeys.length})'),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'ابحث بالاسم لإضافة عنصر (إطار، تأثير، خلفية، قالب)',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setLocal(() => cosmeticSearch = v),
                        ),
                        if (filteredCosmetics.isNotEmpty)
                          ...filteredCosmetics.map((c) {
                            final key = c['item_key'].toString();
                            final already = cosmeticKeys.contains(key);
                            return ListTile(
                              dense: true,
                              title: Text(c['name_ar']?.toString() ?? key,
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(c['category']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 10, color: Colors.white38)),
                              trailing: Icon(already ? Icons.check_circle : Icons.add_circle_outline,
                                  color: already ? Colors.greenAccent : null, size: 18),
                              onTap: () => setLocal(() {
                                if (already) {
                                  cosmeticKeys.remove(key);
                                } else {
                                  cosmeticKeys.add(key);
                                }
                              }),
                            );
                          }),
                        if (cosmeticKeys.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: cosmeticKeys
                                .map((k) => Chip(
                                      label: Text(k, style: const TextStyle(fontSize: 10)),
                                      onDeleted: () => setLocal(() => cosmeticKeys.remove(k)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text('إلغاء'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: FilledButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text('حفظ الكل'))),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true) {
      for (final c in [
        nameCtrl, descCtrl, priceCtrl, durationCtrl, trialDaysCtrl,
        orderCtrl, levelCtrl, unlockedCtrl, pointsCtrl, gemsCtrl, emojiCtrl,
        pricePointsCtrl, priceGemsCtrl
      ]) {
        c.dispose();
      }
      return;
    }

    final amount = double.tryParse(priceCtrl.text.trim()) ?? tier.price.value;
    final duration = int.tryParse(durationCtrl.text.trim()) ?? tier.durationDays;
    final trialDays = int.tryParse(trialDaysCtrl.text.trim()) ?? 0;
    final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
    final level = int.tryParse(levelCtrl.text.trim()) ?? 1;
    final unlocked = int.tryParse(unlockedCtrl.text.trim()) ?? 0;
    final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
    final gems = int.tryParse(gemsCtrl.text.trim()) ?? 0;
    final pricePoints = int.tryParse(pricePointsCtrl.text.trim()) ?? 0;
    final priceGems = int.tryParse(priceGemsCtrl.text.trim()) ?? 0;
    final name = nameCtrl.text.trim().isEmpty ? tier.name : nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final emoji = emojiCtrl.text.trim();

    for (final c in [
      nameCtrl, descCtrl, priceCtrl, durationCtrl, trialDaysCtrl,
      orderCtrl, levelCtrl, unlockedCtrl, pointsCtrl, gemsCtrl, emojiCtrl,
      pricePointsCtrl, priceGemsCtrl
    ]) {
      c.dispose();
    }

    try {
      await Supabase.instance.client.rpc('admin_upsert_membership_tier', params: {
        'p_tier_id': tier.id,
        'p_name': name,
        'p_description': desc,
        'p_price_minor_units': (amount * 100).round(),
        'p_currency': 'sham_cash',
        'p_duration_days': duration,
        'p_enabled': enabled,
        'p_display_order': order,
        'p_trial': trial,
        'p_trial_days': trialDays,
        'p_auto_renew': autoRenew,
        'p_level': level,
        'p_unlocked_service_count': unlocked,
        'p_points_granted': points,
        'p_gems_granted': gems,
        'p_granted_cosmetic_keys': cosmeticKeys.toList(),
        'p_granted_animation_keys': animationKeys.toList(),
        'p_granted_service_keys': serviceKeys.toList(),
        'p_badge_emoji': emoji.isEmpty ? null : emoji,
        'p_badge_color': badgeColor.toARGB32(),
        'p_features': features,
      });
      await Supabase.instance.client.rpc('admin_set_membership_price', params: {
        'p_tier_id': tier.id,
        'p_price_points': pricePoints,
        'p_price_gems': priceGems,
      });
      ref.invalidate(_tierPricesProvider);
      ref.invalidate(_membershipCatalogProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(const SnackBar(content: Text('تم حفظ كل تعديلات العضوية ✓')));
    } catch (e) {
      unawaited(ErrorMonitor.report(e,
          screen: 'membership_full_editor', source: 'save'));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تعذّر الحفظ: $e')));
    }
  }
}

class _FeatureLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final f = <String>[
      'شارة عضوية مميزة',
      'تأثيرات اسم المستخدم',
      'إطار صورة شخصية',
      'خلفية ملف شخصي',
      'صورة شخصية متحركة',
      'موسيقى للملف الشخصي',
      'إخفاء حالة الاتصال',
      'إنشاء إعلانات',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('كل الميزات المتاحة عبر الميزات'),
          const SizedBox(height: 8),
          ...f.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(e))
              ]))),
        ]),
      ),
    );
  }
}
