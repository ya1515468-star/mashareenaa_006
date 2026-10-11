import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../domain/entities/call_entity.dart';

/// بطاقة مكالمة واردة عائمة بأسلوب واتساب: صورة المتصل واسمه، وهاتف أخضر
/// يُسحب للأعلى للرد (أو للأسفل للرفض)، مع زرّي ضغط احتياطيين.
class IncomingCallCard extends ConsumerStatefulWidget {
  final String callerUid;
  final CallType type;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingCallCard({
    super.key,
    required this.callerUid,
    required this.type,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  ConsumerState<IncomingCallCard> createState() => _IncomingCallCardState();
}

class _IncomingCallCardState extends ConsumerState<IncomingCallCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
  double _dy = 0;
  bool _done = false;

  static const double _track = 90;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _finish(bool accept) {
    if (_done) return;
    _done = true;
    accept ? widget.onAccept() : widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final caller = ref.watch(profileByIdProvider(widget.callerUid)).valueOrNull;
    final isVideo = widget.type == CallType.video;
    final progress = (_dy.abs() / _track).clamp(0.0, 1.0);
    final accepting = _dy < 0;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF111B21),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25D366).withValues(alpha: .15 + .35 * _pulse.value),
                      blurRadius: 18 + 16 * _pulse.value,
                      spreadRadius: 3 + 5 * _pulse.value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: ProfileAvatar(
                avatarUrl: caller?.avatarUrl,
                displayName: caller?.displayName ?? '',
                radius: 52,
                frameKey: caller?.avatarFrameKey,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              caller?.displayName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: const Color(0xFF25D366), size: 22),
            const SizedBox(height: 18),
            SizedBox(
              height: _track * 2 + 64,
              width: 80,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF25D366).withValues(alpha: .35),
                        Colors.white10,
                        const Color(0xFFE53935).withValues(alpha: .35),
                      ],
                    ),
                  ),
                ),
                const Positioned(top: 10, child: Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF25D366), size: 30)),
                const Positioned(bottom: 10, child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFE53935), size: 30)),
                Transform.translate(
                  offset: Offset(0, _dy),
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) =>
                        setState(() => _dy = (_dy + d.delta.dy).clamp(-_track, _track)),
                    onVerticalDragEnd: (_) {
                      if (_dy <= -_track * .8) {
                        _finish(true);
                      } else if (_dy >= _track * .8) {
                        _finish(false);
                      } else {
                        setState(() => _dy = 0);
                      }
                    },
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(const Color(0xFF25D366), const Color(0xFFE53935),
                            accepting ? 0 : progress)!,
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                      ),
                      child: Transform.rotate(
                        angle: (accepting ? 0 : progress) * 2.356,
                        child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                onPressed: () => _finish(false),
                icon: const Icon(Icons.call_end_rounded, color: Colors.white),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                onPressed: () => _finish(true),
                icon: const Icon(Icons.call_rounded, color: Colors.white),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
