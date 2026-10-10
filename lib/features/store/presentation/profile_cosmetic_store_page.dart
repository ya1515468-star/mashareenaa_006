// ignore_for_file: prefer_const_constructors
import 'currency_store/currency_store_tab.dart';
import '../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/gif_inspector.dart';
import '../../../core/di/injection_container.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../gamification/domain/entities/username_effect.dart';
import '../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../gamification/presentation/widgets/username_effect_text.dart';
import '../../gamification/domain/entities/name_animation.dart';
import '../../gamification/data/name_animation_upload_service.dart';
import '../../gamification/presentation/providers/name_animation_providers.dart';
import '../../gamification/presentation/widgets/name_animation_widget.dart';
import '../../gamification/presentation/widgets/username_cosmetic_name.dart';
import '../../../core/widgets/dynamic_avatar_frame.dart';
import '../../../core/widgets/avatar_frame_compositor.dart';
import '../../admin/presentation/widgets/admin_gift_dialog.dart';
import 'providers/chat_store_sections_provider.dart';
import '../domain/chat_store_section_icons.dart';
import 'widgets/chat_store_sections_settings_dialog.dart';
import 'widgets/name_background_picker_dialog.dart';
import '../../subscriptions/presentation/widgets/membership_store_tab.dart';
import '../../../core/widgets/avatar_frame_metrics.dart';
import '../../profile/presentation/widgets/account_setting_tiles.dart';
import '../../../core/widgets/frame_effect_catalog.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../domain/equipped_items_service.dart';
import '../domain/usecases/store_usecases.dart';
import 'store_features_tab.dart' show storeCatalogProvider, storeOwnedItemsProvider;
import '../domain/entities/store_item_entity.dart';
import 'widgets/store_effect_engines.dart' show StoreAvatarFrame;
import '../../profile/presentation/widgets/avatar_frame_catalog.dart';
import '../../profile/presentation/widgets/name_template.dart';
import '../data/services/avatar_frame_upload_service.dart';
import 'profile_premium_services_tab.dart';

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFEFEFEF);
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()).isEven;
        if (even) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}

class ProfileCosmeticItem {
  final String key; final String category; final String gender; final String nameAr;
  final String animationMode; final String palette; final String modeVariant;
  final String color1; final String? color2; final int pricePoints; final int priceGems;
  final Map<String,dynamic> metadata; final bool isActive; final int sortOrder;
  const ProfileCosmeticItem({required this.key,required this.category,required this.gender,required this.nameAr,required this.animationMode,required this.palette,required this.modeVariant,required this.color1,required this.color2,required this.pricePoints,required this.priceGems,required this.metadata,required this.isActive,required this.sortOrder});
  factory ProfileCosmeticItem.fromMap(Map<String,dynamic> m)=>ProfileCosmeticItem(
    key:(m['item_key']?.toString() ?? '').trim(),
    category:(m['category']?.toString() ?? '').trim(),
    gender:(m['gender']?.toString() ?? 'unisex').trim(),
    nameAr:(m['name_ar']?.toString() ?? 'عنصر').trim(),
    animationMode:(m['animation_mode']?.toString() ?? 'none').trim(),
    palette:(m['palette_key']?.toString() ?? 'default').trim(),
    modeVariant:(m['mode_variant']?.toString() ?? 'default').trim(),
    color1:(m['color1']?.toString() ?? '#FFFFFF').trim(),
    color2:m['color2']?.toString(),
    pricePoints:(m['price_points'] as num?)?.toInt() ?? 0,
    priceGems:(m['price_gems'] as num?)?.toInt() ?? 0,
    metadata:m['metadata'] is Map? Map<String,dynamic>.from(m['metadata'] as Map):<String,dynamic>{},
    isActive:m['is_active'] != false, sortOrder:(m['sort_order'] as num?)?.toInt() ?? 0);
}

final profileCosmeticCatalogProvider = FutureProvider<List<ProfileCosmeticItem>>((ref) async {
  final sb=Supabase.instance.client;
  final rows=await sb.rpc('get_profile_cosmetic_catalog',params:{});
  return List<Map<String,dynamic>>.from(rows as List).map(ProfileCosmeticItem.fromMap).toList(growable:false);
});

final nameTemplateCatalogProvider = FutureProvider<List<ProfileCosmeticItem>>((ref) async {
  final sb = Supabase.instance.client;
  final rows = await sb.rpc('get_profile_cosmetic_catalog', params: {});
  return List<Map<String, dynamic>>.from(rows as List)
      .map(ProfileCosmeticItem.fromMap)
      .where((item) => item.category == 'name_template' && NameTemplateRegistry.get(item.key) != null)
      .toList(growable: false);
});

final chatStoreOwnerProvider = FutureProvider<bool>((ref) async {
  try { return await Supabase.instance.client.rpc('is_my_platform_owner') == true; } catch (_) { return false; }
});

final serverAvatarFramesProvider = FutureProvider<List<AvatarFrameDefinition>>((ref) async {
  final raw = await Supabase.instance.client.rpc('get_avatar_frame_catalog');
  final rows = raw is List ? raw : const <dynamic>[];
  return rows
      .whereType<Map>()
      .map((row) => AvatarFrameDefinition.fromMap(Map<String, dynamic>.from(row)))
      .where((frame) => frame.key.isNotEmpty && frame.assetUrl != null)
      .toList(growable: false);
});


final messageColorCatalogProvider = FutureProvider<List<ProfileCosmeticItem>>((ref) async {
  final raw = await Supabase.instance.client.rpc('get_message_color_catalog');
  final rows = raw is List ? raw : const <dynamic>[];
  return rows.whereType<Map>().map((m) => ProfileCosmeticItem.fromMap(Map<String,dynamic>.from(m))).toList(growable:false);
});

class MessageColorSwatch extends StatelessWidget {
  final ProfileCosmeticItem item;
  const MessageColorSwatch({super.key, required this.item});
  Color _c(String? v) {
    final s=(v??'').replaceAll('#','').trim();
    final n=int.tryParse('FF$s',radix:16);
    return n==null?const Color(0xFF94A3B8):Color(n);
  }
  @override Widget build(BuildContext context) {
    final c1=_c(item.color1); final c2=item.color2==null?null:_c(item.color2);
    // مربّعات بدل الدوائر (بطلب صريح)، مع إظهار التدرّج الحقيقي للألوان
    // المدمجة وتوهّج نيون خفيف بلون العيّنة نفسها يجعل الألوان الزاهية
    // تُقرأ كنيون فعلًا. كل قيمة هنا من كتالوج الألوان الخادمي حصرًا.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: c2 == null ? null : LinearGradient(colors: [c1, c2]),
        color: c2 == null ? c1 : null,
        border: Border.all(color: Colors.white.withValues(alpha: .22), width: 1),
        boxShadow: [
          BoxShadow(color: c1.withValues(alpha: .55), blurRadius: 12, spreadRadius: 0.5),
          if (c2 != null)
            BoxShadow(color: c2.withValues(alpha: .45), blurRadius: 14, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

class ProfileCosmeticStorePage extends ConsumerStatefulWidget {
  const ProfileCosmeticStorePage({super.key});
  @override ConsumerState<ProfileCosmeticStorePage> createState()=>_ProfileCosmeticStorePageState();
}

class _ProfileCosmeticStorePageState extends ConsumerState<ProfileCosmeticStorePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs=TabController(length:12,vsync:this);
  bool _frameUploadBusy = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() { if (mounted) setState(() {}); });
  }

  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<bool> _confirmStoreAction({
    required String title,
    required String action,
    required String itemName,
    String? detail,
  }) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(detail ?? 'هل تريد $action «$itemName»؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
            ],
          ),
        ) ?? false;
  }

  Future<void> _buyOrEquip(ProfileCosmeticItem item) async {
    final owned=ref.read(myProfileCosmeticOwnershipProvider).valueOrNull?.contains(item.key)==true;
    final owner=ref.read(chatStoreOwnerProvider).valueOrNull==true;
    final free = item.pricePoints == 0 && item.priceGems == 0;
    if (owned || owner || free) {
      final ok = await _confirmStoreAction(title: 'تأكيد التفعيل', action: 'تفعيل', itemName: item.nameAr, detail: 'سيتم تفعيل «${item.nameAr}» وحفظه على الخادم الآن. هل تريد المتابعة؟');
      if (!ok) return;
    }
    if (!owned && !owner && !free) {
      if (!mounted) return;
      final currency=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[const SizedBox(height:12),const Text('اختر طريقة الشراء', style: TextStyle(fontSize:18,fontWeight:FontWeight.w900)),if(item.pricePoints>0||item.priceGems<=0)ListTile(leading:const Icon(Icons.star,color:Colors.amber),title:Text('${item.pricePoints} نقطة'),onTap:()=>Navigator.pop(c,'points')),if(item.priceGems>0||item.pricePoints<=0)ListTile(leading:const Icon(Icons.diamond,color:Colors.cyan),title:Text('${item.priceGems} جوهرة'),onTap:()=>Navigator.pop(c,'gems')),const SizedBox(height:12)])));
      if (currency == null) { return; }
      if (!mounted) return;
      final priceText = currency == 'points' ? '${item.pricePoints} نقطة' : '${item.priceGems} جوهرة';
      final ok = await _confirmStoreAction(title: 'تأكيد الشراء', action: 'شراء', itemName: item.nameAr, detail: 'سيتم خصم $priceText من رصيدك وشراء «${item.nameAr}». هل تريد المتابعة؟');
      if (!ok) return;
      try { await Supabase.instance.client.rpc('purchase_profile_cosmetic',params:{'p_item_key':item.key,'p_currency':currency,'p_request_id': const Uuid().v4()}); } catch(e){ if (!mounted) return; ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e)))); return; }
      ref.invalidate(myProfileCosmeticOwnershipProvider);
    }
    try {
      if (item.category == 'frame') { await Supabase.instance.client.rpc('set_avatar_frame',params:{'p_frame_key':item.key});
      } else if (item.category == 'background') {
        final params = <String, dynamic>{'p_background_key': item.key};
        if (item.metadata['user_customizable'] == true) {
          if (!mounted) return;
          final c1 = await showColorSwatchPicker(context, 'اختر اللون الأول');
          if (c1 == null) return;
          if (!mounted) return;
          final c2 = await showColorSwatchPicker(context, 'اختر اللون الثاني');
          if (c2 == null) return;
          params['p_custom_color1'] = '#${c1.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          params['p_custom_color2'] = '#${c2.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
        }
        await Supabase.instance.client.rpc('set_username_background', params: params);
      } else if (item.category == 'message_color') { await Supabase.instance.client.rpc('set_my_message_color',params:{'p_item_key':item.key});
      } else if (item.category == 'name_template') { final key=item.key.trim(); if (NameTemplateRegistry.get(key)==null) throw StateError('INVALID_NAME_TEMPLATE'); await Supabase.instance.client.rpc('set_username_template',params:{'p_template_key':key});
      } else { final effect=item.metadata['effect_key']?.toString(); if(effect==null||effect.isEmpty) throw StateError('INVALID_EFFECT'); await Supabase.instance.client.rpc('set_username_effect',params:{'p_effect':effect}); }
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(nameTemplateCatalogProvider);
      // serverUserIdentityProvider هو .family — إبطاله بلا مُعامل
      // (uid) لا يُبطل أي نسخة فعلية منه في Riverpod، فتبقى الهوية
      // المخزَّنة مؤقتًا قديمة رغم نجاح الحفظ على الخادم تمامًا. هذا
      // بالضبط سبب "تم التنفيذ لكن اللون لا يتغيّر" — يظهر فقط بعد
      // إعادة فتح الشاشة لأن ذلك يُنشئ نسخة جديدة من المزوّد من الصفر.
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        ref.invalidate(serverUserIdentityProvider(uid));
        ref.invalidate(profileByIdProvider(uid));
        ref.invalidate(currentProfileProvider);
      }
      // serverUserIdentityInRoomProvider مفهرَس بـ(uid, roomId) معًا؛
      // roomId الحالية غير معروفة داخل شاشة المتجر، فلا سبيل لإبطال
      // نسخة بعينها هنا. لكنه autoDispose أصلًا: يُهدَم فور إغلاق
      // شاشة الشات ويُعاد جلبه من الصفر عند فتحها مجددًا، فلا يبقى
      // بيانات قديمة معلَّقة لأكثر من الجلسة الحالية للغرفة المفتوحة.
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم الحفظ وتحديث البروفايل')));
    } catch(e){ if (!mounted) return; ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e)))); }
  }

  /// Every "⋮" owner menu on the store cards (cosmetics/frames/name
  /// animations) opens its edit/gift/delete dialog from
  /// `PopupMenuButton.onSelected`. Confirmed live via the browser console:
  /// pushing a dialog route synchronously from that callback can race the
  /// popup menu's own route-removal animation and trip a Flutter engine
  /// MouseTracker re-entrancy assertion (`mouse_tracker.dart`,
  /// `!_debugDuringDeviceUpdate` — flutter/flutter#66887, #70375, #96364)
  /// that hangs the tab. It's timing-dependent rather than 100% reproducible
  /// per click, so every dialog opened from these menus goes through this
  /// helper, which waits out the popup's own close-transition duration
  /// (300ms — `_kMenuDuration` in Flutter's popup_menu.dart) first.
  Future<T?> _showOwnerMenuDialog<T>(WidgetBuilder builder) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return null;
    return showDialog<T>(context: context, builder: builder);
  }

  /// Comprehensive edit (name/price/active/sort) for any profile_cosmetic
  /// catalog item — backgrounds, name effects, message colors, name
  /// templates, and frames all share this one dialog and one RPC.
  Future<void> _editProfileCosmeticFull(ProfileCosmeticItem item) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    final name = TextEditingController(text: item.nameAr);
    final points = TextEditingController(text: item.pricePoints.toString());
    final gems = TextEditingController(text: item.priceGems.toString());
    final order = TextEditingController(text: item.sortOrder.toString());
    var isActive = item.isActive;
    try {
      final ok = await _showOwnerMenuDialog<bool>(
        (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
          title: Text('تعديل ${item.nameAr}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            Row(children: [
              Expanded(child: TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الجواهر'))),
            ]),
            TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
            SwitchListTile(value: isActive, onChanged: (v) => setD(() => isActive = v), title: const Text('مُفعَّل في المتجر'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))],
        )),
      );
      if (ok != true || !mounted) return;
      final p = int.tryParse(points.text.trim());
      final g = int.tryParse(gems.text.trim());
      final o = int.tryParse(order.text.trim());
      if (p == null || g == null || p < 0 || g < 0) throw StateError('INVALID_PRICE');
      if (o == null || o < 0) throw StateError('INVALID_SORT_ORDER');
      if (name.text.trim().isEmpty) throw StateError('NAME_REQUIRED');
      await Supabase.instance.client.rpc('admin_update_profile_cosmetic', params: {
        'p_item_key': item.key, 'p_name_ar': name.text.trim(), 'p_price_points': p, 'p_price_gems': g,
        'p_is_active': isActive, 'p_sort_order': o, 'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(nameTemplateCatalogProvider);
      ref.invalidate(messageColorCatalogProvider);
      ref.invalidate(serverAvatarFramesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تم حفظ التعديلات ✓'), backgroundColor: Colors.green.shade700));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    } finally {
      name.dispose(); points.dispose(); gems.dispose(); order.dispose();
    }
  }

  /// Hard delete for a shared profile_cosmetic_catalog item. Frame-category
  /// items are refused server-side (they need admin_delete_avatar_frame's
  /// extra cleanup of avatar_frame_catalog), so frame cards call the
  /// existing dedicated _deleteRemoteFrame instead of this.
  Future<void> _deleteProfileCosmetic(ProfileCosmeticItem item) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    final ok = await _showOwnerMenuDialog<bool>(
      (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('سيتم حذف «${item.nameAr}» نهائيًا من الكتالوج ومن كل حساب يملكه. هذا الإجراء لا يمكن التراجع عنه. هل تريد المتابعة؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () => Navigator.pop(c, true), child: const Text('حذف نهائيًا'))],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Supabase.instance.client.rpc('admin_delete_profile_cosmetic', params: {'p_item_key': item.key, 'p_request_id': const Uuid().v4()});
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(nameTemplateCatalogProvider);
      ref.invalidate(messageColorCatalogProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تم حذف «${item.nameAr}» نهائيًا ✓'), backgroundColor: Colors.green.shade700));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  /// Gift any profile_cosmetic item (frame / background / name effect /
  /// message color / name template) to a user found by name or ID.
  Future<void> _giftProfileCosmetic(String itemKey, String nameAr) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    await showAdminGiftDialog(
      context: context,
      itemLabel: nameAr,
      onConfirmGift: (userId, requestId) async {
        await Supabase.instance.client.rpc('admin_force_user_profile_cosmetic', params: {
          'p_user_id': userId, 'p_item_key': itemKey, 'p_request_id': requestId,
        });
      },
    );
  }

  /// Compact corner menu (edit/gift/delete) shared by the backgrounds,
  /// name-effects, message-colors and name-templates cards — one
  /// PopupMenuButton instead of several tiny adjacent IconButtons, which is
  /// what triggers MouseTracker hit-test assertions on desktop/web.
  Widget _profileCosmeticOwnerMenu(ProfileCosmeticItem item) {
    return PopupMenuButton<String>(
      tooltip: 'خيارات الإدارة',
      padding: EdgeInsets.zero,
      iconSize: 16,
      splashRadius: 16,
      icon: const Icon(Icons.more_vert, size: 16),
      onSelected: (v) {
        switch (v) {
          case 'edit': _editProfileCosmeticFull(item); break;
          case 'gift': _giftProfileCosmetic(item.key, item.nameAr); break;
          case 'delete': _deleteProfileCosmetic(item); break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('تعديل شامل')])),
        PopupMenuItem(value: 'gift', child: Row(children: [Icon(Icons.card_giftcard, size: 16, color: Colors.amberAccent), SizedBox(width: 8), Text('إهداء لمستخدم')])),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('حذف نهائي')])),
      ],
    );
  }

  /// Canonical error mapper for the whole cosmetic store (frames, templates,
  /// username effects AND name animations). The real exception is always
  /// logged first so a developer can find the true root cause; the message
  /// shown to the user is chosen from a specific, known error code instead of
  /// a generic connection message. Only a genuinely detected network failure
  /// is ever reported as a connection problem.
  String _friendly(Object e) {
    final s = e.toString();
    // Full internal logging BEFORE any user-facing mapping happens.
    debugPrint('COSMETIC_STORE_ERROR: $s');

    // Ownership / availability -------------------------------------------------
    if (s.contains('ANIMATION_NOT_OWNED')) return 'الحيوان غير مملوك.';
    if (s.contains('ANIMATION_NOT_TRANSPARENT')) return 'هذا الحيوان غير مهيأ للعرض فوق الاسم حاليًا.';
    if (s.contains('ANIMATION_NOT_AVAILABLE')) return 'الحيوان غير متاح حاليًا.';
    if (s.contains('ANIMATION_NOT_FOUND')) return 'الحيوان غير موجود في الكتالوج.';
    if (s.contains('ITEM_NOT_OWNED')) return 'العنصر غير مملوك.';
    if (s.contains('EFFECT_NOT_AVAILABLE')) return 'المؤثر غير متاح حاليًا.';
    if (s.contains('PLACEMENT_NOT_ALLOWED')) return 'مكان التطبيق غير مسموح لهذا المؤثر.';
    if (s.contains('INVALID_NAME_TEMPLATE')) return 'قالب الاسم غير معروف أو غير مسجل.';

    // Currency / balance / pricing ---------------------------------------------
    if (s.contains('INVALID_CURRENCY')) return 'طريقة الدفع غير صالحة.';
    if (s.contains('INSUFFICIENT_POINTS')) return 'رصيد النقاط غير كافٍ.';
    if (s.contains('INSUFFICIENT_GEMS')) return 'رصيد الجواهر غير كافٍ.';
    if (s.contains('PRICE_NOT_SET')) return 'السعر غير مضبوط لهذا العنصر بعد.';
    if (s.contains('INVALID_PRICE')) return 'السعر المُدخل غير صالح.';

    // Auth / permission ----------------------------------------------------------
    if (s.contains('SESSION_EXPIRED')) return 'انتهت الجلسة أثناء تنفيذ العملية. سجّل الدخول ثم أعد المحاولة.';
    if (s.contains('AUTH_REQUIRED') || s.contains('INVALID_SESSION')) return 'انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.';
    if (s.contains('OWNER_REQUIRED') || s.contains('OWNER_CHECK_FAILED')) return 'لا تملك صلاحية المالك اللازمة لتنفيذ هذه العملية.';
    if (s.contains('FORBIDDEN')) return 'لا تملك صلاحية تنفيذ هذه العملية.';
    if (s.contains('USER_NOT_FOUND')) return 'المستخدم غير موجود.';
    if (s.contains('USER_ID_REQUIRED')) return 'معرّف المستخدم مطلوب.';

    // Idempotency / request shape --------------------------------------------
    if (s.contains('REQUEST_ID_REPLAY_FORBIDDEN')) return 'تم رصد تكرار غير متطابق لعملية سابقة. أعد المحاولة من جديد.';
    if (s.contains('REQUEST_ID_REQUIRED')) return 'تعذر تجهيز معرّف العملية. أعد المحاولة.';
    if (s.contains('METHOD_NOT_ALLOWED')) return 'طريقة الطلب غير مدعومة من الخادم.';
    if (s.contains('SERVER_CONFIGURATION_ERROR')) return 'خطأ في إعدادات الخادم. تم تسجيل التفاصيل لفريق التطوير.';

    // GIF validation (client + server share these exact codes) ---------------
    if (s.contains('GIF_TOO_COMPLEX')) return 'ملف GIF كبير/ثقيل جدًا للمعالجة الآمنة على الجهاز. قلّل عدد الإطارات أو الأبعاد ثم أعد الرفع.';
    if (s.contains('GIF_DECODED_TOO_LARGE')) return 'أبعاد أو عدد إطارات GIF تجعل حجمه بعد فك الضغط أكبر من المسموح.';
    if (s.contains('GIF_TRUNCATED')) return 'ملف GIF غير مكتمل أو تالف.';
    if (s.contains('GIF_TOO_MANY_FRAMES') || s.contains('INVALID_FRAME_COUNT')) return 'عدد إطارات الحيوان كبير جدًا.';
    if (s.contains('INVALID_GIF_DIMENSIONS')) return 'أبعاد GIF غير مدعومة.';
    if (s.contains('INVALID_ANIMATION_BOUNDS')) return 'أبعاد عرض الحيوان غير مدعومة.';
    if (s.contains('INVALID_ANIMATION_TIMING')) return 'مدة أو سرعة حركة GIF غير صالحة.';
    if (s.contains('INVALID_GIF')) return 'ملف الحيوان ليس GIF صالحًا أو الملف تالف.';
    if (s.contains('GIF_REQUIRED')) return 'يجب رفع ملف بصيغة GIF فقط.';
    if (s.contains('ANIMATION_EMPTY')) return 'الملف المختار فارغ.';
    if (s.contains('ANIMATION_TOO_LARGE')) return 'حجم الحيوان المتحرك أكبر من 8MB.';
    if (s.contains('INVALID_ASSET_URL')) return 'رابط الملف الناتج غير صالح.';
    if (s.contains('INVALID_STORAGE_PATH')) return 'مسار التخزين الناتج غير صالح.';
    if (s.contains('INVALID_SIZE')) return 'حجم الملف غير صالح.';
    if (s.contains('INVALID_EFFECT_KEY')) return 'معرّف الحيوان غير صالح.';
    if (s.contains('INVALID_SORT_ORDER')) return 'قيمة الترتيب غير صالحة.';
    if (s.contains('INVALID_RENDER_EFFECT')) return 'نوع التأثير الحركي غير معروف.';
    if (s.contains('NAME_REQUIRED')) return 'اسم العنصر مطلوب.';
    if (s.contains('ANIMATION_CATALOG_CREATE_FAILED')) return 'تم رفع الملف لكن تعذر ربطه بكتالوج الحيوانات.';

    // Storage / Database / server-side failures -------------------------------
    if (s.contains('STORAGE_UPLOAD_FAILED')) return 'فشل رفع الملف إلى التخزين. تم تسجيل تفاصيل الخطأ.';
    if (s.contains('STORAGE')) return 'تعذر الوصول إلى التخزين الآن. تم تسجيل تفاصيل الخطأ.';
    if (s.contains('DATABASE_WRITE_FAILED')) return 'تعذر حفظ بيانات العنصر في قاعدة البيانات. تم تسجيل تفاصيل الخطأ.';
    if (s.contains('UPLOAD_VALIDATION_FAILED')) return 'الملف لم يجتز فحص الخادم.';
    if (s.contains('SERVER_ERROR')) return 'حدث خطأ داخل الخادم وتم تسجيل السبب الحقيقي.';

    // Real, detected network failures only — never assumed by default.
    final lower = s.toLowerCase();
    final looksLikeNetwork = s.contains('NETWORK_ERROR') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('timeoutexception');
    if (looksLikeNetwork) return 'تعذر الاتصال بالخادم. تحقق من الشبكة ثم أعد المحاولة.';

    // Unknown: never blame the network without evidence. The real cause is
    // already logged above via debugPrint for the developer to trace.
    return 'تعذر تنفيذ العملية. تم تسجيل تفاصيل الخطأ الحقيقية لفريق التطوير.';
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(chatStoreOwnerProvider).valueOrNull == true;
    final sections = ref.watch(chatStoreSectionsProvider).valueOrNull ?? const {};
    ChatStoreSection sectionFor(String key, String fallbackName, String fallbackIcon, int order) =>
        sections[key] ?? ChatStoreSection.fallback(key, fallbackName, fallbackIcon, order);
    final ordered = [
      sectionFor('frames', 'الإطارات', 'photo_camera_back', 0),
      sectionFor('colored_frames', 'إطارات ملونة', 'palette', 1),
      sectionFor('name_background', 'خلفية إطار الاسم', 'wallpaper', 2),
      sectionFor('username_effects', 'تأثيرات اسم المستخدم', 'auto_awesome', 3),
      sectionFor('live_name', 'اسمك', 'badge', 4),
      sectionFor('message_colors', 'ألوان الرسائل', 'color_lens', 5),
      sectionFor('vip_services', 'خدمات VIP', 'workspace_premium', 6),
      sectionFor('name_templates', 'قالب الاسم', 'style', 7),
      sectionFor('name_animals', 'حيوانات فوق الاسم', 'pets', 8),
      sectionFor('memberships', 'العضويات', 'workspace_premium', 9),
      sectionFor('currency', 'النقاط والجواهر', 'monetization_on', 10),
      sectionFor('role_colors', 'تلوين الرتبة', 'military_tech', 11),
    ];
    final currentBg = ordered[_tabs.index.clamp(0, ordered.length - 1)].backgroundImageUrl;
    return Scaffold(
      appBar: AppBar(
        title: const Text('متجر الشات'),
        actions: [
          if (owner)
            IconButton(
              tooltip: 'تخصيص الأقسام',
              icon: const Icon(Icons.tune),
              onPressed: () => showChatStoreSectionsSettingsDialog(context: context, sectionsInOrder: ordered, onSaved: () => ref.invalidate(chatStoreSectionsProvider)),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final s in ordered) Tab(icon: Icon(resolveChatStoreSectionIcon(s.iconName), size: 18), text: s.nameAr)],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: (currentBg == null || currentBg.isEmpty)
                  ? null
                  : BoxDecoration(image: DecorationImage(image: NetworkImage(currentBg), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken))),
              child: TabBarView(
                controller: _tabs,
                children: [
                  _framesSection(owner),
                  _simpleColoredFramesSection(),
                  _nameBackgroundSection(owner),
                  _catalogGridSection(category: 'name_effect', owner: owner),
                  _liveNameSection(),
                  _messageColorsSection(owner),
                  const ProfilePremiumServicesTab(),
                  _nameTemplatesSection(owner),
                  _nameAnimalsSection(owner, displayMode: sectionFor('name_animals', '', '', 8).displayMode),
                  // Memberships now live inside the chat store alongside every
                  // other purchasable item, instead of only on a separate page.
                  const MembershipStoreTab(),
                  // متجر النقاط والجواهر: كان مبنيًّا وموصولًا بالخادم
                  // لكنه لم يُربط بأي واجهة، فتعذّر على أي مستخدم
                  // الوصول إليه. كشفه فحص الملفات اليتيمة.
                  const CurrencyStoreTab(),
                  const _RoleColorTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Background tab = the new colour picker (live preview + 4 colour tabs +
  /// manual 2-colour merge + empty interior) sitting above the existing
  /// purchasable catalogue grid, so both paths stay available.
  Widget _nameBackgroundSection(bool owner) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: () => showNameBackgroundPickerDialog(context),
              icon: const Icon(Icons.palette),
              label: const Text('تخصيص لون الخلفية'),
            ),
          ),
        ),
        Expanded(child: _catalogGridSection(category: 'background', owner: owner)),
      ],
    );
  }

  /// A free, always-available "بلا" tile shown first in every cosmetic
  /// section, so a user can switch a layer OFF again instead of being stuck
  /// with whatever they last picked. Each layer clears independently — the
  /// other three are untouched.
  Widget _noneCard({required bool selected, required VoidCallback onTap, String label = 'بلا'}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.amberAccent : Colors.white24,
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 30, color: selected ? Colors.amberAccent : Colors.white38),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.amberAccent : Colors.white70,
                  )),
              const SizedBox(height: 4),
              Text(selected ? 'مُطبَّق حاليًا' : 'إلغاء الاختيار',
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  /// Clears one cosmetic layer on the server. Each RPC already supports an
  /// empty/none value as "remove" (verified against the live functions), so
  /// nothing extra is needed server-side.
  Future<void> _clearLayer(String layer) async {
    try {
      final sb = Supabase.instance.client;
      switch (layer) {
        case 'background':
          await sb.rpc('set_username_background', params: {'p_background_key': ''});
          break;
        case 'name_effect':
          await sb.rpc('set_username_effect', params: {'p_effect': 'none'});
          break;
        case 'name_template':
          await sb.rpc('set_username_template', params: {'p_template_key': ''});
          break;
        case 'name_animal':
          await sb.rpc('set_name_animation', params: {'p_effect_key': ''});
          break;
      }
      ref.invalidate(currentProfileProvider);
      ref.invalidate(myProfileCosmeticOwnershipProvider);
      ref.invalidate(serverUserIdentityProvider);
      ref.invalidate(serverUserIdentityInRoomProvider);
      if (layer == 'name_animal') ref.invalidate(nameAnimationCatalogProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: const Text('تم الإلغاء ✓'), backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Widget _catalogGridSection({
    required String category,
    required bool owner,
  }) {
    final async = ref.watch(profileCosmeticCatalogProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'تعذر تحميل الكتالوج الآن. تحقق من الاتصال ثم أعد المحاولة.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (allItems) {
        final own = ref.watch(myProfileCosmeticOwnershipProvider).valueOrNull ??
            const <String>{};

        final items = allItems
            .where((item) => item.isActive)
            .where(
              (item) =>
                  item.category == category,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        if (items.isEmpty) {
          return Center(
            child: Text(
              category == 'background'
                  ? 'لا توجد خلفيات اسم متاحة حاليًا.'
                  : 'لا توجد مؤثرات اسم متاحة حاليًا.',
            ),
          );
        }

        final profile = ref.watch(currentProfileProvider).valueOrNull;
        final noneSelected = category == 'background'
            ? ((profile?.usernameBackgroundKey ?? '').trim().isEmpty)
            : ((profile?.usernameEffect ?? 'none').trim().isEmpty ||
                (profile?.usernameEffect ?? 'none').trim() == 'none');

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
          gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 175,
            mainAxisExtent: 188,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length + 1,
          itemBuilder: (context, rawIndex) {
            // Index 0 is always the free "بلا" tile.
            if (rawIndex == 0) {
              return _noneCard(
                selected: noneSelected,
                onTap: () => _clearLayer(category),
              );
            }
            final index = rawIndex - 1;
            final item = items[index];

            final owned = owner ||
                own.contains(item.key) ||
                (item.pricePoints == 0 && item.priceGems == 0);

            return Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  InkWell(
                onTap: () => _buyOrEquip(item),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 66,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150, maxHeight: 68),
                            child: _preview(item),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.nameAr.isEmpty ? item.key : item.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (owned)
                        const Text(
                          'متاح ✓',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        Text(
                          item.pricePoints > 0 && item.priceGems > 0
                              ? '${item.pricePoints} نقطة • ${item.priceGems} جوهرة'
                              : item.pricePoints > 0
                                  ? '${item.pricePoints} نقطة'
                                  : item.priceGems > 0
                                      ? '${item.priceGems} جوهرة'
                                      : 'مجاني',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                  ),
                  if (owner) Positioned(top: 0, left: 0, child: _profileCosmeticOwnerMenu(item)),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Widget _messageColorsSection(bool owner) {
    final async = ref.watch(messageColorCatalogProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('تعذر تحميل ألوان الرسائل: $error')),
      data: (items) {
        final free = items.where((e) => e.metadata['tier'] == 'free' || e.pricePoints == 0 && e.priceGems == 0).toList();
        final premium = items.where((e) => e.metadata['tier'] == 'premium' || e.pricePoints > 0 || e.priceGems > 0).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            // الخادم set_my_message_style جاهز منذ إضافته لتنسيق الرسائل
            // (غامق/مائل) لكنه كان بلا أي واجهة تصل إليه إطلاقًا.
            const _MessageTextStyleSection(),
            const SizedBox(height: 18),
            _messageColorSectionTitle('ألوان المبتدئين — مجانية', Icons.palette_outlined, ''),
            _messageColorGrid(free, owner),
            const SizedBox(height: 18),
            _messageColorSectionTitle('الألوان المتميزة', Icons.workspace_premium, ''),
            _messageColorGrid(premium, owner),
          ],
        );
      },
    );
  }

  Widget _messageColorSectionTitle(String title, IconData icon, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Icon(icon, size: 22), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white60))]))]),
  );

  Widget _messageColorGrid(List<ProfileCosmeticItem> items, bool owner) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد ألوان حاليًا'));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, childAspectRatio: 2.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (_, index) {
        final item = items[index];
        final owned = owner || ref.watch(myProfileCosmeticOwnershipProvider).valueOrNull?.contains(item.key) == true || item.pricePoints == 0 && item.priceGems == 0;
        return Card(
          child: InkWell(
            onTap: () => _buyOrEquip(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                MessageColorSwatch(item: item),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item.nameAr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(item.pricePoints == 0 && item.priceGems == 0 ? 'مجاني' : '${item.pricePoints} نقطة • ${item.priceGems} جوهرة', style: const TextStyle(fontSize: 9, color: Colors.white60)),
                ])),
                if (owner) _profileCosmeticOwnerMenu(item),
                Icon(owned ? Icons.check_circle : Icons.lock_outline, size: 18),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _simpleColoredFramesSection() {
    final catalog = ref.watch(storeCatalogProvider).valueOrNull ?? const <StoreItemEntity>[];
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final owned = uid == null
        ? const <String>[]
        : ref.watch(storeOwnedItemsProvider(uid)).valueOrNull ?? const <String>[];
    final items = catalog
        .where((item) => item.enabled && item.sku.toLowerCase().startsWith('simple-frame-'))
        .toList(growable: false);

    if (items.isEmpty) {
      return const Center(child: Text('لا توجد إطارات ملونة متاحة حاليًا.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 166,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        final isOwned = uid != null && owned.contains(item.id);
        final price = item.pricePoints;
        final frame = StoreAvatarFrame(
          colors: item.colors,
          padding: 3,
          child: const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF22212B),
            child: Icon(Icons.person, color: Colors.white54, size: 22),
          ),
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 62, height: 62, child: FittedBox(child: frame)),
                Text(item.nameAr, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                Text(price <= 0 ? 'مجاني' : '$price نقطة',
                    style: const TextStyle(fontSize: 9, color: Colors.white60)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: uid == null
                        ? null
                        : () async {
                            if (isOwned) {
                              final confirmed = await _confirmStoreAction(
                                title: 'تأكيد التفعيل',
                                action: 'تفعيل',
                                itemName: item.nameAr,
                                detail: 'سيتم تفعيل الإطار «${item.nameAr}» وحفظه على الخادم. هل تريد المتابعة؟',
                              );
                              if (!confirmed) return;
                              await EquippedItemsService.equip(uid: uid, category: item.category, itemId: item.id);
                              ref.invalidate(currentProfileProvider);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم تفعيل الإطار الملون ✓')));
                            } else {
                              final confirmed = await _confirmStoreAction(
                                title: 'تأكيد الشراء',
                                action: 'شراء',
                                itemName: item.nameAr,
                                detail: 'سيتم شراء «${item.nameAr}» مقابل $price نقطة وحفظ الملكية على الخادم. هل تريد المتابعة؟',
                              );
                              if (!confirmed) return;
                              final result = await sl<PurchaseStoreItemUseCase>().call(uid: uid, item: item);
                              result.fold(
                                (failure) { if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(failure.message))); },
                                (_) { ref.invalidate(storeOwnedItemsProvider(uid)); if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم شراء الإطار الملون ✓'))); },
                              );
                            }
                          },
                    child: Text(isOwned ? 'تفعيل' : 'شراء'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _framesSection(bool owner) {
    final async = ref.watch(serverAvatarFramesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('تعذر تحميل إطارات الصور من الخادم: $error'),
        ),
      ),
      data: (frames) {
        return Stack(
          children: [
            if (frames.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.crop_square_rounded,
                        size: 58,
                        color: Colors.white30,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'قسم الإطارات فارغ حاليًا',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'لا توجد إطارات حاليًا',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 90),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 185,
                  mainAxisExtent: 168,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: frames.length,
                itemBuilder: (_, index) {
                  final frame = frames[index];
                  return _remoteFrameCard(frame, owner);
                },
              ),
            if (owner)
              Positioned(
                left: 16,
                bottom: 18,
                child: FloatingActionButton.extended(
                  heroTag: 'add_remote_avatar_frame',
                  onPressed: _showAddFrameDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة إطار'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _remoteFrameCard(AvatarFrameDefinition frame, bool owner) {
    final owned = owner ||
        (ref.watch(myProfileCosmeticOwnershipProvider).valueOrNull?.contains(frame.key) == true);
    final current = ref.watch(currentProfileProvider).valueOrNull?.avatarFrameKey == frame.key;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: 48,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DynamicAvatarFrame(
                    frameKey: frame.key,
                    radius: 19,
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFF22212B),
                      child: Icon(Icons.person, color: Colors.white54, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                frame.nameAr,
                maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              '${frame.durationMs}ms',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, color: Colors.white54),
            ),
            Text(
              _restrictionLabel(frame),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, color: Colors.white60),
            ),
            if (owner)
              const Text(
                'السعر من إدارة المنصة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 7, color: Colors.white38),
              ),
            const SizedBox(height: 3),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: FilledButton(
                onPressed: () => _equipRemoteFrame(frame, owned),
                child: Text(
                  current ? 'مُفعّل' : (owned ? 'تفعيل' : 'شراء'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
          ),
          if (owner)
            Positioned(top: 0, left: 0, child: _remoteFrameOwnerMenu(frame)),
        ],
      ),
    );
  }

  Widget _remoteFrameOwnerMenu(AvatarFrameDefinition frame) {
    return PopupMenuButton<String>(
      tooltip: 'خيارات الإدارة',
      padding: EdgeInsets.zero,
      iconSize: 16,
      splashRadius: 16,
      icon: const Icon(Icons.more_vert, size: 16),
      onSelected: (v) {
        switch (v) {
          case 'edit': _editProfileCosmeticFull(ProfileCosmeticItem(key: frame.key, category: 'frame', gender: 'unisex', nameAr: frame.nameAr, animationMode: 'gif', palette: 'custom', modeVariant: 'remote', color1: '#FFFFFF', color2: null, pricePoints: 0, priceGems: 0, metadata: const {}, isActive: true, sortOrder: 0)); break;
          case 'gift': _giftProfileCosmetic(frame.key, frame.nameAr); break;
          case 'delete': _deleteRemoteFrame(frame); break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('تعديل شامل')])),
        PopupMenuItem(value: 'gift', child: Row(children: [Icon(Icons.card_giftcard, size: 16, color: Colors.amberAccent), SizedBox(width: 8), Text('إهداء لمستخدم')])),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('حذف نهائي')])),
      ],
    );
  }

  Future<void> _deleteRemoteFrame(AvatarFrameDefinition frame) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true || !mounted) return;
    final confirmed = await _showOwnerMenuDialog<bool>(
      (dialogContext) => AlertDialog(
        title: const Text('حذف الإطار'),
        content: Text(
          'سيتم حذف «${frame.nameAr}» من الكتالوج وإلغاء تفعيله عن أي حساب يستخدمه. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'avatar-frame-delete-v2',
        body: {'frame_key': frame.key},
      );
      final resultMap = Map<String, dynamic>.from(response.data as Map);
      if (resultMap['ok'] != true) {
        final error = resultMap['error']?.toString() ?? 'FRAME_DELETE_FAILED';
        throw StateError(error);
      }
      ref.invalidate(serverAvatarFramesProvider);
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(myProfileCosmeticOwnershipProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(serverUserIdentityProvider);
      ref.invalidate(serverUserIdentityInRoomProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تم حذف الإطار من الخادم ✓ ${resultMap['cleared_profiles'] != null ? 'تم تنظيف ${resultMap['cleared_profiles']} بروفايل' : ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(_friendly(e))),
      );
    }
  }

  String _restrictionLabel(AvatarFrameDefinition frame) {
    if (frame.allowedRoleCodes.isEmpty && frame.minRankLevel <= 0 && frame.maxRankLevel == null) return 'متاح للجميع';
    final roles = frame.allowedRoleCodes.isEmpty ? 'كل الرتب' : frame.allowedRoleCodes.join(', ');
    final rank = frame.maxRankLevel == null ? 'L${frame.minRankLevel}+' : 'L${frame.minRankLevel}-${frame.maxRankLevel}';
    return '$roles • $rank';
  }

  Future<void> _equipRemoteFrame(AvatarFrameDefinition frame, bool owned) async {
    if (owned) {
      final ok = await _confirmStoreAction(title: 'تأكيد التفعيل', action: 'تفعيل', itemName: frame.nameAr, detail: 'سيتم تفعيل الإطار «${frame.nameAr}» وحفظه على الخادم. هل تريد المتابعة؟');
      if (!ok) return;
    }
    if (!owned) {
      if (!mounted) return;
      final currency = await showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('${frame.nameAr}\n${frame.key}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
              ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: const Text('الدفع بالنقاط'), onTap: () => Navigator.pop(c, 'points')),
              ListTile(leading: const Icon(Icons.diamond, color: Colors.cyan), title: const Text('الدفع بالجواهر'), onTap: () => Navigator.pop(c, 'gems')),
            ],
          ),
        ),
      );
      if (currency == null) return;
      final priceText = currency == 'points' ? 'النقاط' : 'الجواهر';
      final ok = await _confirmStoreAction(title: 'تأكيد الشراء', action: 'شراء', itemName: frame.nameAr, detail: 'سيتم شراء «${frame.nameAr}» باستخدام $priceText. هل تريد المتابعة؟');
      if (!ok) return;
      try {
        await Supabase.instance.client.rpc('purchase_profile_cosmetic', params: {
          'p_item_key': frame.key,
          'p_currency': currency,
          'p_request_id': const Uuid().v4(),
        });
        ref.invalidate(myProfileCosmeticOwnershipProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
        return;
      }
    }
    try {
      await Supabase.instance.client.rpc('set_avatar_frame', params: {'p_frame_key': frame.key});
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(serverUserIdentityProvider);
      ref.invalidate(serverUserIdentityInRoomProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم تفعيل الإطار من الخادم ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _showAddFrameDialog() async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;

    final result = await showDialog<_FrameUploadForm>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddRemoteFrameDialog(),
    );
    if (result == null || !mounted) return;

    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['gif', 'png', 'jpg', 'jpeg', 'webp', 'bmp'],
      withData: true,
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('تعذر قراءة ملف الإطار.')));
      return;
    }

    // Client-side validation is UX protection; server-side Storage/RPC rules remain authoritative.
    final extension = file.name.split('.').length > 1
        ? file.name.split('.').last.toLowerCase()
        : '';
    const supported = {'gif', 'png', 'jpg', 'jpeg', 'webp', 'bmp'};
    if (!supported.contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('صيغة الإطار غير مدعومة: .$extension')),
      );
      return;
    }
    if (bytes.length > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('حجم الإطار يجب ألا يتجاوز 8MB.')),
      );
      return;
    }

    var sourceWidth = 0;
    var sourceHeight = 0;
    var frameCount = 1;
    var durationMs = 0;
    if (extension == 'gif') {
      final info = GifInspector.inspect(Uint8List.fromList(bytes));
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('الملف المختار ليس GIF صالحًا.')),
        );
        return;
      }
      sourceWidth = info.width;
      sourceHeight = info.height;
      frameCount = info.numFrames;
      durationMs = info.durationMs;
      if (frameCount < 1 || frameCount > 120 || durationMs < 16 || durationMs > 120000) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('بيانات حركة GIF غير صالحة.')),
        );
        return;
      }
    } else {
      try {
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        final image = await codec.getNextFrame();
        sourceWidth = image.image.width;
        sourceHeight = image.image.height;
        image.image.dispose();
        codec.dispose();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('تعذر قراءة صورة الإطار.')),
        );
        return;
      }
    }
    if (sourceWidth < 64 || sourceWidth > 2048 || sourceHeight < 64 || sourceHeight > 2048) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('أبعاد الإطار يجب أن تكون بين 64×64 و2048×2048. الحجم الحالي: $sourceWidth×$sourceHeight.')),
      );
      return;
    }
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد رفع الإطار'),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(dialogContext).height * .62),
          child: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              SizedBox(
                width: 154,
                height: 154,
                child: Center(
                  child: AvatarFrameComposite(
                      size: 150,
                      framePadding: 0,
                      avatar: const CircleAvatar(
                        radius: 75,
                        backgroundColor: Color(0xFF2A2535),
                        child: Icon(Icons.person, color: Colors.white54, size: 46),
                      ),
                      frame: const AssetImage('images/frame_preview_placeholder.png'),
                      effect: result.frameEffect,
                    ),
                ),
              ),
              const SizedBox(height: 14),
              Text(result.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('$sourceWidth×$sourceHeight • $frameCount إطار • ${durationMs}ms'),
              const SizedBox(height: 4),

              const SizedBox(height: 4),
              Text('${result.pricePoints} نقطة • ${result.priceGems} جوهرة'),
              const SizedBox(height: 4),
              Text(
                result.allowedRoles.isEmpty
                    ? 'متاح لجميع الرتب'
                    : 'الرتب المسموحة: ${result.allowedRoles.join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                result.maxRank == null
                    ? 'Rank: ${result.minRank} وما فوق'
                    : 'Rank: ${result.minRank} - ${result.maxRank}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الرفع'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _frameUploadBusy) return;

    _frameUploadBusy = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('جاري التفعيل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'سيتم رفع الملف الأصلي كما هو والتحقق منه على الخادم.\n\nسيتم تفريغ المنطقة الدائرية الداخلية عند العرض وإضافة حركة وتأثير بصري للإطار.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    // Yield once so the progress dialog is painted before processing starts.
    await Future<void>.delayed(Duration.zero);

    late final Map<String, dynamic> response;
    var progressDialogOpen = true;
    void closeProgressDialog() {
      if (!progressDialogOpen || !mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
      progressDialogOpen = false;
    }

    try {
      response = await const AvatarFrameUploadService().uploadAndCreate(
        AvatarFrameUploadRequest(
          bytes: Uint8List.fromList(bytes),
          filename: file.name.isEmpty ? 'avatar-frame.$extension' : file.name,
          name: result.name,
          gender: result.gender,
          pricePoints: result.pricePoints,
          priceGems: result.priceGems,
          allowedRoles: result.allowedRoles,
          minRank: result.minRank,
          maxRank: result.maxRank,
          frameEffect: result.frameEffect,
        ),
      );
      // Close the processing modal before opening the success preview.
      closeProgressDialog();
      ref.invalidate(serverAvatarFramesProvider);
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(serverUserIdentityProvider);
      ref.invalidate(serverUserIdentityInRoomProvider);
      try {
        final refreshFuture = ref.refresh(serverAvatarFramesProvider.future);
        await refreshFuture;
      } catch (_) {
        // The upload is already committed; keep the success state and let the
        // realtime/provider lifecycle retry the catalog refresh.
      }
      if (!mounted) return;
      final frameKey = response['frame_key']?.toString() ?? '';
      final assetUrl = response['asset_url']?.toString() ?? '';
      if (mounted && assetUrl.isNotEmpty) {
        await _showProcessedFramePreview(
          assetUrl: assetUrl,
          name: result.name,
          sourceWidth: (response['source_width'] as num?)?.toInt() ?? sourceWidth,
          sourceHeight: (response['source_height'] as num?)?.toInt() ?? sourceHeight,
          targetWidth: (response['width'] as num?)?.toInt() ?? 512,
          targetHeight: (response['height'] as num?)?.toInt() ?? 512,
          frames: (response['frames'] as num?)?.toInt() ?? frameCount,
          durationMs: (response['duration_ms'] as num?)?.toInt() ?? durationMs,
          transparencyFixed: response['transparency_fixed'] == true,
          frameEffect: result.frameEffect,
          frameMetrics: AvatarFrameMetrics.fromMap(
            response['frame_metrics'] is Map
                ? Map<String, dynamic>.from(response['frame_metrics'] as Map)
                : <String, dynamic>{
                    'inner_opening_ratio': response['inner_opening_ratio'],
                    'inner_center_x': response['inner_center_x'],
                    'inner_center_y': response['inner_center_y'],
                    'detected_from_transparency': response['inner_opening_detected'],
                  },
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تمت إضافة الإطار وضبط فتحة الصورة تلقائيًا ${frameKey.isEmpty ? 'بنجاح ✓' : '($frameKey) ✓'}')),
      );
    } catch (e) {
      closeProgressDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تعذر إضافة الإطار: ${_friendly(e)}')),
      );
    } finally {
      closeProgressDialog();
      _frameUploadBusy = false;
    }
  }

  Future<void> _showProcessedFramePreview({
    required String assetUrl,
    required String name,
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
    required int frames,
    required int durationMs,
    required bool transparencyFixed,
    required String frameEffect,
    required AvatarFrameMetrics frameMetrics,
  }) async {
    if (assetUrl.trim().isEmpty || !mounted) return;
    final sampleAvatarUrl = ref.read(currentProfileProvider).valueOrNull?.avatarUrl;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة الإطار بعد الرفع'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .72,
            maxWidth: 360,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('1) ملف الإطار الأصلي', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: CustomPaint(
                      painter: _CheckerboardPainter(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.network(
                          assetUrl,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 42),
                          ),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('2) الإطار فوق صورة المستخدم', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ColoredBox(
                      color: Colors.black26,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AvatarFrameComposite(
                            size: 178,
                            framePadding: 0,
                            avatar: sampleAvatarUrl != null && sampleAvatarUrl.trim().isNotEmpty
                                ? Image.network(
                                    sampleAvatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const ColoredBox(
                                      color: Colors.white10,
                                      child: Center(child: Icon(Icons.person, size: 64)),
                                    ),
                                  )
                                : const ColoredBox(
                                    color: Colors.white10,
                                    child: Center(child: Icon(Icons.person, size: 64)),
                                  ),
                            frame: NetworkImage(assetUrl),
                            innerOpeningRatio: frameMetrics.innerOpeningRatio,
                            innerCenterX: frameMetrics.innerCenterX,
                            innerCenterY: frameMetrics.innerCenterY,
                            effect: frameEffect,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('الأصل: $sourceWidth×$sourceHeight'),
                Text('الحجم القياسي: $targetWidth×$targetHeight'),
                Text('الحركة: $frames إطار • ${durationMs.toString()}ms'),
                Text('المؤثر: ${FrameEffectCatalog.name(frameEffect)}'),
                Text(
                  frameMetrics.detectedFromTransparency
                      ? 'الفتحة المكتشفة: ${(frameMetrics.innerOpeningRatio * 100).round()}% • المحاذاة تلقائية ✓'
                      : 'الفتحة: نمط احتياطي 74% • يمكن ضبطها يدويًا لاحقًا',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Text(
                  transparencyFixed
                      ? 'تم تفعيل الإطار بطبقة شفافة حول صورة المستخدم ✓'
                      : 'يتم تطبيق تفريغ الداخل تلقائيًا عند عرض الإطار فوق الصورة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: transparencyFixed ? Colors.greenAccent : Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'صورة المستخدم تُعرض داخل فتحة دائرية، والإطار الثابت أو المتحرك يُعرض فوقها مع حركة وتأثير بصري.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ممتاز'),
          ),
        ],
      ),
    );
  }

  Widget _nameTemplatesSection(bool owner) {
    final async = ref.watch(nameTemplateCatalogProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('تعذر تحميل قوالب الأسماء الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (items) {
        final own = ref.watch(myProfileCosmeticOwnershipProvider).valueOrNull ?? const <String>{};
        final templates = items.where((i) => i.isActive).toList()..sort((a,b) => a.sortOrder.compareTo(b.sortOrder));
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          children: [
            const Text('قالب الاسم', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('50 قالب فيديو مستقلة للاسم. القالب هو الحاوية الأساسية؛ خلفية الاسم وتأثير اسم المستخدم، عند امتلاكهما، يُعرضان داخل القالب. وبدون القالب يبقيان يعملان منفصلين كما كانا.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35)),
            const SizedBox(height: 12),
            if (templates.length != 50)
              Text('تحذير الخادم: تم تحميل ${templates.length}/50 قالبًا', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final profile = ref.watch(currentProfileProvider).valueOrNull;
              final noneSelected = (profile?.usernameTemplateKey ?? '').trim().isEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(Icons.block, color: noneSelected ? Colors.amberAccent : Colors.white38),
                  title: Text('بلا قالب',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: noneSelected ? Colors.amberAccent : Colors.white70)),
                  subtitle: Text(noneSelected ? 'مُطبَّق حاليًا' : 'إلغاء قالب الاسم',
                      style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: noneSelected ? const Icon(Icons.check_circle, color: Colors.amberAccent) : null,
                  onTap: () => _clearLayer('name_template'),
                ),
              );
            }),
            ...templates.map((item) {
              final owned = own.contains(item.key);
              final canUse = owned || owner;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Center(child: SizedBox(width: 170, height: 50, child: FittedBox(fit: BoxFit.contain, child: NameTemplateHost(templateKey: item.key, name: _previewName, width: 145, height: 44, fontSize: 15)))),
                    const SizedBox(height: 2),
                    Text(item.nameAr, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${item.key} • قالب مستقل', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.star, size: 14, color: Colors.amber), Text(' ${item.pricePoints}  '), const Icon(Icons.diamond, size: 14, color: Colors.cyan), Text(' ${item.priceGems}')]),
                    const SizedBox(height: 5),
                    Wrap(alignment: WrapAlignment.center, spacing: 5, children: [
                      if (owned) const Chip(label: Text('مملوك', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                      if (owner) const Chip(label: Text('المالك', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (owner) ...[
                        _profileCosmeticOwnerMenu(item),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: FilledButton(
                        onPressed: () => _buyOrEquip(item),
                        child: Text(canUse ? 'تفعيل القالب' : 'شراء القالب'),
                      )),
                    ]),
                  ]),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _buyOrEquipNameAnimation(NameAnimation item, bool owner) async {
    final own = ref.read(myNameAnimationOwnershipProvider).valueOrNull ?? const <String>{};
    if (own.contains(item.key) || owner || item.ownerFree) {
      final ok = await _confirmStoreAction(title: 'تأكيد التفعيل', action: 'تفعيل', itemName: item.nameAr, detail: 'سيتم تفعيل الحيوان «${item.nameAr}» فوق الاسم وحفظه على الخادم. هل تريد المتابعة؟');
      if (!ok) return;
    }
    if (!own.contains(item.key) && !owner && !item.ownerFree) {
      if (!mounted) return;
      final currency = await showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            const Text('اختر طريقة الشراء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            // لا نعرض عملة سعرها صفر (الخادم يرفضها PRICE_NOT_SET).
            if (item.pricePoints > 0 || item.priceGems <= 0)
              ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: Text('${item.pricePoints} نقطة'), onTap: () => Navigator.pop(c, 'points')),
            if (item.priceGems > 0 || item.pricePoints <= 0)
              ListTile(leading: const Icon(Icons.diamond, color: Colors.cyan), title: Text('${item.priceGems} جوهرة'), onTap: () => Navigator.pop(c, 'gems')),
          ]),
        ),
      );
      if (currency == null) return;
      final priceText = currency == 'points' ? '${item.pricePoints} نقطة' : '${item.priceGems} جوهرة';
      final ok = await _confirmStoreAction(title: 'تأكيد الشراء', action: 'شراء', itemName: item.nameAr, detail: 'سيتم خصم $priceText وشراء «${item.nameAr}». هل تريد المتابعة؟');
      if (!ok) return;
      try {
        await ref.read(nameAnimationRepositoryProvider).purchase(item.key, currency);
        ref.invalidate(myNameAnimationOwnershipProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
        return;
      }
    }
    try {
      await ref.read(nameAnimationRepositoryProvider).activate(item.key);
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) ref.invalidate(activeNameAnimationProvider(uid));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم تفعيل الحيوان فوق الاسم ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  /// Comprehensive edit: name, both prices, owner-free, active state, sort
  /// order and the visual render effect — everything the catalog row holds,
  /// not just price like the previous dialog did.
  Future<void> _editNameAnimationFull(NameAnimation item) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    final name = TextEditingController(text: item.nameAr);
    final points = TextEditingController(text: item.pricePoints.toString());
    final gems = TextEditingController(text: item.priceGems.toString());
    final order = TextEditingController(text: item.sortOrder.toString());
    var ownerFree = item.ownerFree;
    var isActive = item.isActive;
    var effect = item.renderEffect;
    try {
      final ok = await _showOwnerMenuDialog<bool>(
        (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
          title: Text('تعديل ${item.nameAr}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            Row(children: [
              Expanded(child: TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الجواهر'))),
            ]),
            TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
            DropdownButtonFormField<String>(initialValue: effect, decoration: const InputDecoration(labelText: 'التأثير الحركي'), items: const [
              DropdownMenuItem(value: 'none', child: Text('بدون')),
              DropdownMenuItem(value: 'float_glow', child: Text('طفو وتوهّج')),
              DropdownMenuItem(value: 'bounce_glow', child: Text('ارتداد وتوهّج')),
            ], onChanged: (v) => setD(() => effect = v ?? 'float_glow')),
            SwitchListTile(value: ownerFree, onChanged: (v) => setD(() => ownerFree = v), title: const Text('مجاني للمالك'), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: isActive, onChanged: (v) => setD(() => isActive = v), title: const Text('مُفعَّل في المتجر'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))],
        )),
      );
      if (ok != true || !mounted) return;
      final p = int.tryParse(points.text.trim());
      final g = int.tryParse(gems.text.trim());
      final o = int.tryParse(order.text.trim());
      if (p == null || g == null || p < 0 || g < 0) throw StateError('INVALID_PRICE');
      if (o == null || o < 0) throw StateError('INVALID_SORT_ORDER');
      if (name.text.trim().isEmpty) throw StateError('NAME_REQUIRED');
      await Supabase.instance.client.rpc('admin_update_name_animation', params: {
        'p_effect_key': item.key, 'p_name_ar': name.text.trim(), 'p_price_points': p, 'p_price_gems': g,
        'p_owner_free': ownerFree, 'p_is_active': isActive, 'p_sort_order': o, 'p_render_effect': effect,
        'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(nameAnimationCatalogProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تم حفظ التعديلات ✓'), backgroundColor: Colors.green.shade700));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    } finally {
      name.dispose(); points.dispose(); gems.dispose(); order.dispose();
    }
  }

  Future<void> _deleteNameAnimation(NameAnimation item) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    final ok = await _showOwnerMenuDialog<bool>(
      (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('سيتم حذف «${item.nameAr}» نهائيًا من الكتالوج ومن كل حساب يملكه. هذا الإجراء لا يمكن التراجع عنه. هل تريد المتابعة؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () => Navigator.pop(c, true), child: const Text('حذف نهائيًا'))],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await Supabase.instance.client.rpc('admin_delete_name_animation', params: {'p_effect_key': item.key, 'p_request_id': const Uuid().v4()}) as Map;
      final storagePath = result['storage_path'] as String?;
      if (storagePath != null && storagePath.isNotEmpty) {
        await Supabase.instance.client.storage.from('name-animations').remove([storagePath]).catchError((_) => <FileObject>[]);
      }
      ref.invalidate(nameAnimationCatalogProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تم حذف «${item.nameAr}» نهائيًا ✓'), backgroundColor: Colors.green.shade700));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _giftNameAnimation(NameAnimation item) async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    await showAdminGiftDialog(
      context: context,
      itemLabel: item.nameAr,
      onConfirmGift: (userId, requestId) async {
        await Supabase.instance.client.rpc('admin_force_user_name_animation', params: {
          'p_user_id': userId, 'p_effect_key': item.key, 'p_request_id': requestId,
        });
      },
    );
  }

  Widget _nameAnimalsSection(bool owner, {String displayMode = 'details'}) {
    final catalog = ref.watch(nameAnimationCatalogProvider);
    final own = ref.watch(myNameAnimationOwnershipProvider).valueOrNull ?? const <String>{};
    final gridExtent = switch (displayMode) { 'small_icons' => 108.0, 'large_icons' => 225.0, _ => 175.0 };
    final gridMainExtent = switch (displayMode) { 'small_icons' => 128.0, 'large_icons' => 215.0, _ => 166.0 };
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل حيوانات الاسم الآن.')),
      data: (items) {
        final animals = [...items]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return Column(
          children: [
            if (owner)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: _uploadNameAnimation,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('رفع GIF حيوان متحرك'),
                  ),
                ),
              ),
            if (animals.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      owner
                          ? 'القسم جاهز. ارفع صور الحيوانات بصيغة GIF لتظهر هنا ثم يمكن شراءها وتفعيلها فوق قالب الاسم.'
                          : 'لا توجد حيوانات متاحة حاليًا.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 30),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: gridExtent,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: gridMainExtent,
                  ),
                  itemCount: animals.length + 1,
                  itemBuilder: (_, rawI) {
                    if (rawI == 0) {
                      final activeAnimal = ref.watch(activeNameAnimationProvider(
                          ref.watch(currentProfileProvider).valueOrNull?.uid ?? '')).valueOrNull;
                      final noneSelected = activeAnimal == null ||
                          !activeAnimal.isActive ||
                          activeAnimal.key.trim().isEmpty;
                      return _noneCard(
                        selected: noneSelected,
                        onTap: () => _clearLayer('name_animal'),
                      );
                    }
                    final i = rawI - 1;
                    final item = animals[i];
                    final owned = owner || own.contains(item.key) || item.ownerFree;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Every element is sized as a fraction of whatever
                          // height the grid actually hands this cell, so the
                          // same card works in details / small_icons /
                          // large_icons without ever overflowing or needing
                          // a per-mode special case.
                          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 166.0;
                          final imageH = (h * 0.34).clamp(30.0, 76.0);
                          final nameSize = (h * 0.085).clamp(10.0, 13.0);
                          final priceSize = (h * 0.065).clamp(8.0, 10.0);
                          final buyHeight = (h * 0.19).clamp(26.0, 34.0);
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      height: imageH,
                                      child: Center(
                                        child: AnimatedNameAnimalEffect(animation: item, width: 44, height: 30),
                                      ),
                                    ),
                                    Text(
                                      item.nameAr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w900),
                                    ),
                                    if (owned)
                                      Text('متاح ✓', style: TextStyle(fontSize: priceSize, fontWeight: FontWeight.w800))
                                    else
                                      Text(
                                        '${item.pricePoints} نقطة • ${item.priceGems} جوهرة',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: priceSize),
                                      ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: buyHeight,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(padding: EdgeInsets.zero, textStyle: TextStyle(fontSize: nameSize)),
                                        onPressed: () => _buyOrEquipNameAnimation(item, owner),
                                        child: Text(owned ? 'تفعيل' : 'شراء'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Owner actions live in a corner overlay menu
                              // instead of an inline row, so they never
                              // compete with the card's own vertical budget
                              // (and a single PopupMenuButton avoids packing
                              // several tiny IconButtons edge-to-edge, which
                              // is what triggers MouseTracker hit-test
                              // assertions on desktop/web).
                              if (owner)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: PopupMenuButton<String>(
                                    tooltip: 'خيارات الإدارة',
                                    padding: EdgeInsets.zero,
                                    iconSize: 16,
                                    splashRadius: 16,
                                    icon: const Icon(Icons.more_vert, size: 16),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'edit': _editNameAnimationFull(item); break;
                                        case 'gift': _giftNameAnimation(item); break;
                                        case 'delete': _deleteNameAnimation(item); break;
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('تعديل شامل')])),
                                      PopupMenuItem(value: 'gift', child: Row(children: [Icon(Icons.card_giftcard, size: 16, color: Colors.amberAccent), SizedBox(width: 8), Text('إهداء لمستخدم')])),
                                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('حذف نهائي')])),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _uploadNameAnimation() async {
    if (ref.read(chatStoreOwnerProvider).valueOrNull != true) return;
    final file = await fp.FilePicker.pickFiles(type: fp.FileType.custom, allowedExtensions: const ['gif'], withData: true);
    if (file == null || file.files.isEmpty) return;
    if (!mounted) return;
    final selected = file.files.single;
    final bytes = selected.bytes;
    if (bytes == null || bytes.isEmpty) return;
    try {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('رفع GIF حيوان متحرك'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 120,
            child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('رفع'))],
      ));
      if (ok != true || !mounted) return;
      await const NameAnimationUploadService().uploadAndCreate(
        NameAnimationUploadRequest(
          bytes: Uint8List.fromList(bytes),
          filename: selected.name,
          key: 'auto',
          nameAr: selected.name.replaceFirst(RegExp(r'\.gif$', caseSensitive: false), ''),
          category: 'animal',
          pricePoints: 5000,
          priceGems: 50,
        ),
      );
      ref.invalidate(nameAnimationCatalogProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم رفع الحيوان وإضافته للمتجر ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(_friendly(e))));
    }
  }

  Widget _liveNameSection() {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final effect = UsernameEffectX.fromWire(profile.usernameEffect);
    final templateKey = profile.usernameTemplateKey?.trim();
    final backgroundMode = profile.usernameBackgroundMode;
    final animatedUrl = profile.animatedAvatarUrl?.trim();
    final avatarUrl = profile.avatarUrl?.trim();
    final background = backgroundMode == null || backgroundMode.isEmpty
        ? null
        : UsernameCosmeticName(
            name: profile.displayName,
            effect: effect,
            fontSize: profile.usernameFontSize,
            backgroundMode: backgroundMode,
            backgroundColor1: profile.usernameBackgroundColor1,
            backgroundColor2: profile.usernameBackgroundColor2,
            backgroundOpacity: profile.usernameBackgroundOpacity,
            externalEffect: profile.usernameBackgroundExternalEffect,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            userId: profile.uid,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'اسمك',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        const SizedBox(height: 24),
        Center(
          child: DynamicAvatarFrame(
            frameKey: profile.avatarFrameKey,
            radius: 46,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFF1E1C29),
              backgroundImage: animatedUrl?.isNotEmpty == true
                  ? NetworkImage(animatedUrl ?? '')
                  : (avatarUrl?.isNotEmpty == true
                      ? NetworkImage(avatarUrl ?? '')
                      : null),
              child: avatarUrl == null && animatedUrl == null
                  ? const Icon(Icons.person, color: Colors.white54, size: 40)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: AnimatedNameAnimalAboveName(
            animation: ref.watch(activeNameAnimationProvider(profile.uid)).valueOrNull,
            name: templateKey != null && NameTemplateRegistry.get(templateKey) != null
                ? NameTemplateHost(
                    templateKey: templateKey,
                    name: profile.displayName,
                    width: 300,
                    height: 76,
                    fontSize: 20,
                  )
                : background ??
                    UsernameCosmeticName(
                      name: profile.displayName,
                      effect: effect,
                      fontSize: profile.usernameFontSize,
                      userId: profile.uid,
                    ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                templateKey != null && NameTemplateRegistry.get(templateKey) != null
                    ? 'قالب الاسم: $templateKey'
                    : 'تأثير الاسم: ${profile.usernameEffect}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                profile.usernameBackgroundKey == null
                    ? 'خلفية اسم غير محددة'
                    : 'خلفية الاسم: ${profile.usernameBackgroundKey}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                profile.avatarFrameKey == null
                    ? 'إطار الصورة غير محدد'
                    : 'إطار الصورة: ${profile.avatarFrameKey}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The name shown inside every store preview. Uses the signed-in user's
  /// real display name (same source the profile renders from) instead of the
  /// literal placeholder "(اسمك)", so a card previews exactly what the user
  /// will actually get. Falls back to an empty string — leaving the frame
  /// interior genuinely empty — rather than showing a placeholder.
  String get _previewName {
    final n = ref.watch(currentProfileProvider).valueOrNull?.displayName.trim() ?? '';
    return n;
  }

  Widget _preview(ProfileCosmeticItem item){
    if (item.category == 'name_template') {
      return Center(child: NameTemplateHost(templateKey: item.key, name: _previewName, width: 145, height: 44, fontSize: 15));
    }
    if (item.category == 'frame') {
      return Center(
        child: SizedBox(
          width: 58,
          height: 58,
          child: FittedBox(
            fit: BoxFit.contain,
            child: DynamicAvatarFrame(
          frameKey: item.key,
          radius: 23,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22212B),
            ),
            child: const Icon(Icons.person, color: Colors.white54),
          ),
        ),
            ),
          ),
        );
    }

    final effect = UsernameEffectX.fromWire(
      item.metadata['effect_key']?.toString(),
    );
    if (item.category == 'background') {
      return Center(child:UsernameCosmeticName(
        name:_previewName,
        effect:effect,
        fontSize:18,
        backgroundMode:item.animationMode,
        backgroundColor1:item.color1,
        backgroundColor2:item.color2,
        backgroundOpacity:((item.metadata['opacity'] as num?)?.toDouble() ?? .82),
        externalEffect:item.metadata['outer_effect']?.toString(),
        padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
      ));
    }
    if (item.category == 'name_effect') {
      return Center(child: UsernameEffectText(name: _previewName, effect: effect, fontSize: 20));
    }
    return const SizedBox.shrink();
  }
}


class _FrameUploadForm {
  final String name;
  final String gender;
  final int pricePoints;
  final int priceGems;
  final List<String> allowedRoles;
  final int minRank;
  final int? maxRank;
  final String frameEffect;
  const _FrameUploadForm({
    required this.name,
    required this.gender,
    required this.pricePoints,
    required this.priceGems,
    required this.allowedRoles,
    required this.minRank,
    required this.maxRank,
    required this.frameEffect,
  });
}

class _AddRemoteFrameDialog extends StatefulWidget {
  const _AddRemoteFrameDialog();
  @override State<_AddRemoteFrameDialog> createState()=>_AddRemoteFrameDialogState();
}
class _AddRemoteFrameDialogState extends State<_AddRemoteFrameDialog> {
  final name=TextEditingController();
  final points=TextEditingController(text:'0');
  final gems=TextEditingController(text:'0');
  final minRank=TextEditingController(text:'0');
  final maxRank=TextEditingController();
  String gender='unisex';
  String frameEffect='pulse_glow';
  List<Map<String,dynamic>> roles=[];
  final selectedRoles=<String>{};
  bool loadingRoles=true;
  @override void initState(){super.initState(); _loadRoles();}
  Future<void> _loadRoles() async {
    try{
      final raw=await Supabase.instance.client.from('roles').select('code,name,priority').order('priority',ascending:false);
      if(mounted) setState(()=>roles=List<Map<String,dynamic>>.from(raw as List));
    }catch(_){ }
    if(mounted)setState(()=>loadingRoles=false);
  }
  @override void dispose(){name.dispose();points.dispose();gems.dispose();minRank.dispose();maxRank.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('إضافة إطار متحرك'),
    content:SingleChildScrollView(
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[

        const SizedBox(height:12),
        TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الإطار')),
        const SizedBox(height:8),
                DropdownButtonFormField<String>(
          initialValue: frameEffect,
          items: FrameEffectCatalog.options
              .map((o) => DropdownMenuItem<String>(value: o.key, child: Text(o.nameAr)))
              .toList(growable: false),
          onChanged:(v)=>setState(()=>frameEffect=v??'pulse_glow'),
          decoration:const InputDecoration(labelText:'مؤثر الإطار'),
        ),
        const SizedBox(height:8),
        const Text('الحجم والأبعاد تُفحص تلقائيًا. GIF يحتفظ بحركته، والصور الثابتة تحصل على المؤثر المختار عند العرض. المؤثر يعمل داخل المتجر وفي البروفايل والشات.', style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height:8),
        Row(children:[Expanded(child:TextField(controller:points,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'نقاط'))),const SizedBox(width:8),Expanded(child:TextField(controller:gems,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'جواهر')))]),
        const SizedBox(height:8),
        TextField(controller:minRank,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'أدنى Rank Level (0 للجميع)')),
        const SizedBox(height:8),
        TextField(controller:maxRank,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'أقصى Rank Level (اختياري)')),
        const SizedBox(height:12),
        const Text('الرتب المسموحة (اتركها فارغة = الجميع)',style:TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        if (loadingRoles)
          const LinearProgressIndicator()
        else
          ...roles.map((r) {
            final code = r['code']?.toString() ?? '';
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: selectedRoles.contains(code),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    selectedRoles.add(code);
                  } else {
                    selectedRoles.remove(code);
                  }
                });
              },
              title: Text(r['name']?.toString() ?? code),
              subtitle: Text(
                code,
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            );
          }),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          final n = name.text.trim();
          final p = int.tryParse(points.text.trim());
          final g = int.tryParse(gems.text.trim());
          final min = int.tryParse(minRank.text.trim());
          final max = maxRank.text.trim().isEmpty
              ? null
              : int.tryParse(maxRank.text.trim());

          final invalid =
              n.isEmpty ||
              p == null ||
              p < 0 ||
              g == null ||
              g < 0 ||
              min == null ||
              min < 0 ||
              (max != null && max < min);

          if (invalid) {
            ScaffoldMessenger.of(context).showSnackBarSfx(
              const SnackBar(content: Text('تحقق من بيانات الإطار.')),
            );
            return;
          }

          Navigator.pop(
            context,
            _FrameUploadForm(
              name: n,
              gender: gender,
              pricePoints: p,
              priceGems: g,
              allowedRoles: selectedRoles.toList(),
              minRank: min,
              maxRank: max,
              frameEffect: frameEffect,
            ),
          );
        },
        child: const Text('اختيار الإطار ومتابعة'),
      ),
    ],
  );
}

/// غامق ومائل لنص الرسائل — الخادم (set_my_message_style) جاهز
/// منذ إضافته لكن بلا أي واجهة، فبقيت الميزة غير قابلة للوصول.
/// المقياس محدود خادميًا بين 0.80 و1.60 أصلًا (الحدّ الفعلي هناك
/// لا هنا)، فالواجهة تكتفي بغامق/مائل فقط دون منزلق حجم إضافي.
class _MessageTextStyleSection extends ConsumerStatefulWidget {
  const _MessageTextStyleSection();
  @override
  ConsumerState<_MessageTextStyleSection> createState() =>
      _MessageTextStyleSectionState();
}

class _MessageTextStyleSectionState
    extends ConsumerState<_MessageTextStyleSection> {
  bool? _bold;
  bool? _italic;
  bool _busy = false;

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('profiles')
        .select('message_bold, message_italic')
        .eq('id', uid)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _bold = row?['message_bold'] == true;
        _italic = row?['message_italic'] == true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _apply({bool? bold, bool? italic}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('set_my_message_style', params: {
        'p_bold': bold,
        'p_italic': italic,
      });
      setState(() {
        if (bold != null) _bold = bold;
        if (italic != null) _italic = italic;
      });
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        ref.invalidate(serverUserIdentityProvider(uid));
      }
    } catch (e) {
      messenger?.showSnackBarSfx(SnackBar(content: Text('تعذّر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bold == null || _italic == null) {
      return const SizedBox(height: 40);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _styleToggle(
            icon: Icons.format_bold_rounded,
            label: 'غامق',
            active: _bold!,
            onTap: _busy ? null : () => _apply(bold: !_bold!),
          ),
          const SizedBox(width: 10),
          _styleToggle(
            icon: Icons.format_italic_rounded,
            label: 'مائل',
            active: _italic!,
            onTap: _busy ? null : () => _apply(italic: !_italic!),
          ),
        ],
      ),
    );
  }

  Widget _styleToggle({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFD700).withValues(alpha: .18)
                : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active
                    ? const Color(0xFFFFD700)
                    : Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? const Color(0xFFFFD700) : Colors.white60),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? const Color(0xFFFFD700)
                          : Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}

/// تلوين شارة الرتبة بمؤثر من مؤثرات الاسم وخلفية من خلفيات إطار الاسم. يُستعمل
/// ما يملكه العضو من المتجر (أو يشتريه من هنا)؛ التطبيق عبر set_my_role_style
/// التي تتحقق من الملكية خادميًا، والمالك بلا شراء.
class _RoleColorTab extends StatefulWidget {
  const _RoleColorTab();
  @override
  State<_RoleColorTab> createState() => _RoleColorTabState();
}

class _RoleColorTabState extends State<_RoleColorTab> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _effects = [];
  List<Map<String, dynamic>> _backgrounds = [];
  Set<String> _ownedItems = {};
  String? _fx;
  String? _bg;
  bool _owner = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _db.auth.currentUser?.id;
    try {
      final fx = await _db
          .from('profile_cosmetic_catalog')
          .select('item_key,name_ar,metadata,price_points,price_gems')
          .eq('category', 'name_effect')
          .eq('is_active', true)
          .order('sort_order');
      final bg = await _db
          .from('profile_cosmetic_catalog')
          .select('item_key,name_ar,color1,color2,price_points,price_gems')
          .eq('category', 'background')
          .eq('is_active', true)
          .order('sort_order');
      final owned = uid == null ? <dynamic>[] : await _db.rpc('get_my_profile_cosmetic_ownership');
      final me = uid == null
          ? null
          : await _db.from('profiles').select('role_effect_key,role_background_key').eq('id', uid).maybeSingle();
      final owner = await _db.rpc('is_my_platform_owner');
      // نسختا الذكور والإناث تشتركان في المؤثر نفسه؛ يُعرض كل مؤثر مرة واحدة.
      final seen = <String>{};
      final effects = <Map<String, dynamic>>[];
      final itemKeys = <String, List<String>>{};
      for (final e in List<Map<String, dynamic>>.from(fx as List)) {
        final key = (e['metadata'] is Map ? e['metadata']['effect_key'] : null)?.toString() ?? '';
        if (key.isEmpty) continue;
        (itemKeys[key] ??= []).add(e['item_key'].toString());
        if (!seen.add(key)) continue;
        effects.add({...e, 'effect_key': key});
      }
      if (!mounted) return;
      setState(() {
        _effects = effects;
        _effectItemKeys = itemKeys;
        _backgrounds = List<Map<String, dynamic>>.from(bg as List);
        _ownedItems = (owned as List).map((e) => e['item_key'].toString()).toSet();
        _fx = me?['role_effect_key']?.toString();
        _bg = me?['role_background_key']?.toString();
        _owner = owner == true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// مؤثر ← منتجاته (نسختا الذكور والإناث). يملك العضو المؤثر إن اشترى أيًّا منها.
  Map<String, List<String>> _effectItemKeys = {};
  bool _ownsEffect(String effectKey) =>
      _owner || (_effectItemKeys[effectKey]?.any(_ownedItems.contains) ?? false);

  bool _ownsBg(Map<String, dynamic> b) => _owner ||
      _ownedItems.contains(b['item_key']) ||
      ((b['price_points'] ?? 0) == 0 && (b['price_gems'] ?? 0) == 0);

  Color _c(String? hex) {
    final h = (hex ?? '').replaceAll('#', '');
    return h.length == 6 ? Color(int.parse('FF$h', radix: 16)) : const Color(0xFF8E7CFF);
  }

  Future<void> _run(Future<void> Function() op, String ok) async {
    setState(() => _busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await op();
      await _load();
      m.showSnackBarSfx(SnackBar(content: Text(ok)));
    } catch (e) {
      final t = e.toString();
      m.showSnackBarSfx(SnackBar(content: Text(t.contains('INSUFFICIENT')
          ? 'رصيدك لا يكفي.'
          : t.contains('ITEM_NOT_OWNED') ? 'اشترِ العنصر أولًا.' : 'تعذّر التنفيذ: $t')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply({String? fx, String? bg}) => _run(
      () => _db.rpc('set_my_role_style', params: {'p_effect_key': fx, 'p_background_key': bg}),
      'طُبّق على شارة رتبتك');

  Future<void> _buy(String itemKey) => _run(
      () => _db.rpc('purchase_profile_cosmetic', params: {
            'p_item_key': itemKey,
            'p_currency': 'points',
            'p_request_id': const Uuid().v4(),
          }),
      'تم الشراء');

  Widget _preview({String? fx, Map<String, dynamic>? bg}) {
    const label = '👑 رتبتك';
    final Widget text = fx != null
        ? UsernameEffectText(name: label, effect: UsernameEffectX.fromWire(fx), fontSize: 11, fontWeight: FontWeight.w900)
        : Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900));
    if (bg == null) return text;
    final c1 = _c(bg['color1']?.toString());
    final c2 = _c((bg['color2'] ?? bg['color1'])?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]), borderRadius: BorderRadius.circular(7)),
      child: text,
    );
  }

  Widget _cell({required Widget preview, required bool active, required bool owned,
      required int price, required VoidCallback onApply, required VoidCallback onBuy}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? const Color(0xFFFFD700) : Colors.white24, width: active ? 2 : 1),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        preview,
        const SizedBox(height: 6),
        if (!owned) Text('⭐ $price', style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: owned
              ? FilledButton(
                  onPressed: _busy || active ? null : onApply,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(active ? 'مفعّل' : 'تطبيق', style: const TextStyle(fontSize: 11)))
              : OutlinedButton(
                  onPressed: _busy ? null : onBuy,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('شراء', style: TextStyle(fontSize: 11))),
        ),
      ]),
    );
  }

  Widget _grid(List<Widget> children) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .95,
        children: children,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعذّر التحميل'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            child: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    final currentBg = _backgrounds.where((b) => b['item_key'] == _bg).firstOrNull;
    return ListView(padding: const EdgeInsets.all(12), children: [
          Center(child: Padding(padding: const EdgeInsets.all(8), child: _preview(fx: _fx, bg: currentBg))),
          if (_fx != null || _bg != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _busy ? null : () => _apply(fx: null, bg: null),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة الشارة الافتراضية'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('مؤثرات الاسم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          _grid([
            for (final e in _effects)
              _cell(
                preview: _preview(fx: e['effect_key'], bg: currentBg),
                active: _fx == e['effect_key'],
                owned: _ownsEffect(e['effect_key']),
                price: (e['price_points'] as num?)?.toInt() ?? 0,
                onApply: () => _apply(fx: e['effect_key'], bg: _bg),
                onBuy: () => _buy(e['item_key'].toString()),
              ),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('خلفيات إطار الاسم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          _grid([
            for (final b in _backgrounds)
              _cell(
                preview: _preview(fx: _fx, bg: b),
                active: _bg == b['item_key'],
                owned: _ownsBg(b),
                price: (b['price_points'] as num?)?.toInt() ?? 0,
                onApply: () => _apply(fx: _fx, bg: b['item_key'].toString()),
                onBuy: () => _buy(b['item_key'].toString()),
              ),
          ]),
        ]);
  }
}
