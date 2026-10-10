import 'dart:convert';
import '../../../core/services/snack_sfx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mashareena/core/services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:mashareena/core/services/media_upload_service.dart';

import '../../profile/presentation/pages/edit_profile_page.dart';
import '../../vip/presentation/pages/vip_chat_runtime_center_page.dart';
import '../../profile/domain/entities/profile_entity.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../../rbac/presentation/widgets/server_username_display.dart';
import '../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../admin/presentation/widgets/admin_gift_dialog.dart';

class ProfilePremiumServiceItem {
  final String key;
  final String nameAr;
  final String descriptionAr;
  final int pricePoints;
  final int priceGems;
  final int sortOrder;
  final bool isActive;
  final String usageSurface;
  final String usageHintAr;
  final String iconKey;
  final String actionKey;

  const ProfilePremiumServiceItem({
    required this.key,
    required this.nameAr,
    required this.descriptionAr,
    required this.pricePoints,
    required this.priceGems,
    required this.sortOrder,
    required this.isActive,
    required this.usageSurface,
    required this.usageHintAr,
    required this.iconKey,
    required this.actionKey,
  });

  factory ProfilePremiumServiceItem.fromMap(Map<String, dynamic> m) =>
      ProfilePremiumServiceItem(
        key: '${m['feature_key']}',
        nameAr: '${m['name_ar']}',
        descriptionAr: '${m['description_ar'] ?? ''}',
        pricePoints: (m['price_points'] as num?)?.toInt() ?? 0,
        priceGems: (m['price_gems'] as num?)?.toInt() ?? 0,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        isActive: m['is_active'] != false,
        usageSurface: '${m['usage_surface'] ?? 'profile'}',
        usageHintAr: '${m['usage_hint_ar'] ?? 'داخل التطبيق'}',
        iconKey: '${m['icon_key'] ?? 'auto_awesome'}',
        actionKey: '${m['action_key'] ?? 'configure_service'}',
      );
}

class ProfilePremiumOwnedService {
  final String key;
  final bool enabled;
  final Map<String, dynamic> settings;
  final String currency;

  const ProfilePremiumOwnedService({
    required this.key,
    required this.enabled,
    required this.settings,
    this.currency = '',
  });

  /// الخدمة ممنوحة ضمن العضوية (تتوقف بانتهائها).
  bool get fromMembership => currency == 'membership';

  factory ProfilePremiumOwnedService.fromMap(Map<String, dynamic> m) =>
      ProfilePremiumOwnedService(
        key: '${m['feature_key']}',
        enabled: m['enabled'] == true,
        currency: '${m['currency'] ?? ''}',
        settings: m['settings'] is Map
            ? Map<String, dynamic>.from(m['settings'] as Map)
            : <String, dynamic>{},
      );
}

final profilePremiumServicesCatalogProvider =
    FutureProvider.autoDispose<List<ProfilePremiumServiceItem>>((ref) async {
  final rows = await Supabase.instance.client.rpc('get_profile_service_catalog');
  final list = rows is List ? rows : const <dynamic>[];
  return list
      .whereType<Map>()
      .map((e) => ProfilePremiumServiceItem.fromMap(
            Map<String, dynamic>.from(e),
          ))
      .where((item) => item.key.trim().isNotEmpty)
      .toList(growable: false);
});

final profilePremiumRuntimeProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final raw = await Supabase.instance.client.rpc(
    'get_profile_service_runtime',
    params: {'p_feature_key': key},
  );
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

final profilePremiumServicesOwnedProvider =
    FutureProvider.autoDispose<Map<String, ProfilePremiumOwnedService>>((ref) async {
  final rows = await Supabase.instance.client.rpc('get_my_profile_services');
  final map = <String, ProfilePremiumOwnedService>{};
  final list = rows is List ? rows : const <dynamic>[];
  for (final raw in list.whereType<Map>()) {
    final item = ProfilePremiumOwnedService.fromMap(
      Map<String, dynamic>.from(raw),
    );
    map[item.key] = item;
  }
  return map;
});

final profilePremiumOwnerProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Supabase.instance.client.rpc('is_my_platform_owner') == true;
  } catch (_) {
    return false;
  }
});

final platformVipRevenueSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final raw = await Supabase.instance.client.rpc('get_platform_vip_revenue_summary');
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

class ProfilePremiumServicesTab extends ConsumerStatefulWidget {
  const ProfilePremiumServicesTab({super.key});

  @override
  ConsumerState<ProfilePremiumServicesTab> createState() =>
      _ProfilePremiumServicesTabState();
}

class _ProfilePremiumServicesTabState
    extends ConsumerState<ProfilePremiumServicesTab> {
  String _friendly(Object error) {
    final text = error.toString();
    const map = <String, String>{
      'INSUFFICIENT_POINTS': 'رصيد النقاط غير كافٍ.',
      'INSUFFICIENT_GEMS': 'رصيد الجواهر غير كافٍ.',
      'ITEM_NOT_OWNED': 'الخدمة غير مملوكة لهذا الحساب.',
      'FEATURE_REQUIRED_PROFILE_VISITORS': 'خدمة زوار الملف غير مفعلة.',
      'FEATURE_REQUIRED_PROFILE_MINI_STORE': 'خدمة المتجر المصغر غير مفعلة.',
      'FEATURE_REQUIRED_ADVANCED_POLLS': 'خدمة الاستطلاعات غير مفعلة.',
      'FEATURE_REQUIRED_TARGETED_ADS': 'خدمة الإعلانات الموجهة غير مفعلة.',
      'FEATURE_REQUIRED_COST_CALCULATOR': 'خدمة حاسبة التكلفة غير مفعلة.',
      'FEATURE_REQUIRED_PATTERN_SHARING': 'خدمة الباترونات غير مفعلة.',
      'FEATURE_REQUIRED_PROFILE_PRODUCTS': 'خدمة المنتجات غير مفعلة.',
      'FEATURE_REQUIRED_PROFILE_MUSIC': 'خدمة موسيقى البروفايل غير مفعلة.',
      'FEATURE_REQUIRED_SOCIAL_LINKS': 'خدمة روابط التواصل غير مفعلة.',
      'FEATURE_REQUIRED_VOICE_VIDEO_CALLS': 'خدمة الاتصالات غير مفعلة.',
      'FEATURE_REQUIRED_HIDE_PROFILE': 'خدمة إخفاء البروفايل غير مفعلة.',
      'FEATURE_REQUIRED_HIDE_JOIN_ANNOUNCEMENT': 'خدمة إخفاء الدخول غير مفعلة.',
      'FEATURE_REQUIRED_ANONYMOUS_CHAT': 'خدمة المشاركة المجهولة غير مفعلة.',
      'PRICE_NOT_SET': 'السعر غير مضبوط.',
      'INVALID_PRICE': 'السعر غير صالح.',
      'INVALID_PRODUCT': 'بيانات المنتج أو المرفق غير صالحة.',
      'INVALID_PATTERN': 'بيانات الباترون غير صالحة.',
      'INVALID_TITLE': 'العنوان مطلوب.',
      'INVALID_AD': 'بيانات الإعلان غير صالحة.',
      'FEATURE_REQUIRED_VIP': 'هذه الخدمة تحتاج اشتراك VIP فعال.',
      'FEATURE_REQUIRED_PROFILE_PRODUCT': 'خدمة منتجات الملف غير مفعلة.',
      'PATTERN_NOT_PURCHASED': 'يجب شراء الباترون أولاً.',
      'PRODUCT_NOT_AVAILABLE': 'المنتج غير متاح حالياً.',
      'INVALID_RECIPIENT': 'لا يمكن شراء منتجك من نفسك.',
      'AD_NOT_FOUND': 'الإعلان غير موجود.',
      'REQUEST_ID_REPLAY_FORBIDDEN': 'تعذر تكرار عملية شراء قديمة.',
      'PLATFORM_OWNER_NOT_CONFIGURED': 'لم يتم إعداد مالك المنصة DRAGON على الخادم.',
      'SERVICE_CHECK_FAILED': 'تعذر التحقق من أهلية خدمة VIP على الخادم.',
      'FEATURE_REQUIRED_VOICE_VIDEO': 'خدمة الاتصال الصوتي والمرئي غير مفعلة لهذا الحساب.',
      'PROFILE_SERVICE_REQUIRED': 'يجب تفعيل خدمة تصغير حجم اسم المستخدم أولًا.',
      'USERNAME_FONT_SIZE_OUT_OF_RANGE': 'حجم الاسم يجب أن يكون بين 10 و26.',
    };
    for (final entry in map.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return text.replaceFirst('PostgrestException(message: ', '').replaceFirst(')', '');
  }

  Future<void> _recordServiceUse(String featureKey, {String action = 'use'}) async {
    try {
      await Supabase.instance.client.rpc(
        'record_profile_service_use',
        params: {
          'p_feature_key': featureKey,
          'p_context': {'action': action},
        },
      );
      ref.invalidate(profilePremiumServicesOwnedProvider);
      ref.invalidate(profilePremiumRuntimeProvider(featureKey));
    } catch (_) {
      // Usage accounting must never break the primary VIP action.
    }
  }

  Future<void> _purchase(ProfilePremiumServiceItem item) async {
    final owned = ref.read(profilePremiumServicesOwnedProvider).valueOrNull;
    final owner = ref.read(profilePremiumOwnerProvider).valueOrNull == true;
    if (owned?.containsKey(item.key) == true || owner) {
      await _openService(item);
      return;
    }

    final purchaseOptions = <({String currency, String label, IconData icon})>[
      if (item.pricePoints > 0)
        (currency: 'points', label: '${item.pricePoints} نقطة', icon: Icons.star),
      if (item.priceGems > 0)
        (currency: 'gems', label: '${item.priceGems} جوهرة', icon: Icons.diamond),
    ];
    if (purchaseOptions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('هذه الخدمة غير متاحة للشراء حالياً لأن سعرها غير مضبوط.')),
      );
      return;
    }
    final currency = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'اختر طريقة الشراء',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final option in purchaseOptions)
              ListTile(
                leading: Icon(option.icon, color: option.currency == 'points' ? Colors.amber : Colors.cyan),
                title: Text(option.label),
                onTap: () => Navigator.pop(sheetContext, option.currency),
              ),
          ],
        ),
      ),
    );
    if (currency == null) return;
    final selectedPrice = currency == 'points' ? '${item.pricePoints} نقطة' : '${item.priceGems} جوهرة';
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('سيتم شراء خدمة «${item.nameAr}» مقابل $selectedPrice وحفظها على الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('شراء')),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;

    try {
      await Supabase.instance.client.rpc(
        'purchase_profile_service',
        params: {
          'p_feature_key': item.key,
          'p_currency': currency,
          'p_request_id': const Uuid().v4(),
        },
      );
      ref.invalidate(profilePremiumServicesOwnedProvider);
      ref.invalidate(profilePremiumRuntimeProvider(item.key));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تم تفعيل ${item.nameAr} على الخادم ✓')),
      );
      await _openService(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _toggle(ProfilePremiumServiceItem item, bool enabled) async {
    try {
      await Supabase.instance.client.rpc(
        'set_profile_service_enabled',
        params: {'p_feature_key': item.key, 'p_enabled': enabled},
      );
      ref.invalidate(profilePremiumServicesOwnedProvider);
      if (item.key == 'hide_profile' && !enabled) {
        await Supabase.instance.client.rpc(
          'set_my_profile_visibility',
          params: {'p_visibility': 'public'},
        );
        ref.invalidate(currentProfileProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(enabled ? 'تم التفعيل' : 'تم الإيقاف')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _activateVerification() async {
    try {
      await Supabase.instance.client
          .rpc('activate_profile_service', params: {'p_feature_key': 'account_verification'});
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(const SnackBar(content: Text('تم تفعيل التوثيق ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _editPrice(ProfilePremiumServiceItem item) async {
    final owner = ref.read(profilePremiumOwnerProvider).valueOrNull == true;
    if (!owner) return;
    final points = TextEditingController(text: '${item.pricePoints}');
    final gems = TextEditingController(text: '${item.priceGems}');
    var active = item.isActive;
    (int, int, bool)? result;
    try {
      result = await showDialog<(int, int, bool)?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text(item.nameAr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر النقاط'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gems,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر الجواهر'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  title: const Text('الخدمة متاحة للشراء'),
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  (int.tryParse(points.text) ?? -1, int.tryParse(gems.text) ?? -1, active),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
    } finally {
      points.dispose();
      gems.dispose();
    }
    final priceResult = result;
    if (priceResult == null) return;
    final (pricePoints, priceGems, isActive) = priceResult;
    if (pricePoints < 0 || priceGems < 0) return;
    try {
      await Supabase.instance.client.rpc(
        'update_profile_service_price',
        params: {
          'p_feature_key': item.key,
          'p_price_points': pricePoints,
          'p_price_gems': priceGems,
          'p_is_active': isActive,
        },
      );
      ref.invalidate(profilePremiumServicesCatalogProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('تم تحديث السعر وحالة البيع على الخادم ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _usernameFontSizeDialog() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (!mounted || profile == null) return;
    var value = profile.usernameFontSize.clamp(14.0, 34.0).toDouble();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('تصغير/تكبير اسم المستخدم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.toStringAsFixed(1)} px', style: const TextStyle(fontWeight: FontWeight.w900)),
              Slider(
                min: 14, max: 34, divisions: 20, value: value,
                onChanged: (v) => setState(() => value = v),
              ),
              const Text('يُحفظ الحجم على الخادم ويُستخدم في البروفايل والشات.', style: TextStyle(fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    ) ?? false;
    if (!saved || !mounted) return;
    try {
      await Supabase.instance.client.rpc('set_my_username_font_size', params: {'p_font_size': value});
      ref.invalidate(currentProfileProvider);
      ref.invalidate(serverUserIdentityProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم حفظ حجم الاسم على الخادم ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _openService(ProfilePremiumServiceItem item) async {
    if (!mounted) return;
    try {
      switch (item.key) {
        case 'profile_visitors':
          await _showVisitors();
          break;
        case 'account_verification':
          await _activateVerification();
          break;
        case 'hide_join_announcement':
        case 'anonymous_chat':
        case 'voice_video_calls':
          await _showToggle(item);
          break;
        case 'profile_products':
          await _createProfileProductDialog();
          break;
        case 'hide_profile':
          await _hideProfileDialog();
          break;
        case 'achievement_badges':
          await _showBadges();
          break;
        case 'profile_music':
        case 'social_links':
          final profile = ref.read(currentProfileProvider).valueOrNull;
          if (!mounted || profile == null) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => EditProfilePage(profile: profile)),
          );
          break;
        case 'self_destruct_chat':
          await _selfDestructSettings();
          break;
        case 'advanced_profile_polls':
          await _createPollDialog();
          break;
        case 'profile_targeted_ads':
          await _createAdDialog();
          break;
        case 'profile_mini_store':
          await _createMiniStoreItemDialog();
          break;
        case 'pattern_sharing':
          await _uploadPatternDialog();
          break;
        case 'production_cost_calculator':
          await _calculatorDialog();
          break;
        case 'profile_theme_plus':
        case 'profile_card_plus':
        case 'profile_highlight':
        case 'profile_visitor_alerts':
          await _openExtendedVipService(item);
          break;
        case 'username_font_size':
          await _usernameFontSizeDialog();
          break;
        case 'profile_contact_button':
        case 'profile_qr_card':
        case 'profile_custom_badge':
        case 'profile_priority_search':
        case 'chat_name_gradient':
        case 'chat_message_glow':
        case 'chat_priority_badge':
        case 'chat_mention_highlight':
        case 'profile_analytics_plus':
        case 'tailor_pattern_highlight':
          await _openExtendedVipService(item);
          break;
        case 'chat_link_preview_plus':
        case 'chat_media_plus':
        case 'chat_favorites_plus':
        case 'chat_presence_plus':
        case 'chat_smart_mute':
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VipChatRuntimeCenterPage(featureKey: item.key),
          ));
          break;
        case 'creator_tip_button':
          await _openCreatorTipDialog();
          break;
        default:
          return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(_friendly(e))),
      );
      return;
    }

    if (!mounted) return;
    const serverRecorded = <String>{
      'account_verification',
      'hide_join_announcement',
      'anonymous_chat',
      'voice_video_calls',
      'hide_profile',
      'self_destruct_chat',
      'profile_targeted_ads',
      'profile_products',
      'profile_mini_store',
      'advanced_profile_polls',
      'pattern_sharing',
      'production_cost_calculator',
    };
    if (!serverRecorded.contains(item.key)) {
      await _recordServiceUse(item.key, action: 'use');
    }
  }

  Future<void> _openExtendedVipService(ProfilePremiumServiceItem item) async {
    if (!mounted) return;
    final runtime = await ref.read(profilePremiumRuntimeProvider(item.key).future);
    if (!mounted) return;
    final owned = ref.read(profilePremiumServicesOwnedProvider).valueOrNull?[item.key];
    final controller = TextEditingController(
      text: owned?.settings['value']?.toString() ?? _defaultVipSetting(item.key),
    );
    var enabled = owned?.enabled ?? true;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Row(
              children: [
                CircleAvatar(radius: 18, child: Icon(_icon(item.iconKey), size: 19)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.nameAr)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(item.descriptionAr),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('المكان: ${item.usageHintAr}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('الإجراء: ${item.actionKey}', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    runtime['enabled'] == true ? 'الخدمة مفعلة على الخادم ✓' : 'الخدمة غير مفعلة على الخادم',
                    style: TextStyle(color: runtime['enabled'] == true ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('مرات الاستخدام: ${runtime['use_count'] ?? 0}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    title: const Text('تفعيل الخدمة'),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _vipSettingLabel(item.key),
                      hintText: _vipSettingHint(item.key),
                      prefixIcon: Icon(_icon(item.iconKey)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ وتفعيل')),
            ],
          ),
        ),
      );
      if (saved != true || !mounted) return;
      final owner = ref.read(profilePremiumOwnerProvider).valueOrNull == true;
      if (owner) {
        await Supabase.instance.client.rpc(
          'set_profile_service_enabled',
          params: {'p_feature_key': item.key, 'p_enabled': true},
        );
      }
      await Supabase.instance.client.rpc(
        'set_profile_service_setting',
        params: {
          'p_feature_key': item.key,
          'p_key': 'value',
          'p_value': controller.text.trim(),
        },
      );
      await Supabase.instance.client.rpc(
        'set_profile_service_enabled',
        params: {'p_feature_key': item.key, 'p_enabled': enabled},
      );
      ref.invalidate(profilePremiumServicesOwnedProvider);
      ref.invalidate(profilePremiumRuntimeProvider(item.key));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تم حفظ ${item.nameAr} وربطه بحسابك على الخادم ✓')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openCreatorTipDialog() async {
    final recipient = TextEditingController();
    final amount = TextEditingController(text: '100');
    String currency = 'points';
    try {
      final result = await showDialog<(String, int)?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text('دعم المنشئ'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: recipient, decoration: const InputDecoration(labelText: 'UID صاحب المحتوى')),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار الدعم')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'points', label: Text('نقاط')), ButtonSegment(value: 'gems', label: Text('جواهر'))],
                selected: {currency},
                onSelectionChanged: (v) => setState(() => currency = v.first),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () { final n=int.tryParse(amount.text.trim())??0; if(recipient.text.trim().isEmpty||n<=0)return; Navigator.pop(dialogContext,(recipient.text.trim(),n)); }, child: const Text('إرسال الدعم')),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      try {
        final rpc = currency == 'points' ? 'transfer_points' : 'transfer_gems_to_user';
        final raw = await Supabase.instance.client.rpc(rpc, params: {
          'p_to_user_id': result.$1,
          'p_amount': result.$2,
          'p_idempotency_key': const Uuid().v4(),
        });
        if (raw is! Map || raw['ok'] != true) throw StateError('لم يؤكد الخادم نجاح الدعم.');
        if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم إرسال دعم المنشئ وتسجيل العملية خادميًا ✓')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
      }
    } finally {
      recipient.dispose();
      amount.dispose();
    }
  }

  String _defaultVipSetting(String key) {
    const defaults = <String, String>{
      'profile_theme_plus': 'احترافي',
      'profile_card_plus': 'كلاسيكي',
      'profile_highlight': 'مميز',
      'profile_visitor_alerts': 'تشغيل',
      'profile_contact_button': 'تواصل معي',
      'profile_qr_card': 'مشاركة البروفايل',
      'profile_custom_badge': 'VIP',
      'profile_priority_search': 'مرتفع',
      'chat_name_gradient': '#FFD166 → #7DD3FC',
      'chat_message_glow': 'متوسط',
      'chat_priority_badge': 'VIP',
      'chat_mention_highlight': 'تمييز',
      'chat_link_preview_plus': 'موسع',
      'chat_media_plus': 'موسع',
      'chat_favorites_plus': 'مفعلة',
      'chat_presence_plus': 'متاح',
      'chat_smart_mute': '30 ثانية',
      'creator_tip_button': 'دعم المنشئ',
      'profile_analytics_plus': '30 يوم',
      'tailor_pattern_highlight': 'مميز',
    };
    return defaults[key] ?? '';
  }

  String _vipSettingLabel(String key) {
    const labels = <String, String>{
      'profile_theme_plus': 'نمط الثيم',
      'profile_card_plus': 'نمط البطاقة',
      'profile_highlight': 'حالة التمييز',
      'profile_visitor_alerts': 'إعداد التنبيه',
      'profile_contact_button': 'نص زر التواصل',
      'profile_qr_card': 'عنوان بطاقة QR',
      'profile_custom_badge': 'نص الشارة',
      'profile_priority_search': 'مستوى الأولوية',
      'chat_name_gradient': 'ألوان التدرج',
      'chat_message_glow': 'قوة التوهج',
      'chat_priority_badge': 'نمط الشارة',
      'chat_mention_highlight': 'نمط التمييز',
      'chat_link_preview_plus': 'نمط المعاينة',
      'chat_media_plus': 'نمط الوسائط',
      'chat_favorites_plus': 'إعداد المفضلة',
      'chat_presence_plus': 'نمط الحضور',
      'chat_smart_mute': 'مدة الكتم',
      'creator_tip_button': 'عنوان زر الدعم',
      'profile_analytics_plus': 'الفترة',
      'tailor_pattern_highlight': 'نمط إبراز الباترون',
    };
    return labels[key] ?? 'إعداد الخدمة';
  }

  String _vipSettingHint(String key) => 'يُحفظ على الخادم ضمن إعدادات ${itemNameForKey(key)}';

  String itemNameForKey(String key) {
    const names = <String, String>{
      'profile_theme_plus': 'ثيم البروفايل', 'profile_card_plus': 'بطاقة البروفايل',
      'profile_highlight': 'تمييز البروفايل', 'profile_visitor_alerts': 'تنبيهات الزوار',
      'profile_contact_button': 'زر التواصل', 'profile_qr_card': 'بطاقة QR',
      'profile_custom_badge': 'الشارة المخصصة', 'profile_priority_search': 'أولوية البحث',
      'chat_name_gradient': 'اسم الشات المتدرج', 'chat_message_glow': 'توهج الرسائل',
      'chat_priority_badge': 'شارة أولوية الشات', 'chat_mention_highlight': 'تمييز المنشن',
      'chat_link_preview_plus': 'معاينة الروابط', 'chat_media_plus': 'الوسائط Plus',
      'chat_favorites_plus': 'مفضلة الشات', 'chat_presence_plus': 'الحضور Plus',
      'chat_smart_mute': 'الكتم الذكي', 'creator_tip_button': 'دعم المنشئ',
      'profile_analytics_plus': 'إحصائيات البروفايل', 'tailor_pattern_highlight': 'تمييز الباترونات',
    };
    return names[key] ?? 'الخدمة';
  }

  Future<void> _showVisitors() async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_my_profile_visitors',
        params: {'p_limit': 50},
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'زوار ملفك',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              for (final raw in (rows as List))
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (raw as Map)['avatar_url']?.toString().isNotEmpty == true
                        ? NetworkImage('${raw['avatar_url']}')
                        : null,
                    child: raw['avatar_url']?.toString().isNotEmpty == true
                        ? null
                        : const Icon(Icons.person),
                  ),
                  title: ServerUsernameDisplay(
                    uid: (raw['visitor_uid']?.toString() ?? raw['profile_uid']?.toString() ?? ''),
                    fallbackName: '${raw['display_name'] ?? raw['username'] ?? 'عضو'}',
                    fallbackFontSize: 16,
                    showBadges: true,
                    showAchievements: false,
                  ),
                  subtitle: Text('${raw['visited_at'] ?? ''}'),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _showBadges() async {
    List<String> badges = const <String>[];
    try {
      final raw = await Supabase.instance.client.rpc('get_my_achievement_badges');
      if (raw is Map && raw['badges'] is List) {
        badges = (raw['badges'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(growable: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('سجل الإنجازات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            if (badges.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد شارات مكتسبة حتى الآن.', textAlign: TextAlign.center),
              )
            else
              for (final badge in badges)
                ListTile(leading: const Icon(Icons.workspace_premium, color: Colors.amber), title: Text(badge)),
          ],
        ),
      ),
    );
  }

  Future<void> _showToggle(ProfilePremiumServiceItem item) async {
    if (!mounted) return;
    final owned = ref.read(profilePremiumServicesOwnedProvider).valueOrNull?[item.key];
    final enabled = owned?.enabled ?? true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.nameAr),
        content: SwitchListTile(
          value: enabled,
          onChanged: (value) async {
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (!mounted) return;
            await _toggle(item, value);
          },
          title: const Text('الخدمة مفعلة'),
        ),
      ),
    );
  }

  Future<void> _hideProfileDialog() async {
    if (!mounted) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    final hide = profile.visibility == ProfileVisibility.public;
    try {
      await Supabase.instance.client.rpc(
        'set_my_profile_visibility',
        params: {'p_visibility': hide ? 'private' : 'public'},
      );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(hide ? 'تم إخفاء البروفايل' : 'تم إظهار البروفايل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(_friendly(e))),
      );
    }
  }

  Future<void> _selfDestructSettings() async {
    final controller = TextEditingController(text: '10');
    final current = ref.read(profilePremiumServicesOwnedProvider).valueOrNull?['self_destruct_chat'];
    controller.text = '${current?.settings['seconds'] ?? 10}';
    late final int? value;
    try {
      value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('الدردشة ذاتية التدمير'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الثواني بعد القراءة'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                int.tryParse(controller.text),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (value == null || value < 1 || value > 300 || !mounted) return;
    await Supabase.instance.client.rpc(
      'set_profile_service_setting',
      params: {
        'p_feature_key': 'self_destruct_chat',
        'p_key': 'seconds',
        'p_value': value,
      },
    );
    ref.invalidate(profilePremiumServicesOwnedProvider);
  }

  Future<void> _calculatorDialog() async {
    final fabric = TextEditingController();
    final accessories = TextEditingController();
    final hours = TextEditingController();
    final rate = TextEditingController();
    final overhead = TextEditingController(text: '10');
    try {
      await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('عداد تكلفة الإنتاج'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _numField(fabric, 'سعر القماش'),
              _numField(accessories, 'الإكسسوارات'),
              _numField(hours, 'ساعات العمل'),
              _numField(rate, 'سعر الساعة'),
              _numField(overhead, 'المصاريف العامة %'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                final response = await Supabase.instance.client.rpc(
                  'save_production_cost_calculation',
                  params: {
                    'p_fabric': double.tryParse(fabric.text) ?? 0,
                    'p_accessories': double.tryParse(accessories.text) ?? 0,
                    'p_hours': double.tryParse(hours.text) ?? 0,
                    'p_hourly_rate': double.tryParse(rate.text) ?? 0,
                    'p_overhead': double.tryParse(overhead.text) ?? 0,
                  },
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (resultContext) => AlertDialog(
                    title: const Text('النتيجة'),
                    content: Text(const JsonEncoder.withIndent('  ').convert(response)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(resultContext),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext)
                    .showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
              }
            },
            child: const Text('احسب واحفظ'),
          ),
        ],
      ),
      );
    } finally {
      fabric.dispose();
      accessories.dispose();
      hours.dispose();
      rate.dispose();
      overhead.dispose();
    }
  }

  Widget _numField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _createPollDialog() async {
    final q = TextEditingController();
    final o1 = TextEditingController();
    final o2 = TextEditingController();
    try {
      await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استطلاع متقدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: q, decoration: const InputDecoration(labelText: 'السؤال')),
            TextField(controller: o1, decoration: const InputDecoration(labelText: 'الخيار الأول')),
            TextField(controller: o2, decoration: const InputDecoration(labelText: 'الخيار الثاني')),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.rpc('create_profile_poll', params: {
                  'p_question': q.text,
                  'p_options': [o1.text, o2.text],
                  'p_is_multiple': false,
                });
                ref.invalidate(profilePremiumRuntimeProvider('profile_mini_store'));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
                }
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
      );
    } finally {
      q.dispose();
      o1.dispose();
      o2.dispose();
    }
  }

  Future<void> _createAdDialog() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final city = TextEditingController();
    final profession = TextEditingController();
    final budget = TextEditingController(text: '1000');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إعلان موجه للبروفايل'),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
              TextField(controller: body, decoration: const InputDecoration(labelText: 'النص')),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة (اختياري)')),
              TextField(controller: profession, decoration: const InputDecoration(labelText: 'المهنة (اختياري)')),
              TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ميزانية الإعلان بالنقاط')),
            ]),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                try {
                  final createdId = await Supabase.instance.client.rpc('create_profile_targeted_ad', params: {
                    'p_title': title.text.trim(),
                    'p_body': body.text.trim(),
                    'p_target_city': city.text.trim().isEmpty ? null : city.text.trim(),
                    'p_target_profession': profession.text.trim().isEmpty ? null : profession.text.trim(),
                    'p_budget_points': int.tryParse(budget.text) ?? 0,
                  });
                  await Supabase.instance.client.rpc('publish_profile_targeted_ad', params: {'p_ad_id': createdId});
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم إنشاء الحملة ودفع ميزانيتها ونشرها ✓')));
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
                  }
                }
              },
              child: const Text('دفع الميزانية ونشر الحملة'),
            ),
          ],
        ),
      );
    } finally {
      title.dispose();
      body.dispose();
      city.dispose();
      profession.dispose();
      budget.dispose();
    }
  }

  Future<void> _createProfileProductDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final price = TextEditingController(text: '0');
    String mediaType = 'image';
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov'
        ],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || !mounted) return;
      final ext = file.extension?.toLowerCase() ?? '';
      mediaType = const {'mp4', 'webm', 'mov'}.contains(ext) ? 'video' : 'image';

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد رفع منتج البروفايل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'السعر بالنقاط'),
                ),
                const SizedBox(height: 8),
                Text(
                  'المرفق: ${file.name} • $mediaType\nبعد التأكيد سيتم رفع الملف ثم حفظ المنتج على الخادم.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('رفع ونشر'),
            ),
          ],
        ),
      );
      if (result != true || !mounted) return;
      if (title.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('اكتب عنوان المنتج أولًا.')),
        );
        return;
      }

      String? mediaUrl;
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null || uid.isEmpty) throw StateError('AUTH_REQUIRED');
        mediaUrl = await MediaUploadService(bucket: 'profile-products').uploadBytes(
          bytes: bytes,
          fileName: file.name,
          folder: 'profile-products',
          uid: uid,
        );
        try {
          await Supabase.instance.client.rpc('create_profile_product_showcase', params: {
            'p_title': title.text.trim(),
            'p_description': desc.text.trim(),
            'p_media_url': mediaUrl,
            'p_media_type': mediaType,
            'p_price_points': int.tryParse(price.text.trim()) ?? 0,
            'p_price_gems': 0,
          });
        } catch (e) {
          await MediaUploadService(bucket: 'profile-products').deleteFile(mediaUrl);
          rethrow;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBarSfx(
            SnackBar(content: Text(_friendly(e))),
          );
        }
        return;
      }
      ref.invalidate(profilePremiumRuntimeProvider('profile_products'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('تم رفع المنتج وحفظه على الخادم ✓')),
        );
      }
    } finally {
      title.dispose();
      desc.dispose();
      price.dispose();
    }
  }

  Future<void> _createMiniStoreItemDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final points = TextEditingController(text: '0');
    final gems = TextEditingController(text: '0');
    try {
      await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('عنصر المتجر المصغر'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'الوصف')),
          TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط')),
          TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الجواهر')),
        ]),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.rpc('create_profile_mini_store_item', params: {
                  'p_title': title.text,
                  'p_description': desc.text,
                  'p_price_points': int.tryParse(points.text) ?? 0,
                  'p_price_gems': int.tryParse(gems.text) ?? 0,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
      );
    } finally {
      title.dispose();
      desc.dispose();
      points.dispose();
      gems.dispose();
    }
  }

  Future<void> _uploadPatternDialog() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'pdf', 'zip'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty || !mounted) return;

    final title = TextEditingController();
    final desc = TextEditingController();
    final points = TextEditingController(text: '0');
    final gems = TextEditingController(text: '0');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('باترون جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: points,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر النقاط'),
              ),
              TextField(
                controller: gems,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر الجواهر'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                try {
                  final uid = Supabase.instance.client.auth.currentUser?.id;
                  if (uid == null || uid.isEmpty) {
                    throw StateError('AUTH_REQUIRED');
                  }
                  final safe = file.name.replaceAll(
                    RegExp(r'[^A-Za-z0-9._-]'),
                    '_',
                  );
                  final path =
                      '$uid/${DateTime.now().microsecondsSinceEpoch}_$safe';
                  await MediaUploadService(bucket: 'profile-patterns').uploadBytesAtPath(
                    bytes: bytes,
                    fileName: file.name,
                    path: path,
                  );
                  try {
                    await Supabase.instance.client.rpc(
                      'create_profile_pattern',
                      params: {
                        'p_title': title.text.trim(),
                        'p_description': desc.text.trim(),
                        'p_asset_url': path,
                        'p_preview_url': null,
                        'p_price_points': int.tryParse(points.text.trim()) ?? 0,
                        'p_price_gems': int.tryParse(gems.text.trim()) ?? 0,
                      },
                    );
                  } catch (e) {
                    try {
                      await SupabaseService.deleteStoragePath(
                        bucket: 'profile-patterns',
                        path: path,
                      );
                    } catch (_) {}
                    rethrow;
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBarSfx(
                      SnackBar(content: Text(_friendly(e))),
                    );
                  }
                }
              },
              child: const Text('رفع وحفظ'),
            ),
          ],
        ),
      );
    } finally {
      title.dispose();
      desc.dispose();
      points.dispose();
      gems.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(profilePremiumServicesCatalogProvider);
    final owned = ref.watch(profilePremiumServicesOwnedProvider).valueOrNull ?? const <String, ProfilePremiumOwnedService>{};
    final owner = ref.watch(profilePremiumOwnerProvider).valueOrNull == true;
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذر تحميل خدمات VIP: ${_friendly(e)}')),
      data: (items) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(Icons.workspace_premium_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('خدمات VIP — مزايا مدفوعة حقيقية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          owner
                              ? 'أنت مالك المنصة: تتحكم بالأسعار وحالة البيع من الخادم، بينما باقي الأعضاء يشترون الخدمة فقط.'
                              : 'كل خدمة تُفعل بعد شراء حقيقي من الخادم وتبقى مرتبطة بحسابك وحقوقك.',
                          style: const TextStyle(color: Colors.white70, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (owner) ...[
            const SizedBox(height: 10),
            ref.watch(platformVipRevenueSummaryProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('إيرادات خدمات VIP'),
                  subtitle: Text(
                    '${summary['points'] ?? 0} نقطة • ${summary['gems'] ?? 0} جوهرة • ${summary['orders'] ?? 0} عملية شراء',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final item in items) _serviceCard(item, owned, owner),
        ],
      ),
    );
  }


  Widget _serviceCard(
    ProfilePremiumServiceItem item,
    Map<String, ProfilePremiumOwnedService> owned,
    bool owner,
  ) {
    final ownedItem = owned[item.key];
    final active = ownedItem?.enabled == true || owner;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Icon(_icon(item.iconKey))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nameAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.descriptionAr,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  active ? Icons.verified : Icons.lock_outline,
                  color: active ? Colors.greenAccent : Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${item.pricePoints} نقطة • ${item.priceGems} جوهرة',
              style: const TextStyle(fontSize: 12),
            ),
            if (ownedItem != null && ownedItem.fromMembership && !owner)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'ضمن عضويتك — تتوقف عند انتهاء العضوية',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (owner && !item.isActive)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'غير متاحة للشراء للأعضاء حالياً',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  onPressed: (!item.isActive && !owner) ? null : () => _purchase(item),
                  child: Text(active
                      ? 'فتح الخدمة'
                      : (ownedItem != null ? 'مُتوقفة — فتح لإعادة التفعيل' : 'شراء')),
                ),
                if (owner)
                  OutlinedButton.icon(
                    onPressed: () => _editPrice(item),
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('السعر'),
                  ),
                if (owner)
                  OutlinedButton.icon(
                    onPressed: () => showAdminGiftDialog(
                      context: context,
                      itemLabel: item.nameAr,
                      onConfirmGift: (userId, requestId) async {
                        await Supabase.instance.client.rpc('admin_force_user_profile_service', params: {
                          'p_user_id': userId, 'p_feature_key': item.key, 'p_request_id': requestId,
                        });
                      },
                    ),
                    icon: const Icon(Icons.card_giftcard, size: 18, color: Colors.amberAccent),
                    label: const Text('إهداء'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String key) {
    switch (key) {
      case 'visibility': return Icons.visibility;
      case 'verified': return Icons.verified;
      case 'login': return Icons.login_rounded;
      case 'visibility_off': return Icons.visibility_off;
      case 'music_note': return Icons.music_note;
      case 'person_off': return Icons.person_off;
      case 'share': return Icons.share;
      case 'photo_library': return Icons.photo_library;
      case 'video_call': return Icons.video_call;
      case 'storefront': return Icons.storefront;
      case 'campaign': return Icons.campaign;
      case 'poll': return Icons.poll;
      case 'timer_off': return Icons.timer_off;
      case 'grid_4x4': return Icons.grid_4x4;
      case 'calculate': return Icons.calculate;
      case 'palette': return Icons.palette;
      case 'badge_outlined': return Icons.badge_outlined;
      case 'highlight': return Icons.highlight;
      case 'notifications_active': return Icons.notifications_active;
      case 'contact_page': return Icons.contact_page;
      case 'qr_code_2': return Icons.qr_code_2;
      case 'manage_search': return Icons.manage_search;
      case 'gradient': return Icons.gradient;
      case 'flare': return Icons.flare;
      case 'priority_high': return Icons.priority_high;
      case 'alternate_email': return Icons.alternate_email;
      case 'link': return Icons.link;
      case 'perm_media': return Icons.perm_media;
      case 'star': return Icons.star;
      case 'online_prediction': return Icons.online_prediction;
      case 'notifications_off': return Icons.notifications_off;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'analytics': return Icons.analytics;
      case 'content_cut': return Icons.content_cut;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'profile_visitors': return Icons.visibility;
      case 'account_verification': return Icons.verified;
      case 'hide_join_announcement': return Icons.login_rounded;
      case 'hide_profile': return Icons.visibility_off;
      case 'profile_music': return Icons.music_note;
      case 'anonymous_chat': return Icons.person_off;
      case 'social_links': return Icons.share;
      case 'profile_products': return Icons.photo_library;
      case 'voice_video_calls': return Icons.video_call;
      case 'profile_mini_store': return Icons.storefront;
      case 'profile_targeted_ads': return Icons.campaign;
      case 'advanced_profile_polls': return Icons.poll;
      case 'achievement_badges': return Icons.workspace_premium;
      case 'self_destruct_chat': return Icons.timer_off;
      case 'pattern_sharing': return Icons.grid_4x4;
      case 'production_cost_calculator': return Icons.calculate;
      case 'profile_theme_plus': return Icons.palette;
      case 'profile_card_plus': return Icons.badge_outlined;
      case 'profile_highlight': return Icons.highlight;
      case 'profile_visitor_alerts': return Icons.notifications_active;
      case 'profile_contact_button': return Icons.contact_page;
      case 'profile_qr_card': return Icons.qr_code_2;
      case 'profile_custom_badge': return Icons.workspace_premium;
      case 'profile_priority_search': return Icons.manage_search;
      case 'chat_name_gradient': return Icons.gradient;
      case 'chat_message_glow': return Icons.flare;
      case 'chat_priority_badge': return Icons.priority_high;
      case 'chat_mention_highlight': return Icons.alternate_email;
      case 'chat_link_preview_plus': return Icons.link;
      case 'chat_media_plus': return Icons.perm_media;
      case 'chat_favorites_plus': return Icons.star;
      case 'chat_presence_plus': return Icons.online_prediction;
      case 'chat_smart_mute': return Icons.notifications_off;
      case 'creator_tip_button': return Icons.volunteer_activism;
      case 'profile_analytics_plus': return Icons.analytics;
      case 'tailor_pattern_highlight': return Icons.content_cut;
      default: return Icons.auto_awesome;
    }
  }
}
