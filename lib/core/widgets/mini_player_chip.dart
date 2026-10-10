import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mini_player_provider.dart';

/// أيقونة تشغيل يوتيوب صغيرة تظهر بجانب زر السمايل فقط حين تكون النافذة
/// العائمة مصغَّرة. الضغط يعيد النافذة، والضغط المطوّل يوقف التشغيل ويغلقها.
/// بلا tooltip عمدًا (قد تُستعمل حيث لا Overlay).
class MiniPlayerChip extends ConsumerWidget {
  const MiniPlayerChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(miniPlayerProvider);
    final minimized = ref.watch(miniPlayerMinimizedProvider);
    if (track == null || !minimized) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(miniPlayerMinimizedProvider.notifier).state = false,
      onLongPress: () {
        ref.read(miniPlayerProvider.notifier).state = null;
        ref.read(miniPlayerMinimizedProvider.notifier).state = false;
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(Icons.play_circle_fill_rounded,
            color: Color(0xFFFF0000), size: 26),
      ),
    );
  }
}
