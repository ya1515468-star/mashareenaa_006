import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/monitoring/error_monitor.dart';
import '../../../../core/services/media_upload_service.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'mini_chat_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gifts/domain/entities/gift_entity.dart';
import '../../../gifts/presentation/providers/gift_provider.dart';
import '../../../gifts/presentation/widgets/gift_picker_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../friends/presentation/widgets/friend_button.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import 'game_hub.dart';
import '../../../../core/services/server_sounds.dart';

/// نافذة الملف المصغَّر — تفتح عند الضغط على صورة أي عضو آخر داخل
/// الشات العام: الاسم، صورة الملف، الغلاف، الرتبة، زر عرض الملف
/// الكامل، زر مراسلة خاصة، وصندوق هدايا لإهدائه مباشرة (بند ش من
/// مواصفة التعديلات).
class MiniProfilePopup extends ConsumerWidget {
  final String uid;
  final String? roomId;
  const MiniProfilePopup({super.key, required this.uid, this.roomId});

  static Future<String?> show(BuildContext context, String uid,
      {String? roomId}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 340,
              maxHeight: size.height * 0.72,
            ),
            child: Stack(children: [
              MiniProfilePopup(uid: uid, roomId: roomId),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _threadIdFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _sendGift(
      BuildContext context, WidgetRef ref, GiftEntity gift) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null || myUid == uid) return;
    final tx = await ref
        .read(giftControllerProvider.notifier)
        // roomId هنا هو غرفة النافذة الحالية: بتمريره ينشر الخادم إعلان
        // "قام فلان بإرسال هدية إلى فلان" في الغرفة نفسها تلقائيًا.
        .sendGift(fromUid: myUid, toUid: uid, gift: gift, roomId: roomId);
    if (!context.mounted) return;
    final reason = ref.read(giftControllerProvider.notifier).lastError?.trim();

    ScaffoldMessenger.of(context).showSnackBarSfx(
      SnackBar(
        content: Text(
          tx != null
              ? 'تم إرسال ${gift.nameAr} ${gift.emoji}'
              : (reason == null || reason.isEmpty
                  ? 'تعذّر إرسال الهدية.'
                  : 'تعذّر إرسال الهدية: $reason'),
        ),
      ),
    );
  }

  Future<void> _adminCall(BuildContext context, String rpc,
      Map<String, dynamic> params, String success) async {
    try {
      await Supabase.instance.client.rpc(rpc, params: params);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(success)));
    } catch (e) {
      if (!context.mounted) return;
      final raw = e.toString();
      const known = {
        'MUTE_NOT_ACTIVE': 'الكتم مرفوع مسبقًا (ربما رفعه شخص آخر).',
        'BAN_NOT_ACTIVE': 'الحظر مرفوع مسبقًا.',
        'KICK_NOT_ACTIVE': 'الطرد منتهٍ أو مرفوع مسبقًا.',
        'BURY_NOT_ACTIVE': 'العضو ليس في المقبرة.',
        'TARGET_ROLE_TOO_HIGH': 'لا يمكنك تنفيذ أمر على رتبة مساوية أو أعلى منك.',
        'FORBIDDEN': 'ليست لديك صلاحية لهذا الأمر.',
        'CANNOT_ASSIGN_EQUAL_OR_HIGHER_ROLE': 'لا يمكنك منح رتبة مساوية أو أعلى من رتبتك.',
      };
      var msg = 'لم يكتمل الأمر: $raw';
      for (final k in known.entries) {
        if (raw.contains(k.key)) {
          msg = k.value;
          break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(msg)));
    }
  }

  /// يرفع مشرف الغرفة صورة لعضو آخر ويحفظها في ملفه الشخصي. الرفع نفسه
  /// يحدث داخل مجلد المشرف هو (نفس آلية رفع الصورة الشخصية العادية، بلا
  /// أي تعديل على سياسات التخزين)، ثم admin_set_member_avatar الخادمية
  /// هي من تتحقق من صلاحية تعديل ملف هذا العضو تحديدًا (بمقارنة الأولوية
  /// الحقيقية، لا افتراضًا محليًا) قبل حفظ الرابط في ملف الهدف.
  Future<void> _pickAndSetMemberAvatar(BuildContext context) async {
    final rid = roomId;
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (rid == null || myUid == null) return;
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) return;

      final url = await MediaUploadService(bucket: 'profile-avatars')
          .uploadBytes(
              bytes: bytes, fileName: picked.name, folder: 'room-edit', uid: myUid);

      await Supabase.instance.client.rpc('admin_set_member_avatar', params: {
        'p_room_id': rid,
        'p_user_id': uid,
        'p_avatar_url': url,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(const SnackBar(content: Text('تم تحديث صورة العضو ✓')));
    } catch (e) {
      unawaited(ErrorMonitor.report(e, screen: 'mini_profile_popup', source: 'admin_set_member_avatar'));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تعذّر تحديث الصورة: $e')));
    }
  }

  static const _durations = <MapEntry<String, int?>>[
    MapEntry('5 دقائق', 5),
    MapEntry('15 دقيقة', 15),
    MapEntry('30 دقيقة', 30),
    MapEntry('ساعة', 60),
    MapEntry('6 ساعات', 360),
    MapEntry('24 ساعة', 1440),
    MapEntry('7 أيام', 10080),
  ];

  /// يعرض خيارات المدة. يعيد null عند الإلغاء، و(label, minutes) حيث minutes
  /// فارغة تعني دائم (للكتم والحظر فقط).
  Future<({String label, int? minutes})?> _pickDuration(
      BuildContext context, String title,
      {bool allowPermanent = false}) {
    return showModalBottomSheet<({String label, int? minutes})>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (sheetContext) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text(title),),
          ..._durations.map((d) => ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(d.key),
                onTap: () => Navigator.pop(
                    sheetContext, (label: d.key, minutes: d.value)),
              )),
          if (allowPermanent)
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('دائم'),
              onTap: () => Navigator.pop(
                  sheetContext, (label: 'بشكل دائم', minutes: null)),
            ),
        ]),
      ),
    );
  }

  Future<void> _timedAction(BuildContext context, String rpc, String title,
      String reason, String doneVerb,
      {bool allowPermanent = false}) async {
    final rid = roomId;
    if (rid == null) return;
    final d = await _pickDuration(context, title, allowPermanent: allowPermanent);
    if (d == null || !context.mounted) return;
    await _adminCall(
        context,
        rpc,
        {
          'p_room_id': rid,
          'p_user_id': uid,
          'p_duration_minutes': d.minutes,
          'p_reason': reason
        },
        d.minutes == null ? '$doneVerb بشكل دائم ✓' : '$doneVerb لمدة ${d.label} ✓');
  }

  Future<void> _pickRole(BuildContext context) async {
    try {
      final raw = await Supabase.instance.client.rpc('get_assignable_global_roles');
      final roles = (raw is List ? raw : const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!context.mounted) return;
      if (roles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
            const SnackBar(content: Text('لا توجد رتب يمكنك منحها لهذا العضو')));
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: AppColors.surfaceElevated,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                  title: Text('تعيين/ترقية العضو'),
                  subtitle: Text('اختر الرتبة (الرتبة الحالية تُستبدل)')),
              ...roles.map((r) => ListTile(
                    leading: const Icon(Icons.military_tech_outlined),
                    title: Text((r['name'] ?? r['code'] ?? 'رتبة').toString()),
                    onTap: () => Navigator.pop(sheetContext, r),
                  )),
            ],
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      final me = Supabase.instance.client.auth.currentUser?.id;
      await _adminCall(
          context,
          'assign_role',
          {
            'p_target_user_id': uid,
            'p_role_code': selected['code'],
            'p_assigned_by': me,
          },
          'تم تعيين الرتبة: ${selected['name']} ✓');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تعذر تحميل الرتب: $e')));
    }
  }

  Widget _adminSection(BuildContext context, Map<String, dynamic> controls) {
    final rid = roomId;
    if (rid == null || controls.isEmpty) return const SizedBox.shrink();
    // قاعدة صارمة: لا يظهر أي أمر إداري تجاه عضو رتبته مساوية أو أعلى.
    if (controls['outranks_target'] != true) return const SizedBox.shrink();
    final allowed = controls['can_manage'] == true ||
        controls['can_moderate'] == true ||
        controls['can_roles'] == true ||
        controls['can_assign_global_role_this_target'] == true;
    if (!allowed) return const SizedBox.shrink();
    final banned = controls['is_banned'] == true;
    final muted = controls['is_muted'] == true;
    final kicked = controls['is_kicked'] == true;
    final buried = controls['is_buried'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(),
        const Text('إدارة العضو',
            style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (controls['can_ban'] == true && !banned)
            OutlinedButton.icon(
                onPressed: () => _timedAction(context, 'ban_room_member',
                    'حظر العضو من الغرفة', 'إدارة الغرفة', 'تم حظر العضو',
                    allowPermanent: true),
                icon: const Icon(Icons.block),
                label: const Text('حظر')),
          if (controls['can_unban'] == true && banned)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'unban_room_member',
                    {
                      'p_room_id': rid,
                      'p_user_id': uid,
                      'p_reason': 'إلغاء الحظر'
                    },
                    'تم إلغاء الحظر ✓'),
                icon: const Icon(Icons.lock_open),
                label: const Text('إلغاء الحظر')),
          if (controls['can_kick'] == true && !banned && !kicked)
            OutlinedButton.icon(
                onPressed: () => _timedAction(context, 'kick_room_member',
                    'طرد العضو من الغرفة', 'طرد من الغرفة', 'تم طرد العضو'),
                icon: const Icon(Icons.logout),
                label: const Text('طرد')),
          if (controls['can_unkick'] == true && kicked)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'unkick_room_member',
                    {
                      'p_room_id': rid,
                      'p_user_id': uid,
                      'p_reason': 'إلغاء الطرد'
                    },
                    'تم إلغاء الطرد ✓'),
                icon: const Icon(Icons.login),
                label: const Text('إلغاء الطرد')),
          if (controls['can_mute'] == true && !banned && !muted)
            OutlinedButton.icon(
                onPressed: () => _timedAction(context, 'mute_room_member',
                    'كتم العضو', 'كتم مؤقت', 'تم كتم العضو',
                    allowPermanent: true),
                icon: const Icon(Icons.volume_off),
                label: const Text('كتم')),
          if (controls['can_unmute'] == true && muted)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'unmute_room_member',
                    {
                      'p_room_id': rid,
                      'p_user_id': uid,
                      'p_reason': 'إلغاء الكتم'
                    },
                    'تم رفع الإخراس ✓'),
                icon: const Icon(Icons.volume_up),
                label: const Text('رفع الإخراس')),
          if ((controls['can_unbury'] == true ||
                  controls['can_manage_members'] == true ||
                  controls['is_dragon'] == true) &&
              !buried)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'bury_room_member',
                    {'p_room_id': rid, 'p_user_id': uid, 'p_reason': 'المقبرة'},
                    'تم نقل العضو إلى المقبرة ✓'),
                icon: const Icon(Icons.delete_forever),
                label: const Text('المقبرة')),
          if ((controls['can_unbury'] == true ||
                  controls['can_manage_members'] == true ||
                  controls['is_dragon'] == true) &&
              buried)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'unbury_room_member',
                    {
                      'p_room_id': rid,
                      'p_user_id': uid,
                      'p_reason': 'رفع المقبرة'
                    },
                    'تم رفع المقبرة ✓'),
                icon: const Icon(Icons.restore_from_trash),
                label: const Text('رفع المقبرة')),
          if (controls['can_assign_global_role_this_target'] == true)
            OutlinedButton.icon(
                onPressed: () => _pickRole(context),
                icon: const Icon(Icons.upgrade),
                label: const Text('تعيين/ترقية')),
          if (controls['can_remove_roles_this_target'] == true && controls['role_id'] != null)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'remove_room_role',
                    {'p_room_id': rid, 'p_user_id': uid},
                    'تمت إزالة رتبة العضو ✓'),
                icon: const Icon(Icons.person_remove_alt_1),
                label: const Text('إزالة الرتبة')),
          if (controls['can_manage'] == true)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'grant_room_manager',
                    {'p_room_id': rid, 'p_user_id': uid},
                    'تم تعيين مدير الغرفة ✓'),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('تعيين مدير')),
          if (controls['can_manage'] == true)
            OutlinedButton.icon(
                onPressed: () => _adminCall(
                    context,
                    'revoke_room_manager',
                    {'p_room_id': rid, 'p_user_id': uid},
                    'تمت إزالة إدارة الغرفة ✓'),
                icon: const Icon(Icons.remove_moderator),
                label: const Text('إزالة مدير')),
          if (controls['can_edit_profile_this_target'] == true)
            OutlinedButton.icon(
                onPressed: () => _pickAndSetMemberAvatar(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('تغيير صورة العضو')),
        ]),
      ]),
    );
  }

  Future<void> _sendDiceChallenge(BuildContext context) async {
    final stake = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('تحدي النرد — اختر الرهان'),
        children: [
          for (final v in const [0, 10, 50, 100, 500, 1000])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, v),
              child: Text(v == 0 ? 'ودّي (بلا نقاط)' : '$v نقطة',
                  textDirection: TextDirection.rtl),
            ),
        ],
      ),
    );
    if (stake == null || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc('send_dice_challenge', params: {
        'p_to_uid': uid,
        'p_stake': stake,
        'p_room_id': roomId,
      });
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text(stake > 0
              ? 'تم إرسال تحدي النرد على $stake نقطة ✓'
              : 'تم إرسال تحدي النرد ✓')));
    } catch (e) {
      if (!context.mounted) return;
      final raw = e.toString();
      final msg = raw.contains('INSUFFICIENT_POINTS')
          ? 'رصيدك من النقاط لا يكفي لهذا الرهان.'
          : raw.contains('REQUEST_ALREADY_PENDING')
              ? 'لديك تحدٍّ معلّق لهذا العضو بالفعل.'
              : raw.contains('BLOCKED')
                  ? 'لا يمكن إرسال التحدي بسبب الحظر.'
                  : 'تعذّر إرسال التحدي.';
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _transferCurrency(
      BuildContext context, WidgetRef ref, String currency) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(currency == 'points' ? 'تحويل نقاط' : 'تحويل جواهر'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: currency == 'points' ? 'عدد النقاط' : 'عدد الجواهر',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !context.mounted) return;
    try {
      final rpc =
          currency == 'points' ? 'transfer_points' : 'transfer_gems_to_user';
      final result = await Supabase.instance.client.rpc(
        rpc,
        params: {
          'p_to_user_id': uid,
          'p_amount': amount,
          'p_idempotency_key': const Uuid().v4(),
          'p_room_id': roomId,
        },
      );
      if (result is! Map || result['ok'] != true) {
        throw StateError('لم يؤكد الخادم نجاح التحويل.');
      }
      if (!context.mounted) return;
      playServerSound('success');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تم التحويل بنجاح'),
          content: Text(
            'تم تحويل $amount ${currency == 'points' ? 'نقطة' : 'جوهرة'} إلى ${result['to_name'] ?? 'العضو'}، وتم تسجيل العملية خادميًا.\n\nالرصيد بعد التحويل: ${result['sender_balance'] ?? '—'}',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      ref.invalidate(profileByIdProvider(uid));
    } catch (e) {
      if (!context.mounted) return;
      var message = e.toString();
      if (message.contains('INSUFFICIENT_POINTS')) {
        message = 'رصيد النقاط غير كافٍ.';
      } else if (message.contains('INSUFFICIENT_GEMS')) {
        message = 'رصيد الجواهر غير كافٍ.';
      } else if (message.contains('INVALID_RECIPIENT')) {
        message = 'لا يمكن التحويل إلى هذا الحساب.';
      }
      playServerSound('error');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('فشل التحويل'),
          content: Text(message, textDirection: TextDirection.rtl),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showGamePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
              title: Text('اختر اللعبة'),
              subtitle: Text('سيصل للعضو طلب للقبول أو الرفض')),
          ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: const Text('لعبة النرد'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendDiceChallenge(context);
              }),
          for (final t in const ['connect4', 'rps', 'coin', 'trix_solo', 'trix_partner'])
            ListTile(
                leading: Text(
                    t == 'connect4'
                        ? '🔴'
                        : (t == 'rps' ? '✊' : (t == 'coin' ? '🪙' : '♠♥♦♣')),
                    style: TextStyle(fontSize: t.startsWith('trix_') ? 14 : 24)),
                title: Text(t.startsWith('trix_') ? gameTitle(t) : '${gameTitle(t)} (3D)'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final sent = await sendGameChallengeFlow(context,
                      toUid: uid, gameType: t, roomId: roomId);
                  if (sent && context.mounted) Navigator.of(context).pop();
                }),
        ]),
      ),
    );
  }

  Future<void> _showTransferPicker(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
              title: Text('تحويل إلى العضو'),
              subtitle: Text('التحويل يتم خادميًا مع التحقق من الرصيد')),
          ListTile(
              leading: const Icon(Icons.stars_rounded),
              title: const Text('تحويل نقاط'),
              onTap: () {
                Navigator.pop(sheetContext);
                _transferCurrency(context, ref, 'points');
              }),
          ListTile(
              leading: const Icon(Icons.diamond_rounded),
              title: const Text('تحويل جواهر'),
              onTap: () {
                Navigator.pop(sheetContext);
                _transferCurrency(context, ref, 'gems');
              }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(uid));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: profileAsync.when(
          loading: () => const SizedBox(
              height: 220, child: Center(child: CircularProgressIndicator())),
          // A hidden profile is an EXPECTED outcome of the paid "hide profile"
          // feature, not a crash. It used to surface the raw StateError text
          // ("Bad state: ...") straight to the viewer, which looked like the
          // app was broken. It is now reported to the error monitor for the
          // owner and shown as a plain explanation to the viewer.
          error: (e, st) {
            unawaited(ErrorMonitor.report(
              e,
              stack: st,
              screen: 'mini_profile_popup',
              source: 'profile_by_id',
              severity: 'warning',
            ));
            final raw = e.toString();
            final hidden = raw.contains('PROFILE_NOT_FOUND') ||
                raw.contains('not found') ||
                raw.contains('Bad state');
            return SizedBox(
              height: 140,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(hidden ? Icons.visibility_off_outlined : Icons.error_outline,
                          color: AppColors.textSecondary, size: 30),
                      const SizedBox(height: 8),
                      Text(
                        hidden
                            ? 'هذا العضو أخفى ملفه الشخصي.'
                            : 'تعذّر تحميل الملف حاليًا.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          data: (profile) {
            if (profile == null) {
              return const SizedBox(
                  height: 120, child: Center(child: Text('العضو غير موجود')));
            }
            return SingleChildScrollView(
              primary: false,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: profile.coverUrl != null &&
                            profile.coverUrl!.isNotEmpty
                        ? Image.network(profile.coverUrl!, fit: BoxFit.cover)
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color(0xFF3B2850),
                                Color(0xFF7E0BB8)
                              ]),
                            ),
                          ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: ProfileAvatar(
                      avatarUrl: profile.avatarUrl,
                      animatedAvatarUrl: profile.animatedAvatarUrl,
                      displayName: profile.displayName,
                      radius: 34,
                      frameKey: profile.avatarFrameKey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 16),
                    child: Column(
                      children: [
                        ServerUsernameDisplay(
                          uid: uid,
                          roomId: roomId,
                          fallbackName: profile.displayName,
                          fallbackFontSize:
                              profile.usernameFontSize.clamp(8, 30).toDouble(),
                          showBadges: true,
                          showAchievements: true,
                          compactBadges: false,
                          center: true,
                          showTitle: true,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('الملف الكامل'),
                                  onPressed: () {
                                    Navigator.of(context).pop('full_profile');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Primary action: open the FLOATING window so the
                              // room stays visible behind it.
                              if (myUid != null && myUid != profile.uid)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.chat_bubble_outline,
                                        size: 18),
                                    label: const Text('مراسلة'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      final threadId = _threadIdFor(myUid, profile.uid);
                                      // Manually reopening clears any earlier
                                      // dismissal, so future messages in THIS
                                      // thread can auto-float again.
                                      ref
                                          .read(dismissedThreadIdsProvider.notifier)
                                          .update((s) => {...s}..remove(threadId));
                                      ref
                                          .read(miniChatTargetProvider.notifier)
                                          .state = MiniChatTarget(
                                        threadId: threadId,
                                        peerUid: profile.uid,
                                        peerName: profile.displayName,
                                        peerAvatar: profile.avatarUrl,
                                      );
                                      ref
                                          .read(miniChatModeProvider.notifier)
                                          .state = MiniChatMode.normal;
                                    },
                                  ),
                                ),
                              // Secondary action: the classic full page, kept
                              // for anyone who prefers the whole screen.
                              // أُزيل زر "فتح بملء الشاشة": المراسلة الخاصة
                              // تظهر حصرًا كنافذة عائمة بطلب صريح، فلم يعد
                              // لفتحها كصفحة كاملة أي مسار في التطبيق.
                            ],
                          ),
                        ),
                        if (roomId != null && myUid != profile.uid)
                          FutureBuilder<Map<String, dynamic>>(
                            future: Supabase.instance.client
                                .rpc('get_room_member_admin_context', params: {
                                  'p_room_id': roomId,
                                  'p_user_id': profile.uid
                                })
                                .then((v) => v is Map
                                    ? Map<String, dynamic>.from(v)
                                    : <String, dynamic>{})
                                .catchError((_) => <String, dynamic>{}),
                            builder: (context, snap) {
                              final data =
                                  snap.data ?? const <String, dynamic>{};
                              final actor = data['actor'] is Map
                                  ? Map<String, dynamic>.from(data['actor'])
                                  : const <String, dynamic>{};
                              final target = data['target'] is Map
                                  ? Map<String, dynamic>.from(data['target'])
                                  : const <String, dynamic>{};
                              return _adminSection(context, {
                                ...actor,
                                ...target,
                                // كانت can_ban/can_kick/... تُقرأ من actor
                                // العامة مباشرة، بلا أي مقارنة بأولوية هذا
                                // الهدف تحديدًا — الآن الأعلام المستخدَمة هي
                                // نسخة "لهذا الهدف" التي يحسمها الخادم نفسه
                                // (outranks_target)، فلا يظهر أي خيار إدارة
                                // ضد شخص أعلى رتبة إطلاقًا.
                                'can_ban': actor['can_ban_this_target'] == true,
                                'can_unban': actor['can_unban_this_target'] == true,
                                'can_kick': actor['can_kick_this_target'] == true,
                                'can_unkick': actor['can_unkick_this_target'] == true,
                                'can_mute': actor['can_mute_this_target'] == true,
                                'can_unmute': actor['can_unmute_this_target'] == true,
                                'can_assign_roles': actor['can_assign_roles_this_target'] == true,
                                'can_edit_profiles': actor['can_edit_profile_this_target'] == true,
                                'can_manage':
                                    actor['can_manage_room'] == true ||
                                        data['is_dragon'] == true,
                                'can_moderate': actor['can_kick'] == true ||
                                    actor['can_mute'] == true ||
                                    actor['can_ban'] == true ||
                                    actor['can_unban'] == true ||
                                    actor['can_unmute'] == true ||
                                    data['is_dragon'] == true,
                                'can_roles':
                                    actor['can_manage_members'] == true ||
                                        actor['can_assign_roles'] == true ||
                                        actor['can_roles'] == true ||
                                        data['is_dragon'] == true,
                                'is_dragon': data['is_dragon'] == true,
                              });
                            },
                          ),
                        if (myUid != null && myUid != profile.uid) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FriendButton(
                                myUid: myUid, targetUid: profile.uid),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [
                              Expanded(
                                  child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: AppColors.background),
                                icon: const Icon(Icons.card_giftcard, size: 18),
                                label: const Text('هدايا'),
                                onPressed: () => GiftPickerSheet.show(context,
                                    (gift) => _sendGift(context, ref, gift)),
                              )),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: OutlinedButton.icon(
                                icon: const Icon(Icons.sports_esports_outlined,
                                    size: 18),
                                label: const Text('طلب لعبة'),
                                onPressed: () => _showGamePicker(context),
                              )),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 18),
                                  label: const Text('تحويل نقاط أو جواهر'),
                                  onPressed: () =>
                                      _showTransferPicker(context, ref),
                                )),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
