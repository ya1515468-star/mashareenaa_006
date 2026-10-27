import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failure_text.dart';

/// تفاعلات وتعليقات ومشاركة — لأي محتوى.
///
/// `targetType` من ثلاثة: ad | wall_product | showcase. موحَّدةٌ عمدًا:
/// الإعلانات والمنتجات والمعروضات تحتاج الشيء نفسه، وثلاث نسخ منه
/// تعني أنّ إضافة تفاعل أو إخفاء تعليق مخالف يلزمه ثلاثة تعديلات
/// فيُنسى أحدها.
///
/// والعدّ والتفاعل من الخادم لا من العميل: الخادم يتحقّق أنّ المحتوى
/// مرئيٌّ للعضو قبل أي تفاعل، وإلّا صار التفاعل أداة استطلاع — يُجرَّب
/// معرّف فإن قُبل فالمحتوى موجود.

final reactionTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final raw = await Supabase.instance.client.rpc('get_reaction_types');
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  } catch (_) {
    return const [];
  }
});

final quickPhrasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final raw = await Supabase.instance.client.rpc('get_quick_comment_phrases');
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  } catch (_) {
    return const [];
  }
});

typedef ContentTarget = ({String type, String id});

final contentReactionsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ContentTarget>((ref, t) async {
  final raw = await Supabase.instance.client.rpc('get_content_reactions',
      params: {'p_target_type': t.type, 'p_target_id': t.id});
  return raw is Map ? Map<String, dynamic>.from(raw) : const {};
});

final contentCommentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ContentTarget>((ref, t) async {
  final raw = await Supabase.instance.client.rpc('get_content_comments',
      params: {'p_target_type': t.type, 'p_target_id': t.id, 'p_limit': 100});
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
});

class ContentInteractionBar extends ConsumerWidget {
  const ContentInteractionBar({
    super.key,
    required this.targetType,
    required this.targetId,
    this.shareText,
    this.compact = false,
  });

  final String targetType;
  final String targetId;

  /// نصّ يُرسَل عند المشاركة إلى غرفة أو خاص.
  final String? shareText;
  final bool compact;

  ContentTarget get _t => (type: targetType, id: targetId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(contentReactionsProvider(_t)).valueOrNull;
    final mine = reactions?['mine']?.toString();
    final total = (reactions?['total'] as num?)?.toInt() ?? 0;
    final counts = reactions?['counts'] is Map
        ? Map<String, dynamic>.from(reactions!['counts'] as Map)
        : const <String, dynamic>{};
    final comments = ref.watch(contentCommentsProvider(_t)).valueOrNull;
    final types = ref.watch(reactionTypesProvider).valueOrNull ?? const [];

    final myType = types.firstWhere(
      (e) => e['reaction'] == mine,
      orElse: () => const <String, dynamic>{},
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (total > 0 || (comments?.isNotEmpty ?? false))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            // أكثر ثلاثة تفاعلات: إظهار الستّة كلّها على بطاقة صغيرة
            // يُزاحم المحتوى نفسه.
            ...(counts.entries.toList()
                  ..sort((a, b) => ((b.value as num?) ?? 0)
                      .compareTo((a.value as num?) ?? 0)))
                .take(3)
                .map((e) {
              final t = types.firstWhere((x) => x['reaction'] == e.key,
                  orElse: () => const <String, dynamic>{});
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('${t['emoji'] ?? '👍'}',
                    style: const TextStyle(fontSize: 12)),
              );
            }),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('$total',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white54)),
              ),
            const Spacer(),
            if (comments != null && comments.isNotEmpty)
              Text('${comments.length} تعليقًا',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      Row(children: [
        Expanded(
          child: _BarButton(
            emoji: myType['emoji']?.toString() ?? '👍',
            label: myType['label']?.toString() ?? 'أعجبني',
            active: mine != null,
            compact: compact,
            // نقرة = أعجبني · ضغط مطوّل = اختيار التفاعل. وهو ما يتوقّعه
            // من استعمل فيسبوك، فلا يحتاج شرحًا.
            onTap: () => _react(context, ref, mine == null ? 'like' : mine),
            onLongPress: () => _pickReaction(context, ref, types),
          ),
        ),
        Expanded(
          child: _BarButton(
            emoji: '💬',
            label: 'تعليق',
            compact: compact,
            onTap: () => _openComments(context, ref),
          ),
        ),
        Expanded(
          child: _BarButton(
            emoji: '↗️',
            label: 'مشاركة',
            compact: compact,
            onTap: () => _share(context, ref),
          ),
        ),
      ]),
    ]);
  }

  Future<void> _react(BuildContext context, WidgetRef ref, String r) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('react_to_content', params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reaction': r,
      });
      ref.invalidate(contentReactionsProvider(_t));
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text(FailureText.action(e, action: 'التفاعل'))));
    }
  }

  Future<void> _pickReaction(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> types) async {
    if (types.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF160C2C),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in types)
                InkWell(
                  onTap: () => Navigator.pop(c, t['reaction']?.toString()),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(children: [
                      Text('${t['emoji'] ?? ''}',
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text('${t['label'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) {
      await _react(context, ref, picked);
    }
  }

  Future<void> _openComments(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => _CommentsSheet(targetType: targetType, targetId: targetId),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => ShareToSheet(
        text: shareText ?? '',
        targetType: targetType,
        targetId: targetId,
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.compact = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 13 : 15)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: compact ? 11 : 12.5,
                color: active ? const Color(0xFFFFD700) : Colors.white70,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              )),
        ]),
      ),
    );
  }
}

/// ورقة التعليقات مع العبارات الجاهزة.
class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.targetType, required this.targetId});
  final String targetType;
  final String targetId;
  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  ContentTarget get _t => (type: widget.targetType, id: widget.targetId);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send(String body) async {
    final text = body.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('comment_on_content', params: {
        'p_target_type': widget.targetType,
        'p_target_id': widget.targetId,
        'p_body': text,
      });
      _ctrl.clear();
      ref.invalidate(contentCommentsProvider(_t));
    } catch (e) {
      final s = e.toString();
      messenger?.showSnackBar(SnackBar(
        content: Text(s.contains('COMMENT_RATE_LIMIT')
            ? 'أكثرتَ من التعليقات — انتظر قليلًا'
            : FailureText.action(e, action: 'إضافة التعليق')),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client
          .rpc('delete_content_comment', params: {'p_id': id});
      ref.invalidate(contentCommentsProvider(_t));
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text(FailureText.action(e, action: 'الحذف'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(contentCommentsProvider(_t));
    final phrases = ref.watch(quickPhrasesProvider).valueOrNull ?? const [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          maxChildSize: .95,
          builder: (_, scroll) => Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                Text('💬  التعليقات',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: comments.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(FailureText.of(e, subject: 'التعليقات'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? const Center(
                        child: Text('لا تعليقات بعد — كن أوّل المعلّقين',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12.5)))
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return _CommentRow(
                            comment: c,
                            onDelete: () => _delete('${c['id']}'),
                          );
                        },
                      ),
              ),
            ),
            // العبارات الجاهزة: نقرة واحدة بدل كتابة. على هاتف بلوحة
            // مفاتيح عربية بطيئة هذا فرق بين أن يُعلَّق وألّا يُعلَّق.
            if (phrases.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (final p in phrases)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ActionChip(
                          backgroundColor: Colors.white.withValues(alpha: .06),
                          side: const BorderSide(color: Colors.white12),
                          label: Text('${p['emoji'] ?? ''} ${p['text'] ?? ''}',
                              style: const TextStyle(fontSize: 11.5)),
                          onPressed: _busy
                              ? null
                              : () => _send('${p['text'] ?? ''}'),
                        ),
                      ),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تعليقًا…',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _busy ? null : () => _send(_ctrl.text),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Color(0xFFFFD700)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onDelete});
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final avatar = comment['avatar']?.toString() ?? '';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white12,
        backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
        child: avatar.isEmpty
            ? const Icon(Icons.person, size: 16, color: Colors.white38)
            : null,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${comment['name'] ?? 'عضو'}',
                style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${comment['body'] ?? ''}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.5)),
          ]),
        ),
      ),
      if (comment['is_mine'] == true)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline,
              size: 16, color: Colors.white38),
          onPressed: onDelete,
        ),
    ]);
  }
}

/// مشاركة محتوى إلى غرفة أو محادثة خاصة.
class ShareToSheet extends ConsumerStatefulWidget {
  const ShareToSheet({
    super.key,
    required this.text,
    required this.targetType,
    required this.targetId,
  });

  final String text;
  final String targetType;
  final String targetId;

  @override
  ConsumerState<ShareToSheet> createState() => _ShareToSheetState();
}

class _ShareToSheetState extends ConsumerState<ShareToSheet> {
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _threads = const [];
  bool _loading = true;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('get_share_targets', params: {'p_limit': 40});
      final m = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      if (!mounted) return;
      setState(() {
        _rooms = (m['rooms'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _threads = (m['threads'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureText.of(e, subject: 'قائمة المشاركة');
        _loading = false;
      });
    }
  }

  Future<void> _send(
      {String? roomId, String? threadId, required String key}) async {
    setState(() => _busy = key);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('share_content', params: {
        'p_target_type': widget.targetType,
        'p_target_id': widget.targetId,
        'p_room_id': roomId,
        'p_thread_id': threadId,
      });
      if (!mounted) return;
      Navigator.of(context).maybePop();
      messenger?.showSnackBar(const SnackBar(
        content: Text('تمت المشاركة ✓'),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text(FailureText.action(e, action: 'المشاركة'))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, scroll) => Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Text('↗️  مشاركة إلى',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ),
                      )
                    : ListView(
                        controller: scroll,
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_rooms.isNotEmpty) ...[
                            const _ShareSectionTitle('💬 الغرف'),
                            for (final r in _rooms)
                              _ShareTile(
                                title: '${r['name'] ?? 'غرفة'}',
                                busy: _busy == 'room:${r['id']}',
                                onTap: () => _send(
                                    roomId: '${r['id']}',
                                    key: 'room:${r['id']}'),
                              ),
                          ],
                          if (_threads.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const _ShareSectionTitle('✉️ المحادثات'),
                            for (final t in _threads)
                              _ShareTile(
                                title: '${t['name'] ?? 'محادثة'}',
                                busy: _busy == 'thread:${t['id']}',
                                onTap: () => _send(
                                    threadId: '${t['id']}',
                                    key: 'thread:${t['id']}'),
                              ),
                          ],
                          if (_rooms.isEmpty && _threads.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(
                                child: Text(
                                    'لا غرف ولا محادثات للمشاركة فيها بعد',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 12.5)),
                              ),
                            ),
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}

class _ShareSectionTitle extends StatelessWidget {
  const _ShareSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12.5,
                fontWeight: FontWeight.w900)),
      );
}

class _ShareTile extends StatelessWidget {
  const _ShareTile(
      {required this.title, required this.onTap, required this.busy});
  final String title;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        trailing: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send_rounded, size: 16, color: Colors.white38),
        onTap: busy ? null : onTap,
      );
}
