import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/avatar_zoom_viewer.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/widgets/mini_chat_overlay.dart';
import '../../../friends/presentation/widgets/friend_button.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_dialog.dart';
import '../../../social_graph/domain/repositories/social_graph_repository.dart';
import '../../../social_graph/presentation/providers/social_graph_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/profile_likes_service.dart';
import '../../domain/profile_visitors_service.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../rbac/presentation/widgets/server_user_identity_badges.dart';


/// عرض للقراءة فقط لملف مستخدم آخر — بلا زر تعديل، لكن بزر مراسلة
/// يفتح مباشرة محادثة الشات معه.
///
/// 🔧 إصلاح: تسجيل الزيارة كان يتم عبر `ref.watch(...)` مباشرة داخل
/// build() — نمط يعمل تقنيًا في Riverpod لكنه غير مستحسن لأثر جانبي
/// لمرة واحدة (side effect)، لأنه يجعل الصفحة "تراقب" Future الكتابة
/// نفسها وتُعيد البناء عند اكتماله. حُوِّل الآن لاستدعاء وحيد صريح في
/// initState (ConsumerStatefulWidget)، منفصل تمامًا عن دورة
/// build/watch — هذا يزيل احتمالية إعادة بناء غير متوقَّعة مرتبطة
/// بهذا الأثر الجانبي، وهي أحد الاحتمالات التي رُوجعت لمعالجة خطأ
/// "Cannot hit test a render box that has never been laid out"
/// المُبلَّغ عنه عند فتح الملفات الشخصية.
class UserProfileViewPage extends ConsumerStatefulWidget {
  final String uid;
  const UserProfileViewPage({super.key, required this.uid});

  @override
  ConsumerState<UserProfileViewPage> createState() =>
      _UserProfileViewPageState();
}

class _UserProfileViewPageState extends ConsumerState<UserProfileViewPage> {
  @override
  void initState() {
    super.initState();
    // يُنفَّذ بعد اكتمال أول إطار (frame) فقط — وليس أثناء بناء
    // الشجرة — لضمان توفر Provider container بالكامل وتفادي أي
    // تعارض مع دورة حياة الودجت (widget lifecycle) عند فتح الصفحة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
      if (myUid != null && myUid != widget.uid) {
        ref.read(recordProfileVisitProvider(
            (profileUid: widget.uid, visitorUid: myUid)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.uid));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_rounded, size: 54, color: Colors.white54),
              const SizedBox(height: 12),
              Text('لم يكتمل تحميل الملف الشخصي', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('تحقق من الاتصال أو إعدادات خصوصية الحساب ثم أعد المحاولة.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(profileByIdProvider(widget.uid)),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_search_rounded, size: 54, color: Colors.white54),
                  const SizedBox(height: 12),
                  const Text('العضو غير موجود'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(profileByIdProvider(widget.uid)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          return _Body(profile: profile, myUid: myUid);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final ProfileEntity profile;
  final String? myUid;
  const _Body({required this.profile, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersCount =
        ref.watch(followersCountProvider(profile.uid)).valueOrNull ?? 0;
    final followingCount =
        ref.watch(followingCountProvider(profile.uid)).valueOrNull ?? 0;
    final vipContent = ref.watch(profileVipContentProvider(profile.uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Tap the avatar to open it full screen with zoom in/out controls.
          GestureDetector(
            onTap: () => showAvatarZoomViewer(
              context,
              imageUrl: profile.avatarUrl ?? profile.animatedAvatarUrl,
              title: profile.displayName,
            ),
            child: ProfileAvatar(
                avatarUrl: profile.avatarUrl,
                animatedAvatarUrl: profile.animatedAvatarUrl,
                userId: profile.uid,
                displayName: profile.displayName,
                radius: 48,
                frameKey: profile.avatarFrameKey),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ServerUsernameDisplay(
                  uid: profile.uid,
                  fallbackName: profile.displayName,
                  fallbackFontSize: profile.usernameFontSize,
                  // الشارات تُرسم مرة واحدة في الصف المستقل تحت الاسم
                  // (ServerUserIdentityBadges أدناه). رسمها هنا أيضًا كان
                  // يُظهر "مالك المنصة" مرتين.
                  showBadges: false,
                  center: true,
                  showTitle: true,
                ),
              ),
              if (profile.verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: AppColors.gold, size: 20),
              ],
            ],
          )),
          const SizedBox(height: 6),
          ServerUserIdentityBadges(
            uid: profile.uid,
            fontSize: 10,
            showAchievements: true,
            showChatBadge: false,
            compact: false,
          ),
          Consumer(builder: (context, ref, _) {
            final viewerData = ref.watch(profileForViewerProvider(profile.uid));
            return viewerData.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                // country/city only present in the response when the
                // server decided this viewer is allowed to see them
                // (owner/self, public visibility, or an accepted friend
                // on a 'friends'-only profile) — never a client-side check.
                final city = data['city'] as String?;
                final country = data['country'] as String?;
                final parts = [city, country]
                    .whereType<String>()
                    .where((v) => v.trim().isNotEmpty)
                    .toList();
                final children = <Widget>[
                  if (parts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        parts.join('، '),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  if (data.containsKey('is_online'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        data['is_online'] == true ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(
                          fontSize: 11,
                          color: data['is_online'] == true ? Colors.greenAccent : Colors.white54,
                        ),
                      ),
                    ),
                  if (data['privileged'] == true)
                    _OwnerPrivilegedPanel(data: data),
                  _AdminEditTools(targetUid: data['id']?.toString() ?? '', currentName: data['display_name']?.toString() ?? ''),
                ];
                if (children.isEmpty) return const SizedBox.shrink();
                return Column(children: children);
              },
            );
          }),
          if (myUid != null && myUid != profile.uid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LikeButton(profileUid: profile.uid, viewerUid: myUid!),
            ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(profile.bio, textAlign: TextAlign.center),
          ],
          _ProfileVipSurface(profile: profile, myUid: myUid),
          if (profile.profileMusicUrl != null &&
              profile.profileMusicUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text('موسيقى الملف',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 7),
            _OtherUserProfileMusicPlayer(url: profile.profileMusicUrl!),
          ],
          vipContent.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (content) => _VipProfileContent(
              profileUid: profile.uid,
              content: content,
              isOwner: myUid == profile.uid,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              _CountBadge(label: 'متابعون', count: followersCount),
              _CountBadge(label: 'يتابع', count: followingCount),
            ],
          ),
          if (myUid != null && myUid != profile.uid)
            _MutualFriendsIndicator(myUid: myUid!, otherUid: profile.uid),
          const SizedBox(height: 20),
          if (myUid != null && myUid != profile.uid) ...[
            FriendButton(myUid: myUid!, targetUid: profile.uid),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _FollowButton(myUid: myUid!, targetUid: profile.uid),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('مراسلة'),
                  onPressed: () {
                    openPrivateChat(
                      context,
                      ref,
                      threadId: _profileVipThreadId(myUid!, profile.uid),
                      peerUid: profile.uid,
                      peerName: profile.displayName,
                      peerAvatar: profile.avatarUrl,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('حظر المستخدم'),
                    content: Text(
                        'هل تريد حظر ${profile.displayName}؟ لن تتمكنا من مراسلة بعضكما أو متابعة بعضكما.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حظر')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(socialGraphControllerProvider.notifier)
                      .block(blockerUid: myUid!, targetUid: profile.uid);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.block, size: 18, color: AppColors.error),
              label: const Text('حظر المستخدم',
                  style: TextStyle(color: AppColors.error)),
            ),
            TextButton.icon(
              onPressed: () => showReportDialog(
                context: context,
                ref: ref,
                targetType: ReportTargetType.user,
                targetId: profile.uid,
              ),
              icon: const Icon(Icons.flag_outlined,
                  size: 18, color: AppColors.textSecondary),
              label: const Text('إبلاغ عن المستخدم',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }

}

/// زر "إعجاب" على الملف الشخصي مثل فيسبوك — يعرض عدّاد الإعجابات
/// ويتيح تبديل حالة إعجاب الزائر الحالي عبر [ProfileLikesService].
/// لا يظهر إطلاقًا على ملف المستخدم نفسه (يُستدعى فقط عند myUid !=
/// null، والصفحة أصلًا للاطّلاع على ملفات الآخرين فقط).
class _ProductMediaPreview extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductMediaPreview({required this.product});

  @override
  Widget build(BuildContext context) {
    final images = product['image_urls'];
    final imageUrl = images is List && images.isNotEmpty ? images.first?.toString() : null;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }
    return SizedBox(
      width: 56,
      height: 56,
      child: Icon(
        product['owned'] == true
            ? (product['media_type'] == 'video' ? Icons.play_circle_outline : Icons.image_outlined)
            : Icons.lock_outline,
      ),
    );
  }
}

class _LikeButton extends ConsumerWidget {
  final String profileUid;
  final String viewerUid;
  const _LikeButton({required this.profileUid, required this.viewerUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(profileLikesCountProvider(profileUid)).valueOrNull ?? 0;
    final isLiked = ref
            .watch(profileIsLikedByViewerProvider(
                (profileUid: profileUid, viewerUid: viewerUid)))
            .valueOrNull ??
        false;

    return TextButton.icon(
      onPressed: () async {
        try {
          await ProfileLikesService.toggleLike(
            profileUid: profileUid,
            likerUid: viewerUid,
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBarSfx(
            SnackBar(content: Text('فشل تحديث الإعجاب: $e')),
          );
        }
      },
      icon: Icon(
        isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
        size: 18,
        color: isLiked ? AppColors.gold : AppColors.textSecondary,
      ),
      label: Text(
        count > 0 ? 'إعجاب ($count)' : 'إعجاب',
        style: TextStyle(
            color: isLiked ? AppColors.gold : AppColors.textSecondary,
            fontSize: 13),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  const _CountBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String myUid;
  final String targetUid;
  const _FollowButton({required this.myUid, required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowingAsync =
        ref.watch(isFollowingProvider((followerUid: myUid, targetUid: targetUid)));
    final isFollowing = isFollowingAsync.valueOrNull ?? false;

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(isFollowing ? Icons.check : Icons.person_add_alt),
        label: Text(isFollowing ? 'متابَع' : 'متابعة'),
        onPressed: () async {
          final controller = ref.read(socialGraphControllerProvider.notifier);
          final success = isFollowing
              ? await controller.unfollow(
                  followerUid: myUid,
                  targetUid: targetUid,
                )
              : await controller.follow(
                  followerUid: myUid,
                  targetUid: targetUid,
                );
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBarSfx(
              const SnackBar(
                content: Text('فشل تحديث المتابعة في قاعدة البيانات'),
              ),
            );
          }
        },
      ),
    );
  }
}

final _followingUidsProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, uid) {
  return sl<SocialGraphRepository>().watchFollowingUids(uid);
});

/// ميزة 14 من القائمة الإضافية: "أصدقاء مشتركون" — يحسب تقاطع قائمة
/// متابَعي المستخدمَين (وليس المتابِعين، لتفادي أرقام مزدوجة) ويعرض
/// العدد فقط دون كشف الأسماء تحديدًا حرصًا على الخصوصية.
class _MutualFriendsIndicator extends ConsumerWidget {
  final String myUid;
  final String otherUid;
  const _MutualFriendsIndicator({required this.myUid, required this.otherUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(_followingUidsProvider(myUid)).valueOrNull;
    final theirs = ref.watch(_followingUidsProvider(otherUid)).valueOrNull;
    if (mine == null || theirs == null) return const SizedBox.shrink();

    final mutualCount = mine.toSet().intersection(theirs.toSet()).length;
    if (mutualCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$mutualCount صديق مشترك',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}


String _profileVipThreadId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

class _ProfileVipSurface extends ConsumerWidget {

  final ProfileEntity profile;
  final String? myUid;

  const _ProfileVipSurface({required this.profile, required this.myUid});

  bool _enabled(Map<String, dynamic> effects, String key) =>
      (effects[key] as Map?)?['enabled'] == true;

  String _setting(Map<String, dynamic> effects, String key, String fallback) {
    final raw = (effects[key] as Map?)?['settings'];
    if (raw is Map) {
      final value = raw['value']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }



  Future<void> _showQr(BuildContext context, ProfileEntity profile) async {
    final link = 'https://mashareena.app/profile/${profile.uid}';
    final qrUrl = 'https://quickchart.io/qr?size=320&text=${Uri.encodeComponent(link)}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بطاقة QR للبروفايل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.network(qrUrl, width: 220, height: 220, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 180)),
          const SizedBox(height: 8),
          SelectableText(link, textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: link)); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('نسخ الرابط')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _showAnalytics(BuildContext context, WidgetRef ref, ProfileEntity profile) async {
    if (myUid != profile.uid) return;
    final effects = ref.read(profilePublicVipEffectsProvider(profile.uid)).valueOrNull ?? const <String, dynamic>{};
    if ((effects['profile_analytics_plus'] as Map?)?['enabled'] != true) return;
    try {
      final visitorsRaw = await Supabase.instance.client.rpc('get_my_profile_visitors', params: {'p_limit': 200});
      final content = await ref.read(profileVipContentProvider(profile.uid).future);
      int count(dynamic v) => v is List ? v.length : 0;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إحصائيات البروفايل Plus'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('المتابعون: ${ref.read(followersCountProvider(profile.uid)).valueOrNull ?? 0}'),
            Text('يتابع: ${ref.read(followingCountProvider(profile.uid)).valueOrNull ?? 0}'),
            Text('الزوار المسجلون: ${count(visitorsRaw)}'),
            Text('منتجات الملف: ${count(content['products'])}'),
            Text('عناصر المتجر المصغر: ${count(content['mini_store'])}'),
            Text('الاستطلاعات الفعالة: ${count(content['polls'])}'),
            Text('الإعلانات النشطة/المسودة: ${count(content['ads'])}'),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
        ),
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر تحميل الإحصائيات: $e')));
    }
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(profilePublicVipEffectsProvider(profile.uid)).valueOrNull ??
        const <String, dynamic>{};
    final highlight = _enabled(effects, 'profile_highlight');
    final themePlus = _enabled(effects, 'profile_theme_plus');
    final cardPlus = _enabled(effects, 'profile_card_plus');
    final visitorAlerts = _enabled(effects, 'profile_visitor_alerts');
    final contact = _enabled(effects, 'profile_contact_button');
    final qr = _enabled(effects, 'profile_qr_card');
    final badge = _enabled(effects, 'profile_custom_badge');
    final priority = _enabled(effects, 'profile_priority_search');
    final analytics = myUid == profile.uid && _enabled(effects, 'profile_analytics_plus');
    final creatorTip = myUid != null && myUid != profile.uid && _enabled(effects, 'creator_tip_button');
    final tailor = _enabled(effects, 'tailor_pattern_highlight');
    final any = highlight || themePlus || cardPlus || visitorAlerts || contact || qr ||
        creatorTip ||
        badge || priority || analytics || tailor;
    if (!any) return const SizedBox.shrink();

    final border = highlight || themePlus
        ? Border.all(color: const Color(0xFFFFD166), width: highlight ? 1.6 : 1)
        : null;
    final label = _setting(effects, 'profile_contact_button', 'تواصل معي');

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardPlus ? 20 : 14),
          border: border,
          gradient: themePlus
              ? const LinearGradient(colors: [Color(0x142F80ED), Color(0x10FFD166)])
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFD166)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text('مزايا VIP الفعالة', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                if (priority)
                  const Tooltip(
                    message: 'أولوية الظهور في البحث',
                    child: Icon(Icons.manage_search, size: 18, color: Color(0xFF7DD3FC)),
                  ),
              ],
            ),
            if (highlight) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0x1AFFD166),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.highlight, size: 16, color: Color(0xFFFFD166)),
                    SizedBox(width: 6),
                    Text('هذا الملف مميز بواسطة VIP', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
            if (badge) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.workspace_premium, size: 16),
                label: Text(_setting(effects, 'profile_custom_badge', 'VIP')),
              ),
            ],
            if (visitorAlerts || analytics || tailor) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (visitorAlerts)
                    ActionChip(
                      avatar: const Icon(Icons.notifications_active, size: 15),
                      label: Text(myUid == profile.uid ? 'تنبيهات الزوار' : 'تنبيهات الزوار متاحة'),
                      onPressed: myUid == profile.uid ? () async {
                        try {
                          final raw = await Supabase.instance.client.rpc('get_my_profile_visitors', params: {'p_limit': 50});
                          if (!context.mounted) return;
                          final count = raw is List ? raw.length : 0;
                          ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('لديك $count زائرًا مسجلًا.')));
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر قراءة تنبيهات الزوار: $e')));
                        }
                      } : null,
                    ),
                  if (analytics)
                    const Chip(avatar: Icon(Icons.analytics, size: 15), label: Text('إحصائيات Plus')),
                  if (tailor)
                    const Chip(avatar: Icon(Icons.content_cut, size: 15), label: Text('باترونات مميزة')),
                ],
              ),
            ],
            if (analytics) ...[
              const SizedBox(height: 6),
              Text('المتابعون: ${ref.watch(followersCountProvider(profile.uid)).valueOrNull ?? 0} • يتابع: ${ref.watch(followingCountProvider(profile.uid)).valueOrNull ?? 0}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
            if (creatorTip) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _showPublicCreatorTip(context, profile),
                icon: const Icon(Icons.volunteer_activism),
                label: Text(_setting(effects, 'creator_tip_button', 'دعم المنشئ')),
              ),
            ],
            if (contact && myUid != null && myUid != profile.uid) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => openPrivateChat(
                  context,
                  ref,
                  threadId: _profileVipThreadId(myUid!, profile.uid),
                  peerUid: profile.uid,
                  peerName: profile.displayName,
                  peerAvatar: profile.avatarUrl,
                ),
                icon: const Icon(Icons.contact_page),
                label: Text(label),
              ),
            ],
            if (qr) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _showQr(context, profile), icon: const Icon(Icons.qr_code_2), label: const Text('فتح بطاقة QR للبروفايل')),
            ],
            if (analytics) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _showAnalytics(context, ref, profile), icon: const Icon(Icons.analytics), label: const Text('الإحصائيات الفعلية')),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPublicCreatorTip(BuildContext context, ProfileEntity profile) async {
    if (myUid == null || myUid == profile.uid) return;
    final amount = TextEditingController(text: '100');
    String currency = 'points';
    try {
      final value = await showDialog<(String, int)?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text('دعم ${profile.displayName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مقدار الدعم'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'points', label: Text('نقاط')),
                    ButtonSegment(value: 'gems', label: Text('جواهر')),
                  ],
                  selected: {currency},
                  onSelectionChanged: (v) => setState(() => currency = v.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  final n = int.tryParse(amount.text.trim()) ?? 0;
                  if (n > 0) Navigator.pop(dialogContext, (currency, n));
                },
                child: const Text('إرسال الدعم'),
              ),
            ],
          ),
        ),
      );
      if (value == null || !context.mounted) return;
      final rpc = value.$1 == 'points' ? 'transfer_points' : 'transfer_gems_to_user';
      final raw = await Supabase.instance.client.rpc(rpc, params: {
        'p_to_user_id': profile.uid,
        'p_amount': value.$2,
        'p_idempotency_key': const Uuid().v4(),
      });
      if (raw is! Map || raw['ok'] != true) {
        throw StateError('لم يؤكد الخادم نجاح الدعم.');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('تم إرسال دعم المنشئ وتسجيل العملية خادميًا ✓')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر إرسال الدعم: $e')));
      }
    } finally {
      amount.dispose();
    }
  }
}

class _VipProfileContent extends ConsumerStatefulWidget {
  final String profileUid;
  final Map<String, dynamic> content;
  final bool isOwner;

  const _VipProfileContent({
    required this.profileUid,
    required this.content,
    required this.isOwner,
  });

  @override
  ConsumerState<_VipProfileContent> createState() => _VipProfileContentState();
}

class _VipProfileContentState extends ConsumerState<_VipProfileContent> {
  final Set<String> _impressionIdsSent = <String>{};

  List<Map<String, dynamic>> _maps(String key) {
    final raw = widget.content[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _purchaseStoreItem(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final points = (item['price_points'] as num?)?.toInt() ?? 0;
    final gems = (item['price_gems'] as num?)?.toInt() ?? 0;
    final currency = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Wrap(children: [
          ListTile(title: Text('${item['title'] ?? 'عنصر'} — اختر العملة')),
          if (points > 0) ListTile(leading: const Icon(Icons.star), title: Text('$points نقطة'), onTap: () => Navigator.pop(sheet, 'points')),
          if (gems > 0) ListTile(leading: const Icon(Icons.diamond), title: Text('$gems جوهرة'), onTap: () => Navigator.pop(sheet, 'gems')),
        ]),
      ),
    );
    if (currency == null || !context.mounted) return;
    final amount = currency == 'points' ? points : gems;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('سيتم شراء «${item['title'] ?? 'العنصر'}» مقابل $amount ${currency == 'points' ? 'نقطة' : 'جوهرة'} وحفظ العملية على الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('شراء')),
        ],
      ),
    ) ?? false;
    if (!confirmed || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc('purchase_profile_mini_store_item', params: {
        'p_item_id': item['id'],
        'p_currency': currency,
        'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(profileVipContentProvider(widget.profileUid));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم الشراء وتحويل المقابل لصاحب المتجر ✓')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر إتمام الشراء: $e')));
    }
  }

  /// الخادم يتحقق من الشراء ويُرجع bucket+path؛ التوقيع هنا عبر واجهة
  /// التخزين، وتحرسه سياسة SELECT (المشتري أو المالك فقط). كانت الدالة
  /// الخادمية تحاول التوقيع داخل SQL بدالة غير موجودة في Supabase، فلم يكن
  /// أي مشترٍ يستطيع فتح باترون أو منتج اشتراه.
  Future<String?> _signedFromServer(dynamic raw) async {
    if (raw is! Map) return raw?.toString();
    final direct = raw['url']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final bucket = raw['bucket']?.toString();
    final path = raw['path']?.toString();
    if (bucket == null || path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(path, 3600);
  }

  Future<void> _openProductMedia(BuildContext context, Map<String, dynamic> product) async {
    try {
      final raw = await Supabase.instance.client.rpc('get_profile_product_media_signed_url', params: {
        'p_product_id': product['id'],
      });
      final url = await _signedFromServer(raw);
      if (url != null && url.isNotEmpty) {
        await _open(url);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('لا توجد وسائط قابلة للعرض لهذا المنتج.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر فتح المنتج: $e')));
    }
  }

  Future<void> _purchaseProduct(BuildContext context, WidgetRef ref, Map<String, dynamic> product) async {
    final points = (product['price_points'] as num?)?.toInt() ?? 0;
    final gems = (product['price_gems'] as num?)?.toInt() ?? 0;
    if (points <= 0 && gems <= 0) {
      await _openProductMedia(context, product);
      return;
    }
    final currency = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Wrap(children: [
        const ListTile(title: Text('شراء المنتج')),
        if (points > 0) ListTile(leading: const Icon(Icons.star), title: Text('$points نقطة'), onTap: () => Navigator.pop(sheet, 'points')),
        if (gems > 0) ListTile(leading: const Icon(Icons.diamond), title: Text('$gems جوهرة'), onTap: () => Navigator.pop(sheet, 'gems')),
      ])),
    );
    if (currency == null || !context.mounted) return;
    final amountLabel = currency == 'points' ? '$points نقطة' : '$gems جوهرة';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('سيتم شراء «${product['title'] ?? product['name'] ?? 'المنتج'}» مقابل $amountLabel وحفظ العملية على الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('شراء')),
        ],
      ),
    ) ?? false;
    if (!confirmed || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc('purchase_profile_product', params: {
        'p_product_id': product['id'],
        'p_currency': currency,
        'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(profileVipContentProvider(widget.profileUid));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم شراء المنتج وتحويل المقابل للبائع ✓')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر شراء المنتج: $e')));
    }
  }

  Future<void> _purchasePattern(BuildContext context, WidgetRef ref, Map<String, dynamic> pattern) async {
    final points = (pattern['price_points'] as num?)?.toInt() ?? 0;
    final gems = (pattern['price_gems'] as num?)?.toInt() ?? 0;
    if (points <= 0 && gems <= 0) {
      await _openPattern(context, pattern);
      return;
    }
    final currency = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Wrap(children: [
        const ListTile(title: Text('شراء الباترون')),
        if (points > 0) ListTile(leading: const Icon(Icons.star), title: Text('$points نقطة'), onTap: () => Navigator.pop(sheet, 'points')),
        if (gems > 0) ListTile(leading: const Icon(Icons.diamond), title: Text('$gems جوهرة'), onTap: () => Navigator.pop(sheet, 'gems')),
      ])),
    );
    if (currency == null || !context.mounted) return;
    final amountLabel = currency == 'points' ? '$points نقطة' : '$gems جوهرة';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('سيتم شراء الباترون مقابل $amountLabel وحفظ العملية على الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('شراء')),
        ],
      ),
    ) ?? false;
    if (!confirmed || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc('purchase_profile_pattern', params: {
        'p_pattern_id': pattern['id'],
        'p_currency': currency,
        'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(profileVipContentProvider(widget.profileUid));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم شراء الباترون ✓')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر شراء الباترون: $e')));
    }
  }

  Future<void> _openPattern(BuildContext context, Map<String, dynamic> pattern) async {
    try {
      final raw = await Supabase.instance.client.rpc('get_profile_pattern_signed_url', params: {
        'p_pattern_id': pattern['id'],
      });
      final url = await _signedFromServer(raw);
      if (url != null && url.isNotEmpty) await _open(url);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('يجب شراء الباترون أولًا: $e')));
    }
  }

  Future<void> _vote(BuildContext context, String pollId, int index) async {
    try {
      await Supabase.instance.client.rpc('vote_profile_poll', params: {
        'p_poll_id': pollId,
        'p_option_index': index,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content: Text('تم تسجيل التصويت ✓')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تعذر تسجيل التصويت: $e')));
    }
  }

  void _queueAdImpressions() {
    if (widget.isOwner) return;
    final ads = _maps('ads');
    if (ads.isEmpty) return;
    for (final ad in ads) {
      final rawId = ad['id'];
      final id = rawId?.toString() ?? '';
      if (id.isEmpty || !_impressionIdsSent.add(id)) continue;
      unawaited(_recordAdImpression(id));
    }
  }

  Future<void> _recordAdImpression(String adId) async {
    try {
      await Supabase.instance.client.rpc(
        'record_profile_ad_impression',
        params: {'p_ad_id': adId},
      );
    } catch (_) {
      // Delivery accounting must never break profile rendering.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queueAdImpressions();
    });
  }

  @override
  void didUpdateWidget(covariant _VipProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileUid != widget.profileUid || oldWidget.content != widget.content) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _queueAdImpressions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = _maps('social_links');
    final products = _maps('products');
    final store = _maps('mini_store');
    final polls = _maps('polls');
    final ads = _maps('ads');
    final patterns = _maps('patterns');
    final vipEffects = ref.watch(profilePublicVipEffectsProvider(widget.profileUid)).valueOrNull ?? const <String, dynamic>{};
    final tailorHighlightEnabled = (vipEffects['tailor_pattern_highlight'] as Map?)?['enabled'] == true;
    if (links.isEmpty && products.isEmpty && store.isEmpty && polls.isEmpty && ads.isEmpty && patterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (links.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('التواصل الاجتماعي', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final link in links)
                ActionChip(
                  avatar: const Icon(Icons.open_in_new, size: 16),
                  label: Text('${link['platform'] ?? 'رابط'}'),
                  onPressed: () => _open('${link['url'] ?? ''}'),
                ),
            ],
          ),
        ],
        if (products.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('منتجات الملف', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final product in products)
            Card(
              child: ListTile(
                leading: _ProductMediaPreview(product: product),
                title: Text('${product['title'] ?? 'منتج'}'),
                subtitle: Text('${product['description'] ?? ''}'),
                // ListTile.trailing يمرّر قيدًا غير محدود العرض، فزرّ
                // بداخله يطلب عرضًا لانهائيًا ويرمي
                // "BoxConstraints forces an infinite width" — وهو أكثر
                // أخطاء التخطيط تكرارًا في سجل المراقبة، ويُسقط معه كل
                // ما فوقه في القائمة ("انهيار تخطيط متسلسل").
                // ConstrainedBox يمنح الصف حدًّا أعلى فينتهي الانهيار.
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (product['owned'] == true)
                      Flexible(
                        child: FilledButton.icon(
                          onPressed: () => _openProductMedia(context, product),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('عرض',
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                    else if (((product['price_points'] as num?)?.toInt() ?? 0) > 0 ||
                        ((product['price_gems'] as num?)?.toInt() ?? 0) > 0)
                      Flexible(
                        child: FilledButton(
                          onPressed: () =>
                              _purchaseProduct(context, ref, product),
                          child: const Text('شراء',
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                    else
                      Flexible(
                        child: FilledButton.icon(
                          onPressed: () => _openProductMedia(context, product),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('عرض',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
        ],
        if (store.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('المتجر المصغر', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final item in store)
            Card(
              child: ListTile(
                title: Text('${item['title'] ?? 'عنصر'}'),
                subtitle: Text('${item['description'] ?? ''}\n${item['price_points'] ?? 0} نقطة • ${item['price_gems'] ?? 0} جوهرة'),
                isThreeLine: true,
                trailing: widget.isOwner ? const Icon(Icons.inventory_2_outlined) : FilledButton(onPressed: () => _purchaseStoreItem(context, ref, item), child: const Text('شراء')),
              ),
            ),
        ],
        if (polls.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('استطلاعات الرأي', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final poll in polls)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${poll['question'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (poll['options'] is List)
                    for (var i = 0; i < (poll['options'] as List).length; i++)
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _vote(context, '${poll['id']}', i), child: Text('${(poll['options'] as List)[i]}'))),
                ]),
              ),
            ),
        ],
        if (ads.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('إعلان موجه', style: TextStyle(fontWeight: FontWeight.w900)),
          for (final ad in ads)
            Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text('${ad['title'] ?? ''}'), subtitle: Text('${ad['body'] ?? ''}'))),
        ],
        if (patterns.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('سوق الباترونات', style: TextStyle(fontWeight: FontWeight.w900))),
              if (tailorHighlightEnabled)
                const Tooltip(
                  message: 'عضو مميَّز في سوق الباترونات',
                  child: Icon(Icons.content_cut, size: 20, color: Colors.amber),
                ),
            ],
          ),
          for (final pattern in patterns)
            Card(
              shape: tailorHighlightEnabled
                  ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2))
                  : null,
              child: ListTile(
                leading: Icon(Icons.grid_4x4, color: tailorHighlightEnabled ? const Color(0xFF7DD3FC) : null),
                title: Row(
                  children: [
                    Expanded(child: Text('${pattern['title'] ?? ''}')),
                    if (tailorHighlightEnabled) const Icon(Icons.content_cut, size: 16, color: Color(0xFF7DD3FC)),
                  ],
                ),
                subtitle: Text(
                  '${pattern['description'] ?? ''}\n${pattern['price_points'] ?? 0} نقطة • ${pattern['price_gems'] ?? 0} جوهرة',
                ),
                isThreeLine: true,
                // نفس علاج قائمة المنتجات أعلاه: trailing غير محدود
                // العرض يُفجّر قياس الزر ويُسقط القائمة كلها.
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pattern['owned'] == true)
                        Flexible(
                          child: FilledButton.icon(
                            onPressed: () => _openPattern(context, pattern),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('فتح',
                                overflow: TextOverflow.ellipsis),
                          ),
                        )
                      else
                        Flexible(
                          child: FilledButton(
                            onPressed: () =>
                                _purchasePattern(context, ref, pattern),
                            child: const Text('شراء',
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],

      ],
    );
  }
}

class _OtherUserProfileMusicPlayer extends StatefulWidget {
  final String url;
  const _OtherUserProfileMusicPlayer({required this.url});

  @override
  State<_OtherUserProfileMusicPlayer> createState() =>
      _OtherUserProfileMusicPlayerState();
}

class _OtherUserProfileMusicPlayerState
    extends State<_OtherUserProfileMusicPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;


  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_player.play(UrlSource(widget.url)));
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _playing = false;
      _position = Duration.zero;
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final value =
        total > 0 ? _position.inMilliseconds.clamp(0, total).toDouble() : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            tooltip: _playing ? 'إيقاف مؤقت' : 'تشغيل',
            icon: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: AppColors.gold,
              size: 34,
            ),
          ),
          IconButton(
            onPressed: _stop,
            tooltip: 'إيقاف',
            icon: const Icon(Icons.stop_circle_outlined, color: AppColors.textSecondary, size: 28),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: total > 0 ? total.toDouble() : 1,
              onChanged: total <= 0
                  ? null
                  : (v) => _player.seek(Duration(milliseconds: v.round())),
            ),
          ),
        ],
      ),
    );
  }
}

/// لوحة تظهر فقط لمالك المنصة/سوبر أدمن (قسم 12 من وثيقة التنفيذ):
/// الحقول هنا تصل فقط لأنها موجودة أصلًا برد get_profile_for_viewer عند
/// كون المشاهد مخوّلًا — ما في أي منطق إخفاء هنا، الخادم هو اللي يقرر
/// من الأساس هل يرسل هالحقول ولا لأ. كل فتح لهالبيانات يُسجَّل بجدول
/// audit_logs تلقائيًا من نفس الدالة الخادمية.
class _OwnerPrivilegedPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OwnerPrivilegedPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('البريد الإلكتروني', (data['email'] as String?)?.trim().isNotEmpty == true ? data['email'] as String : '—'),
      ('النقاط', '${data['points_balance'] ?? 0}'),
      ('الجواهر', '${data['gems_balance'] ?? 0}'),
      ('نشط', data['is_active'] == true ? 'نعم' : 'لا'),
      ('موقوف', data['is_suspended'] == true ? 'نعم' : 'لا'),
      if (data['location_latitude'] != null && data['location_longitude'] != null)
        ('الموقع الجغرافي', '${data['location_latitude']}, ${data['location_longitude']}'),
      ('معرّف الحساب', data['id'] as String? ?? '—'),
      ('آخر عنوان IP', (data['last_ip'] as String?)?.trim().isNotEmpty == true ? data['last_ip'] as String : '—'),
      if (data['last_ip_at'] != null) ('وقت تسجيل الـ IP', '${data['last_ip_at']}'),
      if (data['last_seen_at'] != null) ('آخر ظهور (حقيقي)', '${data['last_seen_at']}'),
      ('متصل الآن (حقيقي)', data['true_is_online'] == true ? 'نعم' : 'لا'),
      if (data['appear_offline_enabled'] == true)
        ('يُخفي حالة اتصاله', 'نعم — يظهر للآخرين غير متصل'),
      ('مؤشر المخاطر الأمنية', '${data['security_risk_state'] ?? '—'} (${data['security_risk_score'] ?? 0})'),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 16),
            SizedBox(width: 6),
            Text('عرض إداري (مسجّل بسجل المراجعة)', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          // المعرّف والبريد أولًا، مع زر نسخ لكل منهما.
          for (final (label, value) in [
            ('معرّف الحساب (UID)', data['id'] as String? ?? ''),
            ('البريد الإلكتروني', (data['email'] as String?)?.trim() ?? ''),
          ])
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  Expanded(
                    child: SelectableText(value,
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                  IconButton(
                    tooltip: 'نسخ',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.gold),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBarSfx(
                          SnackBar(content: Text('نُسخ $label')));
                    },
                  ),
                ]),
              ),
          const Divider(height: 12),
          for (final (label, value) in rows.where((r) => r.$1 != 'البريد الإلكتروني' && r.$1 != 'معرّف الحساب'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ],
              ),
            ),
          // Grant / revoke "absolute view" — visible to the PLATFORM OWNER
          // ONLY. An account that merely holds the grant must never be able
          // to pass it on, so this control is gated on is_my_platform_owner
          // (the server enforces the same rule independently).
          _AbsoluteViewControl(targetUid: data['id'] as String? ?? ''),
        ],
      ),
    );
  }
}

class _AbsoluteViewControl extends ConsumerStatefulWidget {
  final String targetUid;
  const _AbsoluteViewControl({required this.targetUid});
  @override
  ConsumerState<_AbsoluteViewControl> createState() => _AbsoluteViewControlState();
}

class _AbsoluteViewControlState extends ConsumerState<_AbsoluteViewControl> {
  bool _busy = false;
  bool? _isOwner;
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.targetUid.isEmpty) return;
    try {
      final sb = Supabase.instance.client;
      final owner = await sb.rpc('is_my_platform_owner');
      final rows = await sb
          .from('absolute_view_grants')
          .select('user_id')
          .eq('user_id', widget.targetUid);
      if (!mounted) return;
      setState(() {
        _isOwner = owner == true;
        _granted = (rows as List).isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _isOwner = false);
    }
  }

  Future<void> _toggle(bool enable) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('admin_set_absolute_view', params: {
        'p_target_uid': widget.targetUid,
        'p_enabled': enable,
      });
      if (!mounted) return;
      setState(() => _granted = enable);
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
        content: Text(enable ? 'تم منح الصلاحية المطلقة ✓' : 'تم سحب الصلاحية المطلقة ✓'),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text(e.toString().contains('FORBIDDEN')
              ? 'هذه العملية للمالك فقط.'
              : 'تعذر تنفيذ العملية.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwner != true || widget.targetUid.isEmpty) return const SizedBox.shrink();
    final granted = _granted == true;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(height: 12),
        Text(
          granted
              ? 'هذا الحساب يملك صلاحية عرض مطلقة (منحتها أنت)'
              : 'منح هذا الحساب صلاحية عرض مطلقة لكل بيانات المستخدمين',
          style: TextStyle(fontSize: 11, color: granted ? Colors.amberAccent : Colors.white60),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _busy ? null : () => _toggle(!granted),
          style: granted
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
              : null,
          icon: _busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(granted ? Icons.lock_outline : Icons.verified_user, size: 16),
          label: Text(granted ? 'سحب الصلاحية المطلقة' : 'منح الصلاحية المطلقة'),
        ),
      ]),
    );
  }
}

/// أدوات الإدارة لتعديل اسم العضو وصورته وخلفيته. تظهر فقط إن أجاز الخادم
/// (can_admin_edit_member: المالك، أو طاقم أعلى رتبة من العضو). الإداري يرفع
/// الملف في مجلده الخاص (مسموح بسياسة التخزين)، والخادم يسند الرابط للعضو.
class _AdminEditTools extends StatefulWidget {
  final String targetUid;
  final String currentName;
  const _AdminEditTools({required this.targetUid, required this.currentName});
  @override
  State<_AdminEditTools> createState() => _AdminEditToolsState();
}

class _AdminEditToolsState extends State<_AdminEditTools> {
  bool? _allowed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetUid.isEmpty) return;
    Supabase.instance.client
        .rpc('can_admin_edit_member', params: {'p_target': widget.targetUid})
        .then((v) { if (mounted) setState(() => _allowed = v == true); })
        .catchError((_) { if (mounted) setState(() => _allowed = false); });
  }

  Future<void> _apply({String? name, String? avatar, String? cover}) async {
    setState(() => _busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc('admin_edit_member_profile', params: {
        'p_user_id': widget.targetUid,
        'p_display_name': name,
        'p_avatar_url': avatar,
        'p_cover_url': cover,
      });
      m.showSnackBarSfx(const SnackBar(content: Text('تم التعديل وأُشعر العضو')));
    } catch (e) {
      m.showSnackBarSfx(SnackBar(content: Text(e.toString().contains('FORBIDDEN')
          ? 'لا تملك صلاحية تعديل هذا العضو.'
          : 'تعذّر التعديل: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: widget.currentName);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تعديل اسم العضو'),
        content: TextField(controller: c, maxLength: 40, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    c.dispose();
    if (v != null && v.isNotEmpty) await _apply(name: v);
  }

  Future<void> _pickAndSet({required bool cover}) async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final url = await MediaUploadService(bucket: 'profile-avatars')
          .uploadFile(file: file, folder: me, uid: me);
      await _apply(avatar: cover ? null : url, cover: cover ? url : null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed != true) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('أدوات الإدارة',
            style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : _rename,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('تعديل الاسم')),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickAndSet(cover: false),
              icon: const Icon(Icons.account_circle_rounded, size: 16),
              label: const Text('تغيير الصورة')),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickAndSet(cover: true),
              icon: const Icon(Icons.wallpaper_rounded, size: 16),
              label: const Text('تغيير الخلفية')),
        ]),
      ]),
    );
  }
}
