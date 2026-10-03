import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../member_badge_providers.dart';

/// طبقة مستقلة: GIF فوق قالب الاسم فقط.
class MemberBadgeWidget extends ConsumerWidget {
  final String userId;
  final double maxWidth;
  final double maxHeight;
  final bool center;

  const MemberBadgeWidget({
    super.key,
    required this.userId,
    this.maxWidth = 44,
    this.maxHeight = 34,
    this.center = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberBadgeForUserProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (badge) {
        final url = badge?['asset_url']?.toString().trim();
        if (url == null || url.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: center ? Alignment.center : Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
