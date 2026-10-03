import 'package:audioplayers/audioplayers.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../friends/presentation/pages/friends_list_page.dart';
import '../../../gamification/presentation/pages/points_gems_exchange_page.dart';
import '../../../social_graph/presentation/pages/blocked_users_page.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/profile_storage_cleanup.dart';
import '../providers/profile_provider.dart';
import '../widgets/account_setting_tiles.dart';
import '../widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../widgets/avatar_frame_picker_sheet.dart';
import '../widgets/arabic_font_catalog.dart';
import 'account_security_page.dart';
import 'dice_game_settings_page.dart';
import 'edit_my_info_page.dart';
import 'language_location_page.dart';
import 'style_settings_page.dart';

/// شاشة "الإعدادات" الموحّدة — تجمع كل عناصر البند (س) من مواصفة
/// التعديلات: قائمة خيارات التعديل السريعة أعلى الصفحة، ثم قائمتا
/// الإعدادات (العلوية والسفلية) كما وردتا حرفيًا في المواصفة. كل
/// عنصر إمّا يُحرَّر مباشرة هنا عبر [ProfileController.updateProfile]
/// (للحقول المرتبطة بكيان الملف الشخصي)، أو عبر [AccountSettingsStore]
/// المباشر (لتفضيلات بسيطة لا تستحق حقلًا في الكيان)، أو يفتح شاشة
/// فرعية مخصَّصة موجودة مسبقًا في المشروع.
class AccountSettingsPage extends StatelessWidget {
  final ProfileEntity profile;
  const AccountSettingsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: AccountSettingsContent(profile: profile),
    );
  }
}

class AccountSettingsContent extends ConsumerWidget {
  final ProfileEntity profile;
  final bool embedded;
  const AccountSettingsContent(
      {super.key, required this.profile, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // نراقب البروفايل الحيّ (لا النسخة الثابتة الممرَّرة) بحيث تنعكس
    // أي تعديلات فورًا على العناصر الفرعية (subtitle) دون إعادة فتح
    // الشاشة.
    final liveProfile =
        ref.watch(currentProfileProvider).valueOrNull ?? profile;
    final uid = liveProfile.uid;

    Future<bool> save(ProfileEntity updated) async {
      final ok = await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(updated);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل حفظ التعديل')));
      }
      return ok;
    }

    final children = <Widget>[
      if (!embedded) ...[
        const SizedBox(height: 8),
        Center(
          child: ProfileAvatar(
            avatarUrl: liveProfile.avatarUrl,
            animatedAvatarUrl: liveProfile.animatedAvatarUrl,
            userId: liveProfile.uid,
            displayName: liveProfile.displayName,
            radius: 36,
            frameKey: liveProfile.avatarFrameKey,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ServerUsernameDisplay(
            uid: uid,
            fallbackName: liveProfile.displayName,
            fallbackFontSize: liveProfile.usernameFontSize,
            showBadges: true,
            showAchievements: true,
            compactBadges: false,
            center: true,
          ),
        ),
        const SizedBox(height: 20),
      ],
      const _SectionHeader('قائمة الإعدادات'),
      TextInputSettingTile(
        icon: Icons.badge_outlined,
        title: 'تغير اسم المستخدم',
        currentValueLabel: liveProfile.displayName,
        initialValue: liveProfile.displayName,
        dialogLabel: 'اسم المستخدم الجديد',
        onSave: (value) => save(liveProfile.copyWith(displayName: value)),
      ),
      ListTile(
        leading: const Icon(Icons.palette_outlined, color: AppColors.gold),
        title: const Text('تغير لون اسم المستخدم'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: liveProfile.usernameColor != null
                    ? Color(liveProfile.usernameColor!)
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left, color: AppColors.textMuted),
          ],
        ),
        onTap: () async {
          final color =
              await showColorSwatchPicker(context, 'تغير لون اسم المستخدم');
          if (color == null) return;
          await save(liveProfile.copyWith(usernameColor: color.toARGB32()));
        },
      ),
      TextInputSettingTile(
        icon: Icons.emoji_emotions_outlined,
        title: 'تعديل الحالة',
        currentValueLabel: liveProfile.statusText,
        initialValue: liveProfile.statusText ?? '',
        dialogLabel: 'نص الحالة',
        onSave: (value) => save(liveProfile.copyWith(statusText: value)),
      ),
      ListTile(
        leading:
            const Icon(Icons.format_color_text_outlined, color: AppColors.gold),
        title: const Text('تنسيق الحالة'),
        subtitle: Text(
          [
            if (liveProfile.statusBold) 'عريض',
            if (liveProfile.statusItalic) 'مائل',
          ].join(' + ').isEmpty
              ? 'افتراضي'
              : [
                  if (liveProfile.statusBold) 'عريض',
                  if (liveProfile.statusItalic) 'مائل',
                ].join(' + '),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => _openStatusFormatDialog(context, liveProfile, save),
      ),
      _UsernameFontSizeControl(
        value: liveProfile.usernameFontSize,
        onSave: (v) async {
          // Use the same authoritative profile-update path as the other
          // typography settings so username_font_size is persisted in
          // profiles and immediately re-read by the chat identity provider.
          return save(liveProfile.copyWith(usernameFontSize: v));
        },
      ),
      _ArabicFontTile(
        title: 'خط اسم المستخدم',
        value: liveProfile.usernameFontFamily,
        onChanged: (value) async {
          final ok = await ref.read(profileControllerProvider.notifier).updateTypography(
            usernameFontFamily: value,
            messageFontFamily: liveProfile.messageFontFamily,
          );
          if (ok && context.mounted) {
            ref.invalidate(currentProfileProvider);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق خط الاسم فورًا على الملف والشات')));
          }
        },
      ),
      _ArabicFontTile(
        title: 'خط الرسائل والحالة',
        value: liveProfile.messageFontFamily,
        onChanged: (value) async {
          final ok = await ref.read(profileControllerProvider.notifier).updateTypography(
            usernameFontFamily: liveProfile.usernameFontFamily,
            messageFontFamily: value,
          );
          if (ok && context.mounted) {
            ref.invalidate(currentProfileProvider);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق خط الرسائل فورًا')));
          }
        },
      ),
      _ProfileSliderTile(
        icon: Icons.text_fields_rounded,
        title: 'حجم خط الحالة',
        min: 10,
        max: 22,
        value: liveProfile.statusFontSize,
        valueText: liveProfile.statusFontSize.toStringAsFixed(1),
        onChanged: (v) => save(liveProfile.copyWith(statusFontSize: v)),
      ),
      _AnimatedAvatarTile(profile: liveProfile, onSave: save),
      ListTile(
        leading: const Icon(Icons.filter_frames_rounded, color: AppColors.gold),
        title: const Text('إطار الصورة المتحرك'),
        subtitle: Text(
          liveProfile.avatarFrameKey == null ? 'اختر إطارًا فاخرًا متحركًا' : 'الإطار الحالي: ${liveProfile.avatarFrameKey}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => AvatarFramePickerSheet.show(context, uid),
      ),
      ProfileMusicTile(
        profile: liveProfile,
        onSave: save,
      ),
      ListTile(
        leading: const Icon(Icons.visibility_outlined, color: AppColors.gold),
        title: const Text('خصوصية الحساب'),
        subtitle: Text(
          switch (liveProfile.visibility) {
            ProfileVisibility.public => 'عام — يظهر ملفك للجميع',
            ProfileVisibility.friends => 'الأصدقاء فقط — يظهر لمن تقبلهم كصديق',
            ProfileVisibility.private => 'خاص — ملفك محدود الظهور',
          },
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () async {
          final selected =
              await _chooseProfileVisibility(context, liveProfile.visibility);
          if (selected != null) {
            await save(liveProfile.copyWith(visibility: selected));
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.category_outlined, color: AppColors.gold),
        title: const Text('نوع الحساب'),
        subtitle: Text(_accountTypeLabel(liveProfile.accountType),
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () async {
          final selected =
              await _chooseAccountType(context, liveProfile.accountType);
          if (selected != null) {
            await save(liveProfile.copyWith(accountType: selected));
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.contact_page_outlined, color: AppColors.gold),
        title: const Text('تحرير معلوماتي'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EditMyInfoPage(profile: liveProfile))),
      ),
      ListTile(
        leading: const Icon(Icons.casino_outlined, color: AppColors.gold),
        title: const Text('تهيئة لعبة النرد'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DiceGameSettingsPage(uid: uid))),
      ),
      ListTile(
        leading: const Icon(Icons.currency_exchange, color: AppColors.gold),
        title: const Text('تحويل نقاط الزد (لجواهر)'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                const PointsGemsExchangePage(startWithPointsToGems: true))),
      ),
      AccountChoiceSettingTile(
        uid: uid,
        field: 'speakRequestVisibility',
        icon: Icons.mic_none_outlined,
        title: 'اعدادات طلبات التحدث',
      ),
      AccountChoiceSettingTile(
        uid: uid,
        field: 'privateMessageVisibility',
        icon: Icons.mark_email_unread_outlined,
        title: 'اعدادات الرسائل الخاصة',
      ),
      AccountChoiceSettingTile(
        uid: uid,
        field: 'pointsVisibility',
        icon: Icons.visibility_outlined,
        title: 'من يمكنه رؤية نقاطي؟',
      ),
      const Divider(color: AppColors.divider, height: 32),
      const _SectionHeader('الإعدادات والخصوصية'),
      ListTile(
        leading: const Icon(Icons.currency_exchange, color: AppColors.gold),
        title: const Text('تحويل الجواهر (لنقاط الزد)'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                const PointsGemsExchangePage(startWithPointsToGems: false))),
      ),
      AccountChoiceSettingTile(
        uid: uid,
        field: 'friendsVisibility',
        icon: Icons.people_outline,
        title: 'من يمكنه رؤية اصدقائي؟',
      ),
      ListTile(
        leading: const Icon(Icons.group_outlined, color: AppColors.gold),
        title: const Text('إدارة أصدقاء'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FriendsListPage())),
      ),
      ListTile(
        leading: const Icon(Icons.block_outlined, color: AppColors.gold),
        title: const Text('إدارة التجاهل (قائمة الحظر)'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BlockedUsersPage())),
      ),
      AccountSwitchSettingTile(
        uid: uid,
        field: 'messageSoundEnabled',
        icon: Icons.volume_up_outlined,
        title: 'صوت الرسائل',
        subtitle: 'تنبيه صوتي عند وصول رسالة جديدة',
        defaultValue: true,
      ),
      AccountSwitchSettingTile(
        uid: uid,
        field: 'notificationSoundEnabled',
        icon: Icons.notifications_active_outlined,
        title: 'صوت الإشعارات',
        subtitle: 'تنبيه صوتي للإشعارات العامة',
        defaultValue: true,
      ),
      ListTile(
        leading: const Icon(Icons.style_outlined, color: AppColors.gold),
        title: const Text('إعدادات الستايل'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StyleSettingsPage(uid: uid))),
      ),
      ListTile(
        leading: const Icon(Icons.language_outlined, color: AppColors.gold),
        title: const Text('اللغة / الموقع'),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LanguageLocationPage(uid: uid))),
      ),
      ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined,
            color: AppColors.gold),
        title: const Text('أمان الحساب'),
        subtitle: const Text(
          'البريد، كلمة المرور، ربط Google، حذف العضوية',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AccountSecurityPage(profile: liveProfile))),
      ),
      const SizedBox(height: 24),
    ];
    return embedded
        ? Column(children: children)
        : ListView(padding: const EdgeInsets.only(top: 8), children: children);
  }

  Future<void> _openStatusFormatDialog(
    BuildContext context,
    ProfileEntity profile,
    Future<bool> Function(ProfileEntity) save,
  ) async {
    bool bold = profile.statusBold;
    bool italic = profile.statusItalic;
    Color? color =
        profile.statusColor != null ? Color(profile.statusColor!) : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('تنسيق الحالة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('عريض'),
                value: bold,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => bold = v),
              ),
              SwitchListTile(
                title: const Text('مائل'),
                value: italic,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => italic = v),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('لون النص'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kProfileColorSwatches
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color?.toARGB32() == c.toARGB32()
                                    ? Colors.white
                                    : AppColors.divider,
                                width:
                                    color?.toARGB32() == c.toARGB32() ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await save(profile.copyWith(
                  statusBold: bold,
                  statusItalic: italic,
                  statusColor: color?.toARGB32(),
                ));
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<ProfileVisibility?> _chooseProfileVisibility(
  BuildContext context,
  ProfileVisibility current,
) async {
  return showDialog<ProfileVisibility>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('خصوصية الحساب'),
      content: SegmentedButton<ProfileVisibility>(
        segments: const [
          ButtonSegment(
              value: ProfileVisibility.public,
              label: Text('عام'),
              icon: Icon(Icons.public)),
          ButtonSegment(
              value: ProfileVisibility.friends,
              label: Text('الأصدقاء'),
              icon: Icon(Icons.people_outline)),
          ButtonSegment(
              value: ProfileVisibility.private,
              label: Text('خاص'),
              icon: Icon(Icons.lock_outline)),
        ],
        selected: {current},
        onSelectionChanged: (value) => Navigator.of(context).pop(value.first),
      ),
    ),
  );
}

String _accountTypeLabel(AccountType type) => switch (type) {
      AccountType.individual => 'فردي',
      AccountType.business => 'تجاري',
      AccountType.workshop => 'ورشة',
      AccountType.factory => 'مصنع',
      AccountType.supplier => 'مورد',
      AccountType.store => 'متجر',
      AccountType.designer => 'مصمم / مصممة',
      AccountType.serviceProvider => 'مقدم خدمة',
    };

Future<AccountType?> _chooseAccountType(
  BuildContext context,
  AccountType current,
) async {
  return showModalBottomSheet<AccountType>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: RadioGroup<AccountType>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: ListView(
          shrinkWrap: true,
          children: AccountType.values.map((type) {
            return RadioListTile<AccountType>(
              value: type,
              title: Text(_accountTypeLabel(type)),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

class ProfileMusicTile extends StatefulWidget {
  final ProfileEntity profile;
  final Future<bool> Function(ProfileEntity) onSave;
  const ProfileMusicTile(
      {super.key, required this.profile, required this.onSave});

  @override
  State<ProfileMusicTile> createState() => _ProfileMusicTileState();
}

class _ProfileMusicTileState extends State<ProfileMusicTile> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'aac'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _show('فشل قراءة الملف الصوتي.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _show('حجم موسيقى الملف الشخصي يجب ألا يتجاوز 5 MB.');
      return;
    }
    if (!mounted) return;
    // The State is checked immediately before opening the dialog; this is a safe UI boundary.
    // ignore: use_build_context_synchronously
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد رفع موسيقى البروفايل'),
        content: Text('الملف: ${file.name}\nالمدة: 15 ثانية كحد أقصى\n\nهل تريد رفعه وحفظه؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد الرفع')),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final durationMs = await _measureDurationMs(bytes);
      // كان الصفر (مدة لم تُقرأ) يُعامل كأنه "أطول من 15 ثانية" فيُرفض الملف
      // برسالة مضلِّلة. صار لكل حالة رسالتها.
      if (durationMs <= 0) {
        throw const FormatException('PROFILE_MUSIC_UNREADABLE');
      }
      if (durationMs > 15000) {
        throw const FormatException('PROFILE_MUSIC_TOO_LONG');
      }
      final uid = widget.profile.uid;
      final url = await MediaUploadService(bucket: 'profile-music').uploadBytes(
        bytes: bytes,
        fileName: file.name,
        folder: uid,
        uid: uid,
      );
      final saved = await widget.onSave(widget.profile.copyWith(
        profileMusicUrl: url,
        profileMusicDurationMs: durationMs,
        profileMusicSizeBytes: bytes.length,
      ));
      if (!saved) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-music',
            publicUrl: url,
          );
        } catch (_) {}
        throw StateError('PROFILE_MUSIC_SAVE_FAILED');
      }
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-music',
          publicUrl: widget.profile.profileMusicUrl,
        );
      } catch (_) {}
      _show('تم رفع موسيقى البروفايل بنجاح ✓');
    } catch (e) {
      final t = e.toString();
      _show(t.contains('PROFILE_MUSIC_TOO_LONG')
          ? 'المقطع يجب ألا يتجاوز 15 ثانية.'
          : t.contains('PROFILE_MUSIC_UNREADABLE')
              ? 'تعذّرت قراءة مدة الملف. جرّب ملف MP3 أو WAV.'
              : 'فشل رفع موسيقى البروفايل: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// AudioMeta تُرجع صفرًا لكثير من الصيغ (M4A/AAC وMP3 بمعدل بت متغير)،
  /// فنقيس احتياطيًا بمشغّل الصوت نفسه الذي سيُشغّل المقطع لاحقًا.
  Future<int> _measureDurationMs(List<int> bytes) async {
    try {
      final d = (AudioMeta(Uint8List.fromList(bytes)).durationInSeconds * 1000)
          .round();
      if (d > 0) return d;
    } catch (_) {}
    final player = AudioPlayer();
    try {
      await player.setSource(BytesSource(Uint8List.fromList(bytes)));
      final d =
          await player.getDuration().timeout(const Duration(seconds: 6));
      return d?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      await player.dispose();
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      final oldUrl = widget.profile.profileMusicUrl;
      final saved = await widget.onSave(widget.profile.copyWith(
        profileMusicUrl: '',
        profileMusicDurationMs: 0,
        profileMusicSizeBytes: 0,
      ));
      if (!saved) {
        throw StateError('PROFILE_MUSIC_DELETE_SAVE_FAILED');
      }
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-music',
          publicUrl: oldUrl,
        );
      } catch (_) {}
      _show('تم حذف موسيقى البروفايل.');
    } catch (e) {
      _show('فشل حذف موسيقى البروفايل: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.profile.profileMusicUrl != null &&
        widget.profile.profileMusicUrl!.isNotEmpty;
    final duration = widget.profile.profileMusicDurationMs;
    final durationLabel = duration != null && duration > 0
        ? ' • ${(duration / 1000).toStringAsFixed(1)} ث'
        : '';
    return ListTile(
      leading: const Icon(Icons.music_note_outlined, color: AppColors.gold),
      title: const Text('موسيقى الملف الشخصي'),
      subtitle: Text(
        _busy
            ? 'جارٍ الرفع...'
            : (active
                ? 'مقطع صوتي مفعّل$durationLabel • حد 15 ثانية / 5 MB'
                : 'ارفع MP3 / WAV / OGG / AAC حتى 15 ثانية'),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      onPressed: _remove,
                      tooltip: 'حذف'),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
      onTap: _busy ? null : _pickAndUpload,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// مفتاح تشغيل/إيقاف يكتب مباشرة عبر [ProfileController] بدل الكتابة
/// المباشرة في مستند الحساب — تحديدًا لأن هذا الحقل جزء من
/// [ProfileEntity] نفسه (وليس تفضيلًا خفيفًا منفصلًا)، فيمر عبر نفس
/// مسار التحقق من الصلاحيات الذي يمر عبره أي تعديل آخر للملف
/// الشخصي.
class _UsernameFontSizeControl extends StatefulWidget {
  final double value;
  final Future<bool> Function(double value) onSave;

  const _UsernameFontSizeControl({
    required this.value,
    required this.onSave,
  });

  @override
  State<_UsernameFontSizeControl> createState() => _UsernameFontSizeControlState();
}

class _UsernameFontSizeControlState extends State<_UsernameFontSizeControl> {
  late double _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.value.clamp(14.0, 34.0).toDouble();
  }

  @override
  void didUpdateWidget(covariant _UsernameFontSizeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_saving) {
      _draft = widget.value.clamp(14.0, 34.0).toDouble();
    }
  }

  Future<void> _commit(double value) async {
    final next = value.clamp(14.0, 34.0).toDouble();
    if (_saving || next == _draft) return;
    final previous = _draft;
    setState(() {
      _draft = next;
      _saving = true;
    });
    final ok = await widget.onSave(next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _draft = previous;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _draft.clamp(14.0, 34.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.format_size_rounded, color: AppColors.gold),
                const SizedBox(width: 10),
                const Expanded(child: Text('حجم اسم المستخدم')),
                if (_saving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Text('${current.toStringAsFixed(0)} px'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  tooltip: 'تصغير الخط',
                  onPressed: _saving || current <= 14
                      ? null
                      : () => _commit(current - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Slider(
                    min: 14,
                    max: 34,
                    divisions: 20,
                    value: current,
                    label: '${current.toStringAsFixed(0)} px',
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _draft = v),
                    onChangeEnd: _saving ? null : (v) => _commit(v),
                  ),
                ),
                IconButton(
                  tooltip: 'تكبير الخط',
                  onPressed: _saving || current >= 34
                      ? null
                      : () => _commit(current + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const Text(
              'الافتراضي: 22 px — التصغير حتى 14 px والتكبير حتى 34 px. يحفظ بعد انتهاء السحب.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double min;
  final double max;
  final double value;
  final String valueText;
  final ValueChanged<double> onChanged;

  const _ProfileSliderTile({
    required this.icon,
    required this.title,
    required this.min,
    required this.max,
    required this.value,
    required this.valueText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(title),
      subtitle: Text(
        'الحجم الحالي: $valueText',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(valueText,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      onTap: () async {
        var draft = value.clamp(min, max);
        final saved = await showDialog<double>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(draft.toStringAsFixed(1)),
                  Slider(
                    value: draft,
                    min: min,
                    max: max,
                    divisions: ((max - min) * 2).round(),
                    label: draft.toStringAsFixed(1),
                    onChanged: (v) => setState(() => draft = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, draft),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
        );
        if (saved != null) onChanged(saved);
      },
    );
  }
}

/// عنصر "صورة متحركة للملف الشخصي" — يفتح منتقي صور (GIF مدعوم ضمن
/// أنواع الصور نفسها)، يرفعه لنفس مجلد الصور الرمزية، ثم يحفظ الرابط
/// في animatedAvatarUrl. يعرض أيضًا خيار الإزالة إن كانت مُفعَّلة.
class _ArabicFontTile extends StatelessWidget {
  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  const _ArabicFontTile({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = arabicFontOption(value);
    return ListTile(
      leading: const Icon(Icons.font_download_rounded, color: AppColors.gold),
      title: Text(title),
      subtitle: Text(current.nameAr, style: current.style(size: 13, weight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              children: [
                const ListTile(title: Text('اختر خطًا عربيًا', textAlign: TextAlign.center)),
                ...kArabicFontOptions.map((option) => ListTile(
                  title: Text(option.nameAr, textAlign: TextAlign.right, style: option.style(size: 18)),
                  subtitle: Text('هذا مثال مباشر', textAlign: TextAlign.right, style: option.style(size: 13, weight: FontWeight.w500)),
                  trailing: option.key == value ? const Icon(Icons.check_circle, color: AppColors.gold) : null,
                  onTap: () => Navigator.pop(sheetContext, option.key),
                )),
              ],
            ),
          ),
        );
        if (selected != null && selected != value) onChanged(selected);
      },
    );
  }
}

class _AnimatedAvatarTile extends StatefulWidget {
  final ProfileEntity profile;
  final Future<bool> Function(ProfileEntity) onSave;
  const _AnimatedAvatarTile({required this.profile, required this.onSave});

  @override
  State<_AnimatedAvatarTile> createState() => _AnimatedAvatarTileState();
}

class _AnimatedAvatarTileState extends State<_AnimatedAvatarTile> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ملف GIF فارغ أو غير قابل للقراءة')));
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frames = codec.frameCount;
      codec.dispose();
      if (frames < 2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر GIF متحركًا يحتوي على إطارين أو أكثر.')));
        return;
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل قراءة ملف GIF.')));
      return;
    }
    if (!mounted) return;
    // The State is checked immediately before opening the dialog; this is a safe UI boundary.
    // ignore: use_build_context_synchronously
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد رفع الصورة المتحركة'),
        content: Text('الملف: ${file.name}\n\nسيتم استبدال الصورة المتحركة الحالية. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد الرفع')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await MediaUploadService(bucket: 'profile-avatars').uploadBytes(
        bytes: bytes,
        fileName: file.name,
        folder: widget.profile.uid,
        uid: widget.profile.uid,
      );
      final saved = await widget.onSave(widget.profile.copyWith(animatedAvatarUrl: url));
      if (!saved) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-avatars',
            publicUrl: url,
          );
        } catch (_) {}
        throw StateError('ANIMATED_AVATAR_SAVE_FAILED');
      }
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-avatars',
          publicUrl: widget.profile.animatedAvatarUrl,
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل رفع GIF المتحرك: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final oldUrl = widget.profile.animatedAvatarUrl;
    setState(() => _busy = true);
    try {
      final saved = await widget.onSave(widget.profile.copyWith(animatedAvatarUrl: ''));
      if (!saved) {
        throw StateError('ANIMATED_AVATAR_REMOVE_SAVE_FAILED');
      }
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-avatars',
          publicUrl: oldUrl,
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إزالة GIF المتحرك: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.profile.animatedAvatarUrl != null &&
        widget.profile.animatedAvatarUrl!.isNotEmpty;
    return ListTile(
      leading: const Icon(Icons.image_outlined, color: AppColors.gold),
      title: const Text('صورة متحركة للملف الشخصي'),
      subtitle: Text(
        _busy ? 'جارٍ الرفع...' : (active ? 'مُفعَّلة' : 'غير مُفعَّلة'),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: _remove,
                    tooltip: 'إزالة',
                  ),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
      onTap: _busy ? null : _pickAndUpload,
    );
  }
}
