import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/chat_provider.dart';
import '../../domain/entities/chat_message_entity.dart';

/// إعادة توجيه رسالة إلى محادثة خاصة أخرى: قائمة بمحادثاتك، اختيار واحدة
/// يرسل نسخة من محتوى الرسالة إليها فورًا.
class ForwardMessageSheet {
  static Future<void> show(
    BuildContext context, {
    required String body,
    required String kind,
    String? attachmentUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => _ForwardBody(body: body, kind: kind, attachmentUrl: attachmentUrl),
    );
  }
}

class _ForwardBody extends ConsumerStatefulWidget {
  final String body;
  final String kind;
  final String? attachmentUrl;
  const _ForwardBody({required this.body, required this.kind, this.attachmentUrl});

  @override
  ConsumerState<_ForwardBody> createState() => _ForwardBodyState();
}

class _ForwardBodyState extends ConsumerState<_ForwardBody> {
  List<Map<String, dynamic>>? _threads;
  String? _sendingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  MessageType _typeFromKind(String kind) {
    switch (kind) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'gif': return MessageType.gif;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  Future<void> _load() async {
    try {
      final raw = await Supabase.instance.client.rpc('list_my_threads', params: {'p_limit': 60});
      if (mounted) setState(() => _threads = List<Map<String, dynamic>>.from(raw as List));
    } catch (_) {
      if (mounted) setState(() => _threads = const []);
    }
  }

  Future<void> _forwardTo(Map<String, dynamic> thread) async {
    final otherUid = thread['other_uid']?.toString();
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (otherUid == null || myUid == null) return;
    setState(() => _sendingTo = thread['id']?.toString());
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      // نفس مسار الإرسال الحقيقي المستعمل في كل محادثة خاصة بالتطبيق —
      // لا استدعاء RPC منفصل مُخترَع لهذه الميزة وحدها.
      final ok = await ref.read(chatControllerProvider.notifier).sendMessage(
            fromUid: myUid,
            toUid: otherUid,
            text: widget.body,
            type: _typeFromKind(widget.kind),
            mediaUrl: widget.attachmentUrl,
          );
      if (!ok) throw StateError('فشل الإرسال');
      if (!mounted) return;
      Navigator.pop(context);
      m?.showSnackBarSfx(SnackBar(content: Text('أُعيد التوجيه إلى ${thread['other_name'] ?? 'المحادثة'} ✓')));
    } catch (e) {
      m?.showSnackBarSfx(SnackBar(content: Text('تعذّر إعادة التوجيه: $e')));
    } finally {
      if (mounted) setState(() => _sendingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('إعادة توجيه إلى…',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: _threads == null
                  ? const Center(child: CircularProgressIndicator())
                  : _threads!.isEmpty
                      ? const Center(
                          child: Text('لا توجد محادثات بعد', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _threads!.length,
                          itemBuilder: (_, i) {
                            final t = _threads![i];
                            final name = t['other_name']?.toString() ?? 'عضو';
                            final avatar = t['other_avatar']?.toString() ?? '';
                            final sending = _sendingTo == t['id']?.toString();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white)),
                              trailing: sending
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send_rounded, color: Colors.white38, size: 18),
                              onTap: sending ? null : () => _forwardTo(t),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
