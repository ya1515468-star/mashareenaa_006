import 'package:mashareena/core/utils/safe_launch.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/embedded_media_player.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../feedback/presentation/submit_feedback_page.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../../gamification/presentation/widgets/mystery_spin_dialog.dart';
import '../../../rbac/presentation/widgets/server_chat_badge_above_name.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../store/domain/entities/store_item_entity.dart';
import '../../../store/domain/equipped_items_service.dart';
import '../../../store/presentation/store_features_tab.dart';
import '../../../store/presentation/widgets/store_effect_engines.dart';
import '../../../subscriptions/domain/entities/subscription_tier_entity.dart';
import '../../../subscriptions/presentation/pages/subscriptions_page.dart';
import '../../../subscriptions/presentation/providers/subscription_provider.dart';
import '../../../subscriptions/presentation/widgets/appear_offline_toggle.dart';
import '../../../subscriptions/presentation/widgets/membership_badge_widget.dart';
import '../../../subscriptions/presentation/widgets/membership_countdown_chip.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/profile_storage_cleanup.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/manual_avatar_cropper.dart';
import 'account_settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'تعذر تحميل الملف الشخصي الآن. تحقق من الاتصال ثم أعد المحاولة.'),
        data: (profile) {
          if (profile == null) {
            // سبب حقيقي خلف شكوى "زر الخروج يُظهر هذه الرسالة": عند
            // الضغط على تسجيل الخروج تُمسح الجلسة فورًا، وcurrentProfileProvider
            // يُرجع null حتمًا بلا مستخدم مسجَّل (هذا سلوكه المقصود)، لكن
            // هذه الصفحة بقيت مرسومة لحظيًا قبل أن يُعيد موجّه التطبيق
            // التوجيه لشاشة الدخول، فتظهر رسالة "لم يُعثر على الملف
            // الشخصي" المُخيفة في لحظة خروج ناجح تمامًا، لا عطل فعلي.
            // التمييز هنا بين "لا مستخدم مسجَّل أصلًا" (طبيعي، ريثما
            // يُعاد التوجيه) و"مستخدم مسجَّل لكن بلا صف ملف شخصي" (عطل
            // حقيقي يستحق الرسالة).
            final signedIn = ref.watch(authControllerProvider).valueOrNull != null;
            if (!signedIn) {
              return const LoadingIndicator();
            }
            return const ErrorView(message: 'لم يتم العثور على الملف الشخصي');
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // الغلاف العلوي + الصورة الشخصية فوقه متراكبة، ثم رمز
                // الرتبة واسمها بخط صغير أنيق أسفل الصورة مباشرة —
                // تمامًا كما في المواصفة. إن لم توجد صورة غلاف
                // ومُجهَّزة خلفية متحركة من المتجر، تُعرض بدلًا من
                // اللون الثابت.
                GestureDetector(
                  onTap: () => _pickAndUploadProfileImage(context, ref, profile,
                      cover: true),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        (_safeHttpUrl(profile.coverUrl) != null)
                            ? Image.network(
                                _safeHttpUrl(profile.coverUrl)!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: AppColors.surface),
                              )
                            : Consumer(
                                builder: (context, ref, _) {
                                  final equipped = ref
                                          .watch(equippedItemsProvider(
                                              profile.uid))
                                          .valueOrNull ??
                                      {};
                                  final bgItemId = equipped[StoreItemCategory
                                      .animatedBackground.wire];
                                  if (bgItemId == null) {
                                    return const ColoredBox(
                                        color: AppColors.surface);
                                  }
                                  final catalogAsync =
                                      ref.watch(storeCatalogProvider);
                                  StoreItemEntity? item;
                                  for (final i in catalogAsync.valueOrNull ??
                                      const <StoreItemEntity>[]) {
                                    if (i.id == bgItemId) {
                                      item = i;
                                      break;
                                    }
                                  }
                                  if (item == null) {
                                    return const ColoredBox(
                                        color: AppColors.surface);
                                  }
                                  return AnimatedGradientBackgroundGeneric(
                                      colors: item.colors);
                                },
                              ),
                        const Positioned(
                          left: 12,
                          bottom: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.camera_alt_outlined, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: GestureDetector(
                    onTap: () => _pickAndUploadProfileImage(
                        context, ref, profile,
                        cover: false),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final equipped = ref
                                    .watch(equippedItemsProvider(profile.uid))
                                    .valueOrNull ??
                                {};
                            final equippedFrameId =
                                equipped[StoreItemCategory.avatarFrame.wire];

                            // إطار المتجر المُشترى (البسيط الملوّن) له الأولوية
                            // فقط إن لم يكن هناك إطار فني حديث (avatarFrameKey)
                            // مُفعَّلًا؛ غير ذلك يظهر الإطاران معًا (الدائرة
                            // الملونة القديمة خلف الإطار الفني الجديد).
                            final hasModernFrame = profile.avatarFrameKey != null &&
                                profile.avatarFrameKey!.trim().isNotEmpty;
                            if (equippedFrameId != null && !hasModernFrame) {
                              final catalogAsync =
                                  ref.watch(storeCatalogProvider);
                              StoreItemEntity? item;
                              for (final i in catalogAsync.valueOrNull ??
                                  const <StoreItemEntity>[]) {
                                if (i.id == equippedFrameId) {
                                  item = i;
                                  break;
                                }
                              }
                              if (item != null) {
                                return StoreAvatarFrame(
                                  colors: item.colors,
                                  child: ProfileAvatar(
                                    avatarUrl: _safeHttpUrl(profile.avatarUrl),
                                    animatedAvatarUrl:
                                        _safeHttpUrl(profile.animatedAvatarUrl),
                                    displayName: profile.displayName,
                                    radius: 48,
                                    frameScale: 1.0,
                                    userId: profile.uid,
                                    frameKey: profile.avatarFrameKey,
                                  ),
                                );
                              }
                            }

                            return ProfileAvatar(
                              avatarUrl: _safeHttpUrl(profile.avatarUrl),
                              animatedAvatarUrl:
                                  _safeHttpUrl(profile.animatedAvatarUrl),
                              displayName: profile.displayName,
                              radius: 48,
                              frameScale: 1.0,
                              userId: profile.uid,
                              frameKey: profile.avatarFrameKey,
                            );
                          },
                        ),
                        const Positioned(
                          right: -2,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.camera_alt_outlined,
                                  size: 16, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      ServerChatBadgeAboveName(
                        uid: profile.uid,
                        center: true,
                        size: 30,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ServerUsernameDisplay(
                            uid: profile.uid,
                            fallbackName: profile.displayName,
                            fallbackFontSize: profile.usernameFontSize.clamp(8, 34).toDouble(),
                            showTitle: true,
                          ),
                          if (profile.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                color: AppColors.primary, size: 20),
                          ],
                          Consumer(
                            builder: (context, ref, _) {
                              final hasSmiley = ref
                                      .watch(effectiveFeaturesProvider(
                                          profile.uid))
                                      .valueOrNull
                                      ?.animatedSmileyNextToName ??
                                  false;
                              if (!hasSmiley) return const SizedBox.shrink();
                              return const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: _PulsingSmiley(),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MembershipBadgeChip(
                        badge: (ref
                                    .watch(currentSubscriptionProvider)
                                    .valueOrNull
                                    ?.effectiveTier)
                                ?.badge ??
                            SubscriptionCatalog.free.badge,
                        fontSize: 12,
                      ),
                      const MembershipCountdownChip(),
                      const SizedBox(height: 8),
                      if (profile.statusText != null &&
                          profile.statusText!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.statusText!,
                            style: TextStyle(
                              fontSize: profile.statusFontSize,
                              color: profile.statusColor != null
                                  ? Color(profile.statusColor!)
                                  : AppColors.textSecondary,
                              fontWeight: profile.statusBold
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: profile.statusItalic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(profile.email,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        'عضو منذ ${_formatJoinDate(profile.createdAt)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final statsAsync =
                              ref.watch(currentGamificationStatsProvider);
                          final stats = statsAsync.valueOrNull;
                          if (stats == null) return const SizedBox.shrink();

                          final unlimitedAsync =
                              ref.watch(isUnlimitedResourcesProvider);
                          final isUnlimited =
                              unlimitedAsync.valueOrNull ?? false;

                          final gemsLabel =
                              isUnlimited ? '∞ جوهرة' : '${stats.gems} جوهرة';
                          final pointsLabel =
                              isUnlimited ? '∞ نقطة' : '${stats.points} نقطة';

                          final canClaim =
                              stats.canClaimDailyReward(DateTime.now());
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Chip(
                                    avatar: const Icon(Icons.military_tech,
                                        size: 16),
                                    label: Text('المستوى ${stats.rankLevel}'),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    avatar: const Icon(Icons.diamond_outlined,
                                        size: 16),
                                    label: Text(gemsLabel),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    avatar: const Icon(Icons.stars, size: 16),
                                    label: Text(pointsLabel),
                                  ),
                                  if (stats.dailyRewardStreak > 1) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      avatar: const Icon(
                                          Icons.local_fire_department,
                                          size: 16),
                                      label: Text(
                                          '${stats.dailyRewardStreak} يوم'),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: canClaim
                                        ? () => ref
                                            .read(gamificationControllerProvider
                                                .notifier)
                                            .claimDailyReward(profile.uid)
                                        : null,
                                    icon: const Icon(Icons.card_giftcard),
                                    label: Text(
                                      canClaim ? 'مكافأة اليوم' : 'تم الاستلام',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SubscriptionsPage()),
                                      );
                                    },
                                    icon: const Icon(
                                        Icons.workspace_premium_outlined),
                                    label: const Text('العضويات'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // المستخدمون المحظورون، ومن زار ملفي.
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lightbulb_outline),
                            label: const Text('اقترح فكرة'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SubmitFeedbackPage(),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.donut_large),
                            label: const Text('عجلة الحظ'),
                            onPressed: () => MysterySpinDialog.show(
                              context,
                              profile.uid,
                            ),
                          ),
                        ],
                      ),
                      if (profile.profileMusicUrl != null &&
                          profile.profileMusicUrl!.isNotEmpty)
                        Consumer(
                          builder: (context, ref, _) {
                            final hasMusic = ref
                                    .watch(
                                        effectiveFeaturesProvider(profile.uid))
                                    .valueOrNull
                                    ?.profileMusic ??
                                false;
                            if (!hasMusic) return const SizedBox.shrink();
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('موسيقى البروفايل',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                ),
                                const SizedBox(height: 8),
                                _ProfileMusicPlayer(
                                    url: profile.profileMusicUrl!),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      if (profile.bio.isNotEmpty) ...[
                        Text(profile.bio, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                      ],
                      if (profile.profession != null)
                        _InfoRow(
                            icon: Icons.work_outline,
                            text: profile.profession!),
                      if (profile.city != null || profile.country != null)
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: [profile.city, profile.country]
                              .where((e) => e != null)
                              .join('، '),
                        ),
                      if (profile.experiences.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('الخبرات',
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.experiences
                              .map((e) => Chip(label: Text(e)))
                              .toList(),
                        ),
                      ],
                      if (profile.socialLinks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: profile.socialLinks
                              .map((s) => ActionChip(
                                    avatar: const Icon(Icons.link, size: 16),
                                    label: Text(s.platform),
                                    onPressed: () => _openSocialLink(
                                      context,
                                      s.url,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppearOfflineToggle(uid: profile.uid),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.divider, height: 32),
                      AccountSettingsContent(profile: profile, embedded: true),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileMusicPlayer extends StatefulWidget {
  final String url;
  const _ProfileMusicPlayer({required this.url});

  @override
  State<_ProfileMusicPlayer> createState() => _ProfileMusicPlayerState();
}

class _ProfileMusicPlayerState extends State<_ProfileMusicPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get _isUploadedProfileMusic =>
      widget.url.contains('/storage/v1/object/public/profile-music/');

  @override
  void initState() {
    super.initState();
    if (_isUploadedProfileMusic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _player.play(UrlSource(widget.url));
      });
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      });
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      });
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      });
    }
  }

  Future<void> _toggle() async {
    if (!_isUploadedProfileMusic) {
      await safeLaunch(widget.url);
      return;
    }
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUploadedProfileMusic) return EmbeddedMediaPlayer(url: widget.url);
    final total = _duration.inMilliseconds;
    final value =
        total > 0 ? _position.inMilliseconds.clamp(0, total).toDouble() : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppColors.gold,
                size: 34),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: total > 0 ? total.toDouble() : 1,
              onChanged: total > 0
                  ? (v) => _player.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Text('${_position.inSeconds}/${_duration.inSeconds}s',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

Future<void> _openSocialLink(BuildContext context, String value) async {
  final raw = value.trim();
  if (raw.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBarSfx(
      const SnackBar(content: Text('رابط التواصل غير متاح')),
    );
    return;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    ScaffoldMessenger.of(context).showSnackBarSfx(
      const SnackBar(content: Text('رابط التواصل غير صالح')),
    );
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('فشل فتح رابط التواصل')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('فشل فتح رابط التواصل: $e')),
      );
    }
  }
}

String? _safeHttpUrl(String? value) {
  final v = value?.trim();
  if (v == null || v.isEmpty) return null;
  final uri = Uri.tryParse(v);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return v;
}

Future<bool> _confirmProfileUpload(
  BuildContext context, {
  required String label,
  required String fileName,
  required int bytes,
}) async {
  final mb = bytes / (1024 * 1024);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('تأكيد رفع $label'),
      content: Text(
        'الملف: $fileName\nالحجم: ${mb.toStringAsFixed(2)} MB\n\nهل تريد رفعه وحفظه على الخادم الآن؟',
        textDirection: TextDirection.rtl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('رفع وحفظ'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<void> _showUploadResult(
  BuildContext context, {
  required bool success,
  required String label,
  String? error,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.redAccent),
          const SizedBox(width: 8),
          Text(success ? 'تم بنجاح' : 'فشل العملية'),
        ],
      ),
      content: Text(
        success
            ? 'تم رفع $label وحفظه على الخادم، وتم تحديث البروفايل.'
            : (error ?? 'فشل تنفيذ العملية.'),
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
}

Future<void> _pickAndUploadProfileImage(
  BuildContext context,
  WidgetRef ref,
  ProfileEntity profile, {
  required bool cover,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: cover ? 82 : 88,
    maxWidth: cover ? 1800 : 1200,
  );
  if (picked == null || !context.mounted) return;
  final cropped = cover ? picked : await cropAvatarBeforeUpload(context, picked);
  if (cropped == null || !context.mounted) return;
  final bytes = await cropped.length();
  if (!context.mounted) return;
  final label = cover ? 'خلفية البروفايل' : 'صورة المستخدم';
  if (!await _confirmProfileUpload(
    context,
    label: label,
    fileName: picked.name,
    bytes: bytes,
  )) {
    return;
  }

  String? uploadedUrl;
  try {
    final uid = profile.uid;
    // الخلفية لا تمرّ بالقص فاسمها من المنتقي قد يخلو من امتداد (خاصةً على
    // الويب: blob بلا .jpg) فيُرفض كـ«نوع غير مسموح». نستنتج الامتداد من
    // توقيع الملف نفسه ونسمّيه صراحةً.
    final upBytes = await cropped.readAsBytes();
    String upExt = 'jpg';
    if (upBytes.length > 12) {
      if (upBytes[0] == 0x89 && upBytes[1] == 0x50) {
        upExt = 'png';
      } else if (upBytes[0] == 0x47 && upBytes[1] == 0x49) {
        upExt = 'gif';
      } else if (upBytes[0] == 0x52 && upBytes[1] == 0x49 && upBytes[8] == 0x57) {
        upExt = 'webp';
      }
    }
    uploadedUrl = await MediaUploadService(bucket: 'profile-avatars').uploadBytes(
      bytes: upBytes,
      fileName: '${cover ? 'cover' : 'avatar'}.$upExt',
      folder: uid,
      uid: uid,
    );
    final updated = cover
        ? profile.copyWith(coverUrl: uploadedUrl, updatedAt: DateTime.now())
        : profile.copyWith(
            avatarUrl: uploadedUrl,
            // A new normal avatar replaces the previously active animated avatar.
            // This guarantees the newly uploaded image is visible immediately.
            animatedAvatarUrl: '',
            updatedAt: DateTime.now(),
          );
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(updated);
    if (!ok) {
      // عطل حقيقي وُجد هنا: هذا الحذف كان خارج أي حماية خاصة به، بخلاف
      // النمط الصحيح المتّبع في edit_profile_page.dart حيث كل حذف مُغلَّف
      // بـtry/catch مستقل. فشل حذف الملف المرفوع (مؤقتًا، لفشل التحديث
      // أصلًا) لا يجوز أن يُسقط بلوك try الرئيسي ويُظهر الرسالة العامة
      // المضلِّلة بدل سبب فشل التحديث الحقيقي أعلاه.
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-avatars',
          publicUrl: uploadedUrl,
        );
      } catch (_) {}
      if (!context.mounted) return;
      await _showUploadResult(
        context,
        success: false,
        label: label,
        error: ref.read(profileControllerProvider).error?.toString() ??
            'فشل حفظ التغيير على الخادم.',
      );
      return;
    }

    // السبب الحقيقي للعطل المُبلَّغ: رفع الصورة وتحديث الملف الشخصي نجحا
    // فعليًا في هذه المرحلة، لكن حذف الصورة القديمة (تنظيف لا ضرورة
    // لنجاحه) لم يكن محميًّا بحماية خاصة به — أي استثناء هنا (ملف غير
    // موجود أصلًا، رابط لا يطابق نمط هذا الحاوي...) كان يسقط إلى الـcatch
    // العام أسفل الدالة فيظهر "تعذر إكمال العملية" رغم أن الصورة تغيّرت
    // بنجاح فعلاً على الخادم.
    final previousUrl = cover ? profile.coverUrl : profile.avatarUrl;
    try {
      await ProfileStorageCleanup.deletePublicFile(
        bucket: 'profile-avatars',
        publicUrl: previousUrl,
      );
    } catch (_) {}

    ref.invalidate(currentProfileProvider);
    ref.invalidate(profileByIdProvider(profile.uid));
    if (!context.mounted) return;
    await _showUploadResult(context, success: true, label: label);
  } catch (e) {
    if (uploadedUrl != null) {
      try {
        await ProfileStorageCleanup.deletePublicFile(
          bucket: 'profile-avatars',
          publicUrl: uploadedUrl,
        );
      } catch (_) {}
    }
    if (!context.mounted) return;
    final raw = e.toString();
    await _showUploadResult(
      context,
      success: false,
      label: label,
      // الرسالة العامة كانت تُخفي السبب الحقيقي دائمًا (حصة الصورة
      // المستنفَدة، رفض تخزيني، انقطاع فعلي...)، فلا يعرف المستخدم هل
      // يعيد المحاولة أم ينتظر الشهر القادم. السبب الخادمي (إن وُجد) يظهر
      // الآن أولًا.
      error: raw.contains('AVATAR_QUOTA_EXCEEDED')
          ? raw.substring(raw.indexOf('AVATAR_QUOTA_EXCEEDED') + 'AVATAR_QUOTA_EXCEEDED:'.length).trim()
          : (e is ServerException && e.message.trim().isNotEmpty)
              ? e.message
              : 'تعذر إكمال العملية الآن. تحقق من الاتصال ثم أعد المحاولة.',
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// ميزة العضوية: سمايل متحرك بجانب الاسم (animatedSmileyNextToName)
/// — نبض ناعم مستمر، بديل خفيف الوزن عن GIF متحرك حقيقي.
class _PulsingSmiley extends StatefulWidget {
  const _PulsingSmiley();

  @override
  State<_PulsingSmiley> createState() => _PulsingSmileyState();
}

class _PulsingSmileyState extends State<_PulsingSmiley>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 0.9 + (_controller.value * 0.3);
        return Transform.scale(
            scale: scale,
            child: const Text('✨', style: TextStyle(fontSize: 16)));
      },
    );
  }
}

/// ميزة 13 من القائمة الإضافية: "عضو منذ" — تاريخ انضمام مختصر
/// وأنيق بدل الطابع الزمني الكامل.
String _formatJoinDate(DateTime date) {
  const monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${monthsAr[date.month - 1]} ${date.year}';
}
