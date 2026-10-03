import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_dialog.dart';
import '../../domain/entities/content_categories.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';
import '../pages/post_detail_page.dart';
import '../../../content_engagement/presentation/widgets/image_engagement_badge.dart';

class PostCard extends ConsumerWidget {
  final PostEntity post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(profileByIdProvider(post.authorUid));
    final likedAsync = ref.watch(isPostLikedProvider(post.id));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceHighlight,
                    child: Icon(Icons.person, size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: 8),
                  authorAsync.valueOrNull == null
                      ? const Text('...')
                      : ServerUsernameDisplay(
                          uid: authorAsync.valueOrNull!.uid,
                          fallbackName: authorAsync.valueOrNull!.displayName,
                          fallbackFontSize: 15,
                        ),
                  const Spacer(),
                  Chip(label: Text(ContentCategories.labelOf(post.category))),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppColors.textSecondary),
                    onSelected: (value) {
                      if (value == 'report') {
                        showReportDialog(
                          context: context,
                          ref: ref,
                          targetType: ReportTargetType.post,
                          targetId: post.id,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.text, maxLines: 4, overflow: TextOverflow.ellipsis),
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        post.mediaUrls.first,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: SizedBox.shrink(),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: ImageEngagementBadge(
                          contentId: post.id,
                          ownerUserId: post.authorUid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: post.tags
                      .map((t) => Text('#$t',
                          style: const TextStyle(
                              color: AppColors.goldMuted, fontSize: 12)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      likedAsync.valueOrNull == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: likedAsync.valueOrNull == true
                          ? AppColors.burgundyBright
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: myUid == null
                        ? null
                        : () {
                            ref
                                .read(postControllerProvider.notifier)
                                .toggleLike(
                                  postId: post.id,
                                  uid: myUid,
                                  postAuthorUid: post.authorUid,
                                );
                            ref.invalidate(isPostLikedProvider(post.id));
                          },
                  ),
                  Text('${post.likesCount}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${post.commentsCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
