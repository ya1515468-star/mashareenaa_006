import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/mini_chat_overlay.dart';

/// قائمة المحادثات الخاصة.
///
/// أفاتار + اسم + زر ✗ لإخفاء المحادثة، وزر Clear لإخفائها كلها،
/// وخيارات لكل محادثة: قفل الخاص، مسح المحتوى، حذف من القائمة.
///
/// "الحذف" هنا من عند صاحب الحساب وحده — الخادم يضيف معرّفه إلى
/// deleted_for_uids و hidden_for_uids ولا يمسّ نسخة الطرف الآخر.
/// مسح محادثة بين طرفين قرار أحادي لا يجوز أن يمحو أرشيف غيرك.

final _db = Supabase.instance.client;

final myThreadsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await _db.rpc('list_my_threads', params: {'p_limit': 80});
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

final myDmLockProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return false;
  final r = await _db
      .from('profiles')
      .select('dm_locked')
      .eq('id', uid)
      .maybeSingle();
  return r?['dm_locked'] == true;
});

class ConversationsPage extends ConsumerWidget {
  /// يُمرَّر حين تُعرض الصفحة داخل ورقة منزلقة، فتتشارك القائمة
  /// تمريرها مع الورقة: السحب لأسفل من أعلى القائمة يُغلق الورقة
  /// بدل أن يعلق التمرير. null = شاشة مستقلة.
  final ScrollController? scrollController;

  const ConversationsPage({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(myThreadsProvider);
    final locked = ref.watch(myDmLockProvider).valueOrNull ?? false;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0E2233),
          automaticallyImplyLeading: scrollController == null,
          title: const Text('الرسائل'),
          actions: [
            IconButton(
              tooltip: locked ? 'الخاص مقفل' : 'الخاص مفتوح',
              icon: Icon(locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: locked ? const Color(0xFFF59E0B) : Colors.white70),
              onPressed: () => _toggleLock(context, ref, locked),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('Clear',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              onPressed: () => _clearAll(context, ref),
            ),
          ],
        ),
        body: Column(children: [
          if (scrollController != null)
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          Expanded(
            child: threads.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded,
                    size: 40, color: Color(0xFFEF4444)),
                const SizedBox(height: 10),
                Text('$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12.5)),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(myThreadsProvider),
                    child: const Text('إعادة المحاولة')),
              ]),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined, size: 50, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('لا محادثات',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              );
            }
            return ListView.separated(
              controller: scrollController,
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10, indent: 76),
              itemBuilder: (_, i) => _ThreadTile(
                thread: list[i],
                onChanged: () => ref.invalidate(myThreadsProvider),
              ),
            );
          },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _toggleLock(
      BuildContext context, WidgetRef ref, bool current) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _db.rpc('set_my_dm_lock', params: {'p_locked': !current});
      ref.invalidate(myDmLockProvider);
      messenger?.showSnackBar(SnackBar(
        content: Text(!current
            ? '🔒 أُقفل الخاص — لن تستقبل رسائل إلا ممن تتابعهم'
            : '🔓 فُتح الخاص'),
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('تعذّر التغيير: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مسح كل المحادثات'),
          content: const Text(
              'ستُخفى كل المحادثات من قائمتك أنت فقط. الطرف الآخر يحتفظ بنسخته.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('مسح الكل')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await _db.rpc('clear_all_my_threads');
      ref.invalidate(myThreadsProvider);
      final n = (r is Map ? r['hidden'] : 0) ?? 0;
      messenger?.showSnackBar(SnackBar(
          content: Text('مُسحت $n محادثة'),
          backgroundColor: const Color(0xFF16A34A)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('تعذّر المسح: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }
}

class _ThreadTile extends ConsumerWidget {
  final Map<String, dynamic> thread;
  final VoidCallback onChanged;
  const _ThreadTile({required this.thread, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = thread['other_name']?.toString() ?? 'عضو';
    final avatar = thread['other_avatar']?.toString() ?? '';
    final unread = (thread['unread'] as num?)?.toInt() ?? 0;
    final last = thread['last_message_text']?.toString() ?? '';

    return ListTile(
      // لم يكن للصف أي onTap، فالضغط على اسم العضو لا يفعل شيئًا.
      // openPrivateChat هي المسار الموحّد: تفتح النافذة العائمة فوق الغرفة
      // وتغلق هذه الورقة.
      onTap: () {
        final peer = thread['other_uid']?.toString() ?? '';
        if (peer.isEmpty) return;
        openPrivateChat(
          context,
          ref,
          threadId: thread['id'].toString(),
          peerUid: peer,
          peerName: name,
          peerAvatar: avatar.isEmpty ? null : avatar,
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Stack(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white10,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? const Icon(Icons.person_rounded, color: Colors.white38)
              : null,
        ),
        if (unread > 0)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ]),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      subtitle: last.isEmpty
          ? null
          : Text(last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
      // هذا بالضبط نمط الانهيار المتكرر في السجل: trailing: Row بلا
      // حدّ عرض داخل ListView.separated (sliver_list فعليًا) — نفس
      // التتبّع (button_style_button.dart داخل sliver_list) الذي
      // ظل يتكرر رغم كل الإصلاحات السابقة في لوحة الإدارة، لأن
      // هذا الموضع في قائمة المحادثات نفسها لم يُفحَص من قبل.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 90),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'خيارات',
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white38),
            onPressed: () => _options(context),
          ),
          IconButton(
            tooltip: 'حذف من قائمتي',
            icon: const Icon(Icons.close_rounded, size: 26),
            onPressed: () => _hide(context),
          ),
        ]),
      ),
    );
  }

  Future<void> _options(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0E1628),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded,
                  color: Color(0xFFF59E0B)),
              title: const Text('مسح محتوى المحادثة'),

              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.redAccent),
              title: const Text('حذف المحادثة من قائمتي'),
              onTap: () => Navigator.pop(ctx, 'hide'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8)),
              title: const Text('قفل الخاص'),

              onTap: () => Navigator.pop(ctx, 'lock'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      switch (action) {
        case 'clear':
          await _db.rpc('clear_my_thread',
              params: {'p_thread_id': thread['id'].toString()});
          messenger?.showSnackBar(const SnackBar(
              content: Text('مُسح محتوى المحادثة'),
              backgroundColor: Color(0xFF16A34A)));
        case 'hide':
          await _db.rpc('hide_my_thread',
              params: {'p_thread_id': thread['id'].toString()});
          messenger?.showSnackBar(const SnackBar(
              content: Text('حُذفت من قائمتك'),
              backgroundColor: Color(0xFF16A34A)));
        case 'lock':
          await _db.rpc('set_my_dm_lock', params: {'p_locked': true});
          messenger?.showSnackBar(const SnackBar(
              content: Text('🔒 أُقفل الخاص'),
              backgroundColor: Color(0xFF16A34A)));
      }
      onChanged();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('تعذّر التنفيذ: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _hide(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _db.rpc('hide_my_thread',
          params: {'p_thread_id': thread['id'].toString()});
      onChanged();
      messenger?.showSnackBar(const SnackBar(
          content: Text('حُذفت من قائمتك'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('تعذّر الحذف: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }
}
