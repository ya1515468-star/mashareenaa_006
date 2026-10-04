import '../widgets/voice_hold_button.dart';
import '../../../../core/widgets/song_search_sheet.dart';
import '../../data/gif_catalog.dart';
import '../../../../core/providers/mini_player_provider.dart';
import 'dart:async';
import '../../../../core/monitoring/error_monitor.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/chat_sound_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/pages/active_call_page.dart';
import '../../../calls/presentation/providers/call_provider.dart';
import '../../../gifts/domain/entities/gift_entity.dart';
import '../../../gifts/presentation/providers/gift_provider.dart';
import '../../../gifts/presentation/widgets/gift_picker_sheet.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../subscriptions/presentation/widgets/membership_badge_widget.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../providers/chat_provider.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reply_and_attachment_widgets.dart';
import '../widgets/typing_and_presence_widgets.dart';
import '../../../vip/presentation/widgets/vip_presence_plus.dart';

final chatVoiceVideoServiceProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  // Was a separate, duplicated entitlement check (owner-bypass +
  // get_my_profile_services scan) that silently swallowed ANY error into
  // `false` — hiding the call buttons with no visible reason. Consolidated
  // onto the single server-authoritative function (the same one that
  // correctly handles an explicit user-level disable overriding a
  // membership grant), and errors are now reported to the monitor instead
  // of being swallowed silently.
  //
  // حل عاجل صريح: مالك المنصة يرى زر الاتصال دائمًا بلا أي شرط، بمعزل تام
  // عن أي تفصيل زمني أو تخزين مؤقت قد يؤثر على فحص الميزة الاستهلاكية —
  // هذا تجاوز مستقل، لا يعتمد على نجاح استدعاء is_my_profile_service إطلاقًا.
  try {
    final isOwner =
        await Supabase.instance.client.rpc('is_my_platform_owner');
    if (isOwner == true) return true;
  } catch (e, st) {
    unawaited(ErrorMonitor.report(e,
        stack: st, screen: 'chat_thread_page', source: 'is_my_platform_owner_check'));
  }
  try {
    final result = await Supabase.instance.client
        .rpc('is_my_profile_service', params: {'p_feature_key': 'voice_video_calls'});
    return result == true;
  } catch (e, st) {
    unawaited(ErrorMonitor.report(e,
        stack: st, screen: 'chat_thread_page', source: 'voice_video_calls_check'));
    return false;
  }
});

class ChatThreadPage extends ConsumerStatefulWidget {
  final String threadId;
  final String otherUid;
  final String otherName;

  const ChatThreadPage({
    super.key,
    required this.threadId,
    required this.otherUid,
    required this.otherName,
  });

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _textController = TextEditingController();
  bool _isTyping = false;
  bool _pinnedBannerDismissed = false;
  List<Map<String, dynamic>> _mentionSuggestions = const [];
  final Map<String, String> _mentionUserIds = {};
  Timer? _mentionTimer;
  Timer? _typingStopTimer;
  final Map<String, BuildContext> _messageContexts = {};
  final _sound = ChatSoundService(Supabase.instance.client);
  Color _mentionFrameColor = const Color(0xFFFFD54F);

  Future<void> _loadMentionFrameColor() async {
    try {
      final raw =
          await Supabase.instance.client.rpc('get_chat_username_frame_color');
      if (!mounted) return;
      setState(() => _mentionFrameColor = switch (raw?.toString()) {
            'red' => const Color(0xFFFF5252),
            'blue' => const Color(0xFF42A5F5),
            _ => const Color(0xFFFFD54F),
          });
    } catch (_) {}
  }

  void _insertMention(String name, String uid) {
    final mention = '${name.trim().replaceFirst(RegExp(r'^@'), '')} ';
    final s = _textController.selection;
    final at = s.isValid ? s.start : _textController.text.length;
    final end = s.isValid ? s.end : at;
    _textController.value = TextEditingValue(
        text: _textController.text.replaceRange(at, end, mention),
        selection: TextSelection.collapsed(offset: at + mention.length));
  }

  void _jumpToMessage(String id) {
    final ctx = _messageContexts[id];
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // رتبة المنصة للمستخدم الحالي: تُظهر "حذف إداري" للطاقم (مشرف فما فوق).
    // الخادم (delete_message) يفرض الهرم فعليًا ويرفض حذف رسالة من هو أعلى.
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me != null) {
      Supabase.instance.client
          .rpc('user_role_priority', params: {'p_uid': me})
          .then((v) { if (mounted) setState(() => _myPriority = (v as num?)?.toInt() ?? 0); })
          .catchError((_) {});
    }
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid != null) {
      Future.microtask(
        () => ref.read(chatControllerProvider.notifier).markRead(
              threadId: widget.threadId,
              uid: myUid,
            ),
      );
    }
    _textController.addListener(_onTextChanged);
    unawaited(_loadMentionFrameColor());
    // Captured while `ref` is still valid, for use in dispose().
    _myUidForDispose = ref.read(authControllerProvider).valueOrNull?.uid;
    _chatControllerForDispose = ref.read(chatControllerProvider.notifier);
  }

  String? _myUidForDispose;
  ChatController? _chatControllerForDispose;

  @override
  void dispose() {
    // `ref` is already invalid by the time dispose() runs, so reading it here
    // threw "Cannot use ref after the widget was disposed" every time this
    // page closed. Both values are captured during initState instead, and the
    // cached references are used here.
    final myUid = _myUidForDispose;
    if (myUid != null && _isTyping) {
      _chatControllerForDispose?.setTyping(
            threadId: widget.threadId,
            uid: myUid,
            isTyping: false,
          );
    }
    _mentionTimer?.cancel();
    _typingStopTimer?.cancel();
    _messageContexts.clear();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    final hasText = _textController.text.trim().isNotEmpty;
    _typingStopTimer?.cancel();
    if (hasText != _isTyping) {
      _isTyping = hasText;
      unawaited(ref.read(chatControllerProvider.notifier).setTyping(
            threadId: widget.threadId,
            uid: myUid,
            isTyping: hasText,
          ));
    }
    if (hasText) {
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_isTyping) return;
        _isTyping = false;
        unawaited(ref.read(chatControllerProvider.notifier).setTyping(
              threadId: widget.threadId,
              uid: myUid,
              isTyping: false,
            ));
      });
    }
    _refreshMentionSuggestions();
  }

  void _refreshMentionSuggestions() {
    final text = _textController.text;
    final cursor = _textController.selection.isValid
        ? _textController.selection.start
        : text.length;
    final before = text.substring(0, cursor);
    final m = RegExp(r'(?:^|\s)@([\w\u0600-\u06FF._-]*)$').firstMatch(before);
    if (m == null) {
      if (_mentionSuggestions.isNotEmpty && mounted) {
        setState(() => _mentionSuggestions = const []);
      }
      return;
    }
    final q = m.group(1) ?? '';
    _mentionTimer?.cancel();
    _mentionTimer = Timer(const Duration(milliseconds: 180), () async {
      try {
        final raw = await Supabase.instance.client.rpc(
          'search_public_profiles',
          params: {'p_query': q, 'p_limit': 8},
        );
        final rows = raw is List ? raw : const <dynamic>[];
        if (mounted) {
          setState(() =>
              _mentionSuggestions = List<Map<String, dynamic>>.from(rows));
        }
      } catch (_) {}
    });
  }

  void _chooseMention(Map<String, dynamic> row) {
    final name = (row['display_name'] ?? row['username'] ?? 'عضو').toString();
    final uid = row['id']?.toString() ?? '';
    final text = _textController.text;
    final cursor = _textController.selection.isValid
        ? _textController.selection.start
        : text.length;
    final before = text.substring(0, cursor);
    final m = RegExp(r'@([\w\u0600-\u06FF._-]*)$').firstMatch(before);
    if (m == null) return;
    final start = m.start;
    final mention = '${name.trim().replaceFirst(RegExp(r'^@'), '')} ';
    _textController.value = TextEditingValue(
        text: text.replaceRange(start, cursor, mention),
        selection: TextSelection.collapsed(offset: start + mention.length));
    if (uid.isNotEmpty) {}
    setState(() => _mentionSuggestions = const []);
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;

    final replyingTo = ref.read(replyingToProvider);
    final replyMode = ref.read(replyingModeProvider);
    final sent = await ref.read(chatControllerProvider.notifier).sendMessage(
          fromUid: myUid,
          toUid: widget.otherUid,
          text: text,
          replyTo: replyingTo,
          metadata: replyingTo == null
              ? null
              : {
                  'reply_mode': replyMode,
                  'request_id': const Uuid().v4(),
                  'mention_user_ids': _mentionUserIds.values.toSet().toList(),
                  if (replyMode.contains('quote'))
                    'quoted_message_id': replyingTo.id
                },
        );

    if (!mounted) return;

    if (!sent) {
      // يُعرض سبب الرفض الحقيقي بلا الرمز الإنجليزي: "أنت مكتوم… تبقّى…
      // السبب…" أو "هذا العضو أقفل الرسائل الخاصة" بدل رسالة عامة.
      final raw = ref.read(chatControllerProvider.notifier).lastSendError ?? '';
      final m = RegExp(
              r'(?:CHAT_RESTRICTED|RESTRICTED_[A-Z_]+|DM_LOCKED)\s*:\s*([^,\)]+)')
          .firstMatch(raw);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(m != null
                ? m.group(1)!.trim()
                : 'تعذّر إرسال الرسالة، حاول مرة أخرى.')),
      );
      return;
    }

    await _sound.play(ChatSoundEvent.send);
    if (!mounted) return;
    _textController.clear();
    _isTyping = false;
    ref.read(replyingToProvider.notifier).state = null;
    _mentionUserIds.clear();
    ref.read(replyingModeProvider.notifier).state = 'reply';
    await ref.read(chatControllerProvider.notifier).setTyping(
          threadId: widget.threadId,
          uid: myUid,
          isTyping: false,
        );
  }

  /// بحث أغنية/فيديو في الخاص: نفس منطق الغرفة — تُرسَل كرسالة نصّية
  /// برابط يوتيوب (تُضمَّن تلقائيًا في الفقاعة)، بينما التشغيل اختياري
  /// من زر "تشغيل" في المشغّل العائم المشترك بين الغرف والخاص.
  Future<void> _showSongSearch() async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await SongSearchSheet.show(
      context,
      onPreviewPlay: (videoId, title) {
        ref.read(miniPlayerProvider.notifier).state =
            MiniPlayerTrack(videoId: videoId, title: title);
      },
      onSelected: (videoId, title) async {
        await ref.read(chatControllerProvider.notifier).sendMessage(
            fromUid: myUid,
            toUid: widget.otherUid,
            text: 'https://www.youtube.com/watch?v=$videoId',
            type: MessageType.text,
          );
      },
    );
  }

  Future<void> _showGifPicker(BuildContext context) async {
    const gifs = mashareenaChatGifCatalog;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      // بلا هذا كانت Wrap ترتّب من اليسار (اتجاه الودجت الافتراضي)، فيظهر
      // أول سمايل (مالك المنصة) من أقصى اليسار لا اليمين — نفس الإصلاح
      // المطبَّق في قائمة الغرفة.
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final gif in gifs)
                    Tooltip(
                      message: mashareenaChatGifNames[gif] ?? '',
                      triggerMode: mashareenaChatGifNames.containsKey(gif)
                          ? TooltipTriggerMode.longPress
                          : TooltipTriggerMode.manual,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(sheetContext, gif),
                        // لقمة لمس 40×40 حول صورة 25×25.
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 25,
                              height: 25,
                              child: Image.asset(gif,
                                  width: 25, height: 25,
                                  fit: BoxFit.contain, gaplessPlayback: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _sendAttachment(MessageType.gif, selected, 'gif.gif');
  }

  Future<void> _sendEmoji(String emoji) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await ref.read(chatControllerProvider.notifier).sendMessage(
          fromUid: myUid,
          toUid: widget.otherUid,
          text: emoji,
          type: MessageType.emoji,
        );
  }

  Future<void> _sendAttachment(
      MessageType type, String url, String name) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await ref.read(chatControllerProvider.notifier).sendMessage(
          fromUid: myUid,
          toUid: widget.otherUid,
          text: name,
          type: type,
          mediaUrl: url,
        );
  }

  Future<void> _react(ChatMessageEntity message, String emoji) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await ref.read(chatControllerProvider.notifier).toggleReaction(
          threadId: widget.threadId,
          messageId: message.id,
          uid: myUid,
          emoji: emoji,
        );
  }

  Future<void> _togglePin(ChatMessageEntity message) async {
    await ref.read(chatControllerProvider.notifier).setPinned(
          threadId: widget.threadId,
          messageId: message.id,
          pinned: !message.isPinned,
        );
  }

  Future<void> _editMessage(ChatMessageEntity message) async {
    var editedText = message.text;
    final p = context.palette;
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surfaceElevated,
        title: Text('تعديل الرسالة', style: TextStyle(color: p.textPrimary)),
        content: TextFormField(
          initialValue: message.text,
          textAlign: TextAlign.right,
          autofocus: true,
          onChanged: (value) => editedText = value,
          style: TextStyle(color: p.textPrimary),
          decoration: InputDecoration(
            hintText: message.text,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editedText),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newText == null || newText.trim().isEmpty || !mounted) return;
    await ref.read(chatControllerProvider.notifier).editMessage(
          threadId: widget.threadId,
          messageId: message.id,
          newText: newText,
        );
  }

  int _myPriority = 0;

  Future<void> _moderatorDelete(ChatMessageEntity message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف إداري'),
        content: const Text('ستُحذف الرسالة لدى الطرفين حذفًا نهائيًا لا يستطيع صاحبها التراجع عنه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc('delete_message',
          params: {'p_scope': 'dm', 'p_message_id': message.id});
      m.showSnackBar(const SnackBar(content: Text('حُذفت الرسالة')));
    } catch (e) {
      m.showSnackBar(SnackBar(
          content: Text(e.toString().contains('FORBIDDEN')
              ? 'لا يمكنك حذف رسالة عضو أعلى منك رتبة.'
              : 'تعذّر الحذف: $e')));
    }
  }

  Future<void> _deleteMessage(ChatMessageEntity message,
      {required bool forEveryone}) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;
    await ref.read(chatControllerProvider.notifier).deleteMessage(
          threadId: widget.threadId,
          messageId: message.id,
          requesterUid: myUid,
          forEveryone: forEveryone,
        );
  }

  Future<void> _sendGift(GiftEntity gift) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null || !mounted) return;

    final senderName =
        ref.read(currentProfileProvider).valueOrNull?.displayName ?? 'عضو';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد إرسال الهدية'),
            content: Text(
              '$senderName سيرسل ${gift.nameAr} ${gift.emoji} إلى ${widget.otherName}.\nهل تريد المتابعة؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final tx = await ref.read(giftControllerProvider.notifier).sendGift(
          fromUid: myUid,
          toUid: widget.otherUid,
          gift: gift,
        );

    if (!mounted) return;
    if (tx == null) {
      final reason =
          ref.read(giftControllerProvider.notifier).lastError?.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason == null || reason.isEmpty
                ? 'تعذّر إرسال الهدية.'
                : 'تعذّر إرسال الهدية: $reason',
          ),
        ),
      );
      return;
    }
    await ref.read(chatControllerProvider.notifier).sendMessage(
      fromUid: myUid,
      toUid: widget.otherUid,
      text: gift.emoji,
      type: MessageType.gift,
      metadata: {
        'gift_id': gift.id,
        'gift_emoji': gift.emoji,
        'gift_name': gift.nameAr,
        'from_name': senderName,
        'to_name': widget.otherName,
        'price_points': tx.pricePoints
      },
    );
    await _sound.play(ChatSoundEvent.receive);
  }

  Future<void> _startCall(CallType type) async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;

    final result = await ref.read(callControllerProvider.notifier).startCall(
          callerUid: myUid,
          calleeUid: widget.otherUid,
          type: type,
        );

    if (!mounted) return;

    final call = result.fold((failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return null;
    }, (c) => c);

    if (call == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveCallPage(
          callId: call.id,
          otherUid: widget.otherUid,
          type: type,
          isCaller: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    // Was userPresenceProvider — a RAW stream from user_presence that
    // ignores privacy entirely (appear-offline, stealth). That is why this
    // header could show "متصل الآن" here while the floating window's own
    // bar (which correctly asks the privacy-aware get_profile_for_viewer)
    // showed "غير متصل" for the SAME person at the SAME time. Both now read
    // from the one privacy-respecting source.
    final peerPresenceAsync = ref.watch(privacyAwarePresenceProvider(widget.otherUid));
    final typingAsync = ref.watch(chatTypingProvider(widget.threadId));
    final replyingTo = ref.watch(replyingToProvider);
    final otherProfile =
        ref.watch(profileByIdProvider(widget.otherUid)).valueOrNull;
    final p = context.palette;

    final otherIsTyping =
        (typingAsync.valueOrNull ?? []).any((uid) => uid == widget.otherUid);

    // صحّي التسليم: أي رسالة وصلت لهذا الجهاز من الطرف الآخر ولا
    // تزال بحالة "sent" تتحول إلى "delivered" فور استلامها هنا، حتى
    // دون الحاجة لفتح المحادثة فعليًا (فرق delivered عن seen).
    ref.listen(chatMessagesProvider(widget.threadId), (previous, next) {
      final msgs = next.valueOrNull;
      if (msgs == null || myUid == null) return;
      final toMarkDelivered = msgs
          .where((m) => m.senderUid != myUid && m.status == MessageStatus.sent)
          .map((m) => m.id)
          .toList();
      if (toMarkDelivered.isNotEmpty) {
        ref.read(chatControllerProvider.notifier).markDelivered(
              threadId: widget.threadId,
              messageIds: toMarkDelivered,
            );
      }
      if (toMarkDelivered.isNotEmpty) {
        unawaited(_sound.play(ChatSoundEvent.receive));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => UserProfileViewPage(uid: widget.otherUid)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ServerUsernameDisplay(
                      uid: widget.otherUid,
                      fallbackName: widget.otherName,
                      fallbackFontSize: 14,
                      showBadges: true,
                      showAchievements: true,
                    ),
                  ),
                  UserMembershipBadge(uid: widget.otherUid, fontSize: 9.5),
                ],
              ),
              PrivacyAwarePresenceSubtitle(data: peerPresenceAsync.valueOrNull),
              if (ref
                      .watch(profilePublicVipEffectsProvider(widget.otherUid))
                      .valueOrNull?['chat_presence_plus'] is Map &&
                  ((ref
                              .watch(profilePublicVipEffectsProvider(
                                  widget.otherUid))
                              .valueOrNull?['chat_presence_plus']
                          as Map)['enabled'] ==
                      true))
                VipPresencePlus(uid: widget.otherUid),
            ],
          ),
        ),
        actions: [
          if (ref.watch(chatVoiceVideoServiceProvider).valueOrNull == true) ...[
            IconButton(
              icon: const Icon(Icons.call_outlined),
              tooltip: 'اتصال صوتي',
              onPressed: () => _startCall(CallType.voice),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'اتصال فيديو',
              onPressed: () => _startCall(CallType.video),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const ErrorView(message: 'تعذر تحميل المحادثة الآن. تحقق من الاتصال ثم أعد المحاولة.'),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text('ابدأ المحادثة الآن',
                        style: TextStyle(color: p.textSecondary)),
                  );
                }
                final pinned = messages.where((m) => m.isPinned).toList();
                return Column(
                  children: [
                    if (pinned.isNotEmpty && !_pinnedBannerDismissed)
                      _PinnedTopicBanner(
                        message: pinned.first,
                        onDismiss: () =>
                            setState(() => _pinnedBannerDismissed = true),
                        onTap: () => _togglePin(pinned.first),
                      ),
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final occurrenceKey = '${msg.id}#$index';
                          final isMine = msg.senderUid == myUid;
                          return Builder(
                            builder: (itemContext) {
                              if (itemContext.mounted) {
                                _messageContexts[msg.id] = itemContext;
                              }
                              return KeyedSubtree(
                                key: ValueKey(occurrenceKey),
                                child: MessageBubble(
                                  message: msg,
                                  isMine: isMine,
                                  currentUid: myUid ?? '',
                                  senderName: isMine ? null : widget.otherName,
                                  senderUid: isMine ? myUid : widget.otherUid,
                                  senderAvatarUrl:
                                      isMine ? null : otherProfile?.avatarUrl,
                                  senderAvatarFrameKey: isMine
                                      ? null
                                      : otherProfile?.avatarFrameKey,
                                  mentionFrameColor: _mentionFrameColor,
                                  onReact: (emoji) => _react(msg, emoji),
                                  onReply: () {
                                    ref
                                        .read(replyingModeProvider.notifier)
                                        .state = 'reply';
                                    ref
                                        .read(replyingToProvider.notifier)
                                        .state = msg;
                                  },
                                  onSenderTap: isMine
                                      ? null
                                      : () {
                                          _mentionUserIds[widget.otherName] =
                                              widget.otherUid;
                                          _insertMention(widget.otherName,
                                              widget.otherUid);
                                        },
                                  onReplyMode: (mode) {
                                    ref
                                        .read(replyingModeProvider.notifier)
                                        .state = mode;
                                    ref
                                        .read(replyingToProvider.notifier)
                                        .state = msg;
                                  },
                                  onEdit:
                                      isMine ? () => _editMessage(msg) : null,
                                  onDeleteForMe: () =>
                                      _deleteMessage(msg, forEveryone: false),
                                  onDeleteForEveryone: isMine
                                      ? () =>
                                          _deleteMessage(msg, forEveryone: true)
                                      : null,
                                  onModeratorDelete: !isMine && _myPriority >= 100
                                      ? () => _moderatorDelete(msg)
                                      : null,
                                  onTogglePin: () => _togglePin(msg),
                                  onJumpToMessage: _jumpToMessage,
                                  onGifTap: (url) =>
                                      _sendAttachment(MessageType.gif, url, 'gif.gif'),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          TypingIndicatorBar(visible: otherIsTyping),
          if (replyingTo != null)
            ReplyPreviewBar(
              replyingTo: replyingTo,
              onCancel: () =>
                  ref.read(replyingToProvider.notifier).state = null,
            ),
          if (_mentionSuggestions.isNotEmpty)
            Container(
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mentionSuggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final r = _mentionSuggestions[i];
                      return InkWell(
                          onTap: () => _chooseMention(r),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: p.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.divider)),
                              child: Text(
                                  '@${r['display_name'] ?? r['username'] ?? 'عضو'}',
                                  style: TextStyle(
                                      color: p.textPrimary, fontSize: 12))));
                    })),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF22C55E)),
                    tooltip: 'إرفاق',
                    onPressed: () =>
                        AttachmentMenu.show(context, onPicked: _sendAttachment),
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFF59E0B)),
                    tooltip: 'إيموجي',
                    onPressed: () => EmojiPickerSheet.show(context, _sendEmoji),
                  ),
                  // سمايلات متحركة: لم تكن موجودة إطلاقًا في الخاص رغم
                  // وجودها في الغرف. الاختيار هنا يُرسِل فورًا (بلا صندوق
                  // معاينة)، مطابقًا لنمط إرسال الإيموجي الفوري في هذه
                  // الشاشة أصلًا.
                  IconButton(
                    icon: const Icon(Icons.gif_box_outlined, color: Color(0xFFEC4899)),
                    tooltip: 'GIF',
                    onPressed: () => _showGifPicker(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.music_note_rounded, color: Color(0xFF22D3EE)),
                    tooltip: 'بحث أغنية',
                    onPressed: _showSongSearch,
                  ),
                  // تسجيل بنمط واتساب: يبدأ بضغطة ويظل زر الميكروفون ظاهرًا، ثم
                  // يظهر شريط الموجة مع إيقاف مؤقت/إرسال/حذف صريح.
                  VoiceHoldButton(
                    color: p.accent,
                    privateChat: true,
                    onUploaded: (url) async =>
                        _sendAttachment(MessageType.audio, url, 'voice.m4a'),
                  ),
                  IconButton(
                    icon: const Text('🎁', style: TextStyle(fontSize: 18)),
                    tooltip: 'إرسال هدية',
                    onPressed: () => GiftPickerSheet.show(context, _sendGift),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        // Same store-purchased message color the sent
                        // bubble will render with (message_bubble.dart) —
                        // one canonical source (profiles.message_color),
                        // so what you see while typing is what gets sent,
                        // per spec item 6.
                        color: () {
                          final v = ref
                              .watch(currentProfileProvider)
                              .valueOrNull
                              ?.messageColor;
                          return (v == null || v == 4294967295)
                              ? p.textPrimary
                              : Color(v);
                        }(),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        hintStyle: TextStyle(color: p.textMuted),
                        filled: true,
                        fillColor: p.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: p.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: p.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: p.accent, width: 1.4),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _send,
                    icon: Icon(Icons.send, color: p.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط "الموضوع" العلوي — يعرض أحدث رسالة مثبَّتة بأسلوب الإعلان
/// المرجعي (أيقونة تنبيه + نص + زر إغلاق)، بألوان ثيم التطبيق الحالي.
class _PinnedTopicBanner extends StatelessWidget {
  final ChatMessageEntity message;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _PinnedTopicBanner(
      {required this.message, required this.onDismiss, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: p.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموضوع',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: p.accent)),
                  Text(
                    message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: p.textMuted),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
