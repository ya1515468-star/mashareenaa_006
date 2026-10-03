import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_engagement_repository.dart';

final contentEngagementProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, contentId) async {
  return ContentEngagementRepository().get(contentId);
});

class ImageEngagementBadge extends ConsumerWidget {
  final String contentId;
  final String? ownerUserId;
  final VoidCallback? onInteraction;

  const ImageEngagementBadge({
    super.key,
    required this.contentId,
    this.ownerUserId,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(contentEngagementProvider(contentId)).valueOrNull;
    final count = (data?['total_engagement'] as num?)?.toInt() ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            await ContentEngagementRepository().record(
              contentId: contentId,
              eventType: 'interaction',
              ownerUserId: ownerUserId,
            );
            ref.invalidate(contentEngagementProvider(contentId));
            onInteraction?.call();
          } catch (_) {}
        },
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
