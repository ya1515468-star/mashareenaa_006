import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'typing_and_presence_widgets.dart';

/// Window state of the floating private chat.
enum MiniChatMode { minimized, normal, fullscreen }

class MiniChatTarget {
  final String threadId;
  final String peerUid;
  final String peerName;
  final String? peerAvatar;
  const MiniChatTarget({
    required this.threadId,
    required this.peerUid,
    required this.peerName,
    this.peerAvatar,
  });
}

/// Holds which private conversation is floating over the room, if any.
final miniChatTargetProvider = StateProvider<MiniChatTarget?>((ref) => null);
final miniChatModeProvider = StateProvider<MiniChatMode>((ref) => MiniChatMode.normal);

/// Threads the user explicitly closed with the ✕ button during this room
/// visit. The auto-open-on-new-message listener checks this so it never
/// forces a conversation back open against the user's own choice — "the
/// user decides", not the app.
final dismissedThreadIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Closes the window AND remembers the dismissal, so the auto-open listener
/// never springs it back open for the same conversation without the user
/// asking for it again.
void _closeAndDismiss(WidgetRef ref, String threadId) {
  ref.read(dismissedThreadIdsProvider.notifier).update((s) => {...s, threadId});
  ref.read(miniChatTargetProvider.notifier).state = null;
}

/// نقطة الدخول الوحيدة لفتح أي محادثة خاصة في التطبيق كله.
///
/// المراسلة الخاصة تظهر حصرًا كنافذة عائمة فوق الغرفة (لا صفحة كاملة)، لأن
/// النافذة تعيش داخل ChatLobbyPage نفسها؛ لذلك تعود هذه الدالة إلى شاشة
/// الغرفة أولًا ثم تفتح النافذة هناك. استخدامها من كل مكان (الملف الشخصي،
/// قائمة المحادثات، نافذة العضو المصغّرة، دليل الأعمال...) يضمن سلوكًا
/// واحدًا موحَّدًا بدل تكرار منطق التنقّل في كل شاشة على حدة.
void openPrivateChat(
  BuildContext context,
  WidgetRef ref, {
  required String threadId,
  required String peerUid,
  required String peerName,
  String? peerAvatar,
}) {
  ref
      .read(dismissedThreadIdsProvider.notifier)
      .update((s) => {...s}..remove(threadId));
  ref.read(miniChatTargetProvider.notifier).state = MiniChatTarget(
    threadId: threadId,
    peerUid: peerUid,
    peerName: peerName,
    peerAvatar: peerAvatar,
  );
  // العودة لشاشة الغرفة حيث تُعرض النافذة العائمة فعليًا. إن كانت الغرفة
  // هي الشاشة الحالية أصلًا، لا يُزال شيء من المكدّس.
  Navigator.of(context).popUntil((route) => route.isFirst);
}

// Presence now comes from the single shared privacyAwarePresenceProvider
// (typing_and_presence_widgets.dart) instead of a second, separately
// defined provider here. Two providers calling the identical RPC still
// meant two independent cache entries that could show different values
// mid-transition — the exact "online AND offline at once" bug reported.


/// The signed-in user's wallpaper for ONE conversation. Each thread is stored
/// separately, so talking to five people can mean five different backgrounds.
final miniChatWallpaperProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, threadId) async {
  final raw = await Supabase.instance.client
      .rpc('get_my_chat_wallpaper', params: {'p_thread_id': threadId});
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

/// Renders the three-state floating window. Placed in a Stack above the room
/// so the public chat stays visible and usable underneath.
class MiniChatOverlay extends ConsumerWidget {
  /// The actual conversation UI, supplied by the caller so this widget stays
  /// purely about windowing.
  final Widget Function(MiniChatTarget target) contentBuilder;
  const MiniChatOverlay({super.key, required this.contentBuilder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(miniChatTargetProvider);
    if (target == null) return const SizedBox.shrink();
    final mode = ref.watch(miniChatModeProvider);
    final size = MediaQuery.sizeOf(context);

    if (mode == MiniChatMode.minimized) {
      return Positioned(
        // Sits ABOVE the composer instead of on top of it. At bottom:12 the
        // bar covered the public chat's send button, so minimising the private
        // chat blocked sending in the room — the opposite of the point.
        right: 12,
        bottom: 96,
        // A Positioned with only right/bottom hands its child UNBOUNDED width.
        // The Row inside then passed w=Infinity down to its IconButton, whose
        // internal padding asserts on infinite width — which is exactly the
        // "BoxConstraints forces an infinite width" crash the monitor caught,
        // and every "RenderBox was not laid out" line after it was a knock-on
        // effect of that single failure. Constraining the bar fixes all of them.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width - 40).clamp(160.0, 320.0),
          ),
          child: _MinimizedBar(target: target),
        ),
      );
    }

    final isFull = mode == MiniChatMode.fullscreen;
    final w = isFull ? size.width : (size.width * .82).clamp(280.0, 420.0);
    final h = isFull ? size.height : (size.height * .52).clamp(320.0, 520.0);

    return Positioned(
      right: isFull ? 0 : 10,
      bottom: isFull ? 0 : 10,
      left: isFull ? 0 : null,
      top: isFull ? 0 : null,
      child: Material(
        elevation: 16,
        borderRadius: BorderRadius.circular(isFull ? 0 : 14),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF171126),
        child: SizedBox(
          width: w,
          height: h,
          child: Column(
            children: [
              _WindowBar(target: target, mode: mode),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  children: [
                    // Per-conversation wallpaper sits BEHIND the messages and
                    // is dimmed by its stored opacity so text stays readable
                    // whatever image the user picked.
                    Positioned.fill(child: _Wallpaper(threadId: target.threadId)),
                    Positioned.fill(child: contentBuilder(target)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimizedBar extends ConsumerWidget {
  final MiniChatTarget target;
  const _MinimizedBar({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 12,
      color: const Color(0xFF241A3A),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () =>
            ref.read(miniChatModeProvider.notifier).state = MiniChatMode.normal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeerAvatar(uid: target.peerUid, avatarUrl: target.peerAvatar, radius: 11),
              const SizedBox(width: 8),
              Text(target.peerName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _closeAndDismiss(ref, target.threadId),
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'إغلاق',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowBar extends ConsumerWidget {
  final MiniChatTarget target;
  final MiniChatMode mode;
  const _WindowBar({required this.target, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF241A3A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _PeerAvatar(uid: target.peerUid, avatarUrl: target.peerAvatar, radius: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(target.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                _PresenceLabel(uid: target.peerUid),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'خلفية المحادثة',
            onPressed: () => showChatWallpaperDialog(context, ref, threadId: target.threadId),
            icon: const Icon(Icons.wallpaper, size: 16),
          ),
          // كان هنا زرَّا اتصال مضافان بالخطأ — المحتوى المعروض داخل هذه
          // النافذة هو ChatThreadPage الكاملة (انظر contentBuilder في
          // chat_lobby_page.dart)، ولها بالفعل أزرار اتصال خاصة بها في
          // شريطها العلوي. الإضافة السابقة كانت تكرارًا حقيقيًا ظاهرًا في
          // الواجهة، لا إصلاحًا لعطل حقيقي.
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تصغير',
            onPressed: () => ref.read(miniChatModeProvider.notifier).state =
                MiniChatMode.minimized,
            icon: const Icon(Icons.remove, size: 18),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: mode == MiniChatMode.fullscreen ? 'استعادة' : 'ملء الشاشة',
            onPressed: () => ref.read(miniChatModeProvider.notifier).state =
                mode == MiniChatMode.fullscreen
                    ? MiniChatMode.normal
                    : MiniChatMode.fullscreen,
            icon: Icon(
                mode == MiniChatMode.fullscreen
                    ? Icons.close_fullscreen
                    : Icons.open_in_full,
                size: 16),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'إغلاق',
            onPressed: () => _closeAndDismiss(ref, target.threadId),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

/// The peer's real profile photo, with the presence dot overlaid as a small
/// badge — this replaces what used to be JUST the dot with nothing else,
/// which is why no photo ever appeared in the floating window's bar despite
/// the target's avatar URL already being available on MiniChatTarget.
class _PeerAvatar extends ConsumerWidget {
  final String uid;
  final String? avatarUrl;
  final double radius;
  const _PeerAvatar({required this.uid, required this.avatarUrl, this.radius = 12});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(privacyAwarePresenceProvider(uid)).valueOrNull?['is_online'] == true;
    final url = avatarUrl?.trim() ?? '';
    return SizedBox(
      width: radius * 2 + 3,
      height: radius * 2 + 3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white24,
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty
                ? Icon(Icons.person, size: radius * .9, color: Colors.white70)
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * .55,
              height: radius * .55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.greenAccent : Colors.grey,
                border: Border.all(color: const Color(0xFF171126), width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceLabel extends ConsumerWidget {
  final String uid;
  const _PresenceLabel({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(privacyAwarePresenceProvider(uid)).valueOrNull;
    if (data == null) return const SizedBox.shrink();
    final online = data['is_online'] == true;
    return Text(
      online ? 'متصل' : 'غير متصل',
      style: TextStyle(
        fontSize: 10,
        color: online ? Colors.greenAccent : Colors.white38,
      ),
    );
  }
}

/// The ✓ / ✓✓ / ✓✓(blue) indicator for a message I sent.
///
/// Reads the server's own status value. When the recipient is hiding their
/// receipts, the server never advances that value, so this naturally keeps
/// showing a single tick — no special client-side case is needed, and nothing
/// about the hidden state is shipped to this device at all.
class MessageTicks extends StatelessWidget {
  final String status;
  final double size;
  const MessageTicks({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    if (s == 'seen' || s == 'read') {
      return Icon(Icons.done_all, size: size, color: Colors.lightBlueAccent);
    }
    if (s == 'delivered') {
      return Icon(Icons.done_all, size: size, color: Colors.white54);
    }
    return Icon(Icons.done, size: size, color: Colors.white54);
  }
}


class _Wallpaper extends ConsumerWidget {
  final String threadId;
  const _Wallpaper({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(miniChatWallpaperProvider(threadId)).valueOrNull;
    final url = data?['image_url']?.toString().trim() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    final opacity = (data?['opacity'] as num?)?.toDouble() ?? 0.35;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        // A broken wallpaper must never hide the conversation.
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Lets the user pick a wallpaper for THIS conversation only.
/// The server rejects the change when the VIP service is not owned, and that
/// rejection is surfaced plainly instead of failing silently.
Future<void> showChatWallpaperDialog(
  BuildContext context,
  WidgetRef ref, {
  required String threadId,
}) async {
  final existing = ref.read(miniChatWallpaperProvider(threadId)).valueOrNull;
  String? pickedUrl = existing?['image_url']?.toString();
  double opacity = (existing?['opacity'] as num?)?.toDouble() ?? 0.35;
  bool uploading = false;
  String? uploadError;

  /// Reads the picked file as bytes and uploads it — the same proven
  /// pattern already used elsewhere in this project (admin_login_
  /// announcement_tab.dart), chosen specifically because it works
  /// identically on web (where image_picker's File-path API does not
  /// apply) and on mobile.
  Future<String?> pickAndUpload() async {
    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw StateError('INVALID_IMAGE');
    if (bytes.length > 6 * 1024 * 1024) throw StateError('IMAGE_TOO_LARGE');
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    if (!const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) {
      throw StateError('INVALID_IMAGE');
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('AUTH_REQUIRED');
    // Keyed by thread so re-uploading for the SAME conversation overwrites
    // the old file instead of accumulating orphaned images per user.
    final path = '$uid/$threadId.$ext';
    await Supabase.instance.client.storage.from('chat-wallpapers').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return Supabase.instance.client.storage.from('chat-wallpapers').getPublicUrl(path);
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: const Text('خلفية هذه المحادثة', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pickedUrl != null && pickedUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(pickedUrl!, height: 110, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 110)),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: uploading
                  ? null
                  : () async {
                      setLocal(() {
                        uploading = true;
                        uploadError = null;
                      });
                      try {
                        final url = await pickAndUpload();
                        if (url != null) pickedUrl = url;
                      } catch (e) {
                        uploadError = e.toString().contains('FORBIDDEN') ||
                                e.toString().contains('row-level security')
                            ? 'خلفية المحادثة خدمة VIP — فعّلها أولًا.'
                            : e.toString().contains('IMAGE_TOO_LARGE')
                                ? 'الصورة أكبر من 6 ميجابايت.'
                                : 'تعذّر رفع الصورة.';
                      } finally {
                        setLocal(() => uploading = false);
                      }
                    },
              icon: uploading
                  ? const SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(uploading ? 'جارٍ الرفع…' : 'اختيار صورة من الهاتف'),
            ),
            if (uploadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(uploadError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ),
            const SizedBox(height: 14),
            Row(children: [
              const Text('الشفافية', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: opacity,
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  label: '${(opacity * 100).round()}%',
                  onChanged: (v) => setLocal(() => opacity = v),
                ),
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.rpc('set_my_chat_wallpaper',
                    params: {'p_thread_id': threadId, 'p_image_url': null});
                ref.invalidate(miniChatWallpaperProvider(threadId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {}
            },
            child: const Text('إزالة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: (pickedUrl == null || pickedUrl!.isEmpty)
                ? null
                : () async {
                    try {
                      await Supabase.instance.client.rpc('set_my_chat_wallpaper', params: {
                        'p_thread_id': threadId,
                        'p_image_url': pickedUrl,
                        'p_opacity': opacity,
                      });
                      ref.invalidate(miniChatWallpaperProvider(threadId));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      if (dialogContext.mounted) {
                        final needsVip =
                            e.toString().contains('FEATURE_REQUIRED_CHAT_WALLPAPER');
                        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                          content: Text(needsVip
                              ? 'خلفية المحادثة خدمة VIP — فعّلها من خدمات VIP أولًا.'
                              : 'تعذر حفظ الخلفية.'),
                        ));
                      }
                    }
                  },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
