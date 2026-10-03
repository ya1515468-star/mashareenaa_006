import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/chat_repository.dart';

/// The ONE privacy-aware source of a person's presence, used everywhere a
/// screen shows another user's online/offline state. It always calls
/// get_profile_for_viewer, which is the same function that already honours
/// both the paid "appear offline" service and the owner-held stealth
/// privilege — so no screen can ever show a status that contradicts what
/// another screen shows for the very same person at the very same moment
/// (the exact bug this replaces: a raw, privacy-blind stream showing
/// "متصل الآن" next to a privacy-aware label showing "غير متصل").
///
/// كانت FutureProvider — تجلب مرة واحدة فقط عند الإنشاء، بلا أي تحديث
/// تلقائي لاحق. عندما ظهرت شاشتان تراقبان نفس الشخص في لحظتين مختلفتين
/// قليلًا (شريط النافذة العائمة، وChatThreadPage المُضمَّنة داخلها)، كانت
/// كل واحدة تأخذ "لقطة" منفصلة وقتها الخاص — فإن تغيّرت حالة الشخص الحقيقية
/// بين اللقطتين، ظهر تناقض ظاهري بلا أي خطأ في المصدر نفسه، فكلاهما كان
/// صحيحًا وقت التقاطه فقط. البثّ الدوري المشترك هنا يحلّ هذا جذريًا: كل من
/// يراقب نفس uid يشارك نفس البثّ الحي نفسه دائمًا، فلا يمكن لشاشتين أن
/// تريا قيمتين مختلفتين لنفس الشخص في نفس اللحظة بعد الآن.
final privacyAwarePresenceProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>((ref, uid) {
  Future<Map<String, dynamic>> fetch() async {
    final raw = await Supabase.instance.client
        .rpc('get_profile_for_viewer', params: {'p_target_user_id': uid});
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  late final StreamController<Map<String, dynamic>> controller;
  Timer? timer;
  controller = StreamController<Map<String, dynamic>>(
    onListen: () async {
      controller.add(await fetch());
      timer = Timer.periodic(const Duration(seconds: 6), (_) async {
        if (controller.isClosed) return;
        controller.add(await fetch());
      });
    },
    onCancel: () {
      timer?.cancel();
    },
  );
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

class PrivacyAwarePresenceSubtitle extends StatelessWidget {
  final Map<String, dynamic>? data;
  const PrivacyAwarePresenceSubtitle({super.key, required this.data});

  String _label() {
    final d = data;
    if (d == null) return '';
    if (d['is_online'] == true) return 'متصل الآن';
    final lastSeenRaw = d['last_seen_at']?.toString();
    if (lastSeenRaw == null || lastSeenRaw.isEmpty) return '';
    final lastSeen = DateTime.tryParse(lastSeenRaw);
    if (lastSeen == null) return '';
    final diff = DateTime.now().toUtc().difference(lastSeen.toUtc());
    if (diff.inMinutes < 1) return 'آخر ظهور: الآن';
    if (diff.inMinutes < 60) return 'آخر ظهور: منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'آخر ظهور: منذ ${diff.inHours} ساعة';
    return 'آخر ظهور: منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final text = _label();
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: TextStyle(
          fontSize: 11,
          color: data?['is_online'] == true ? Colors.greenAccent : Colors.white54,
        ));
  }
}

class TypingIndicatorBar extends StatelessWidget {
  final bool visible;
  const TypingIndicatorBar({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('يكتب الآن...',
                      style: TextStyle(color: p.accent, fontSize: 12)),
                  const SizedBox(width: 6),
                  const _TypingDots(),
                ],
              ),
            ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.2) % 1.0;
            final scale = 0.6 + (t < 0.5 ? t : 1 - t);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: p.accent, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class PresenceSubtitle extends StatelessWidget {
  final UserPresence? presence;
  const PresenceSubtitle({super.key, required this.presence});

  String _label() {
    if (presence == null) return '';
    if (presence!.isOnline) return 'متصل الآن';
    final lastSeen = presence!.lastSeen;
    if (lastSeen == null) return '';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'آخر ظهور: الآن';
    if (diff.inMinutes < 60) return 'آخر ظهور: منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'آخر ظهور: منذ ${diff.inHours} ساعة';
    return 'آخر ظهور: منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    if (label.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        color: presence!.isOnline ? p.success : p.textMuted,
      ),
    );
  }
}
