import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final PostEntity post;
  const PostDetailPage({super.key, required this.post});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (text.isEmpty || uid == null) return;

    _commentController.clear();
    await ref.read(postControllerProvider.notifier).addComment(
          CommentEntity(
            id: '',
            postId: widget.post.id,
            authorUid: uid,
            text: text,
            createdAt: DateTime.now(),
          ),
          postAuthorUid: widget.post.authorUid,
        );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.post.id));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('المنشور')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(widget.post.text),
            ),
          ),
          const Divider(color: AppColors.divider),
          Expanded(
            child: commentsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const ErrorView(message: 'تعذر تحميل المنشور الآن. تحقق من الاتصال ثم أعد المحاولة.'),
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('لا توجد تعليقات بعد',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Consumer(
                      builder: (context, ref, _) {
                        final authorAsync =
                            ref.watch(profileByIdProvider(comment.authorUid));
                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.surfaceHighlight,
                            child: Icon(Icons.person,
                                size: 16, color: AppColors.gold),
                          ),
                          title: Text(
                              authorAsync.valueOrNull?.displayName ?? '...'),
                          subtitle: Text(comment.text),
                          trailing: (myUid != null &&
                                  (myUid == comment.authorUid ||
                                      myUid == widget.post.authorUid))
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.textMuted),
                                  onPressed: () {
                                    ref
                                        .read(postControllerProvider.notifier)
                                        .deleteComment(
                                          postId: widget.post.id,
                                          commentId: comment.id,
                                          authorUid: comment.authorUid,
                                          requestedByUid: myUid,
                                        );
                                  },
                                )
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textAlign: TextAlign.right,
                      decoration:
                          const InputDecoration(hintText: 'أضف تعليقًا...'),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send, color: AppColors.gold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
