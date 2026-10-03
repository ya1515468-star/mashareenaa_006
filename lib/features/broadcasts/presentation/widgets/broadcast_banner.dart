import 'package:flutter/material.dart';
import '../../domain/entities/broadcast_entity.dart';

/// عرض بث موجّه إلى مستخدمين محددين.
/// التخزين الدائم لحالة العرض سيضاف لاحقًا عبر Supabase.
class BroadcastBanner {
  static OverlayEntry? _current;
  static final Set<String> _shownIds = <String>{};

  static Future<void> showIfVisible(
    BuildContext context,
    BroadcastEntity broadcast, {
    required String? currentUserUid,
    required bool currentUserIsPlatformOwner,
  }) async {
    final visible = broadcast.isVisibleTo(
      currentUserUid: currentUserUid,
      currentUserIsPlatformOwner: currentUserIsPlatformOwner,
    );

    if (!visible) {
      return;
    }

    if (_shownIds.contains(broadcast.id)) {
      return;
    }

    _shownIds.add(broadcast.id);

    if (!context.mounted) {
      return;
    }

    try {
      _current?.remove();

      final overlay = Overlay.of(context, rootOverlay: true);

      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => _BroadcastBannerWidget(
          broadcast: broadcast,
          onFinished: () {
            if (entry.mounted) {
              entry.remove();
            }

            if (_current == entry) {
              _current = null;
            }
          },
        ),
      );

      _current = entry;
      overlay.insert(entry);
    } catch (_) {
      _shownIds.remove(broadcast.id);
    }
  }
}

class _BroadcastBannerWidget extends StatefulWidget {
  final BroadcastEntity broadcast;
  final VoidCallback onFinished;

  const _BroadcastBannerWidget({
    required this.broadcast,
    required this.onFinished,
  });

  @override
  State<_BroadcastBannerWidget> createState() => _BroadcastBannerWidgetState();
}

class _BroadcastBannerWidgetState extends State<_BroadcastBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.forward();

    Future<void>.delayed(
      const Duration(seconds: 6),
      () async {
        if (!mounted) {
          return;
        }

        await _controller.reverse();

        if (mounted) {
          widget.onFinished();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slide,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7A1F3D),
                  Color(0xFFD4AF37),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  '🐉',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.broadcast.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed: () async {
                    await _controller.reverse();

                    if (mounted) {
                      widget.onFinished();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
