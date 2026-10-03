import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/presentation/widgets/arabic_font_catalog.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../rbac/presentation/widgets/server_chat_inline_message.dart';
import '../../domain/entities/chat_message_entity.dart';
import 'emoji_picker_sheet.dart';
import 'chat_media_content.dart';
import '../../../../core/widgets/embedded_media_player.dart';
import 'reply_3d_anchor.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';
import 'chat_mention_badge.dart';
import '../../../vip/presentation/widgets/vip_link_preview.dart';
import '../../../vip/presentation/widgets/vip_favorite_button.dart';

/// فقاعة الرسالة — مُعاد تصميمها بأسلوب مضغوط (صورة مصغّرة + اسم
/// ملوَّن + رسالة، بتباعد أقل) مطابقًا للنمط البصري لتطبيقات
/// الدردشة الجماعية المرجعية (شارة اسم ملوَّنة، نجمة VIP، صورة
/// صغيرة بجانب كل رسالة من الطرف الآخر)، مع الحفاظ الكامل على
/// نظام الثيم الحالي للتطبيق (لا تغيير في الألوان الأساسية) وكل
/// الوظائف الموجودة (رد، تفاعلات، تثبيت، تعديل، حذف). الصورة
/// المصغّرة وشارة الاسم تظهران فقط لرسائل الطرف الآخر (isMine
/// false) — نفس تعارف واتساب/تيليجرام/مسنجر في المحادثات الثنائية،
/// حيث موضع الفقاعة نفسه يكفي لتمييز رسائلك الخاصة.
/// نفس منطق الفحص المستخدَم في server_chat_inline_message.dart للرسائل
/// العامة، مطبَّق هنا على مسار الرسائل الخاصة الذي لم يكن محميًا إطلاقًا.
Color _readablePrivateTextColor(Color text, Color background) {
  double luminance(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : ((v + 0.055) / 1.055).clamp(0.0, 1.0).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }
  final bgLum = luminance(background);
  final textLum = luminance(text);
  final contrast = (textLum - bgLum).abs();
  if (contrast > 0.35) return text;
  return bgLum > 0.55 ? Colors.black : Colors.white;
}

class MessageBubble extends ConsumerWidget {
  final ChatMessageEntity message;
  final bool isMine;
  final String currentUid;
  final String? senderAvatarUrl;
  final String? senderAvatarFrameKey;
  final String? senderName;
  final String? senderUid;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final ValueChanged<String>? onReplyMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  /// الضغط على سمايل متحرك مرسَل يرسله مرة أخرى فورًا.
  final ValueChanged<String>? onGifTap;

  /// حذف إداري لرسالة عضو آخر (يُمرَّر فقط لمن يملك صلاحية؛ الخادم يفرض الهرم).
  final VoidCallback? onModeratorDelete;
  final VoidCallback onTogglePin;
  final ValueChanged<String>? onJumpToMessage;
  final VoidCallback? onSenderTap;
  final Color mentionFrameColor;
  final String? roomId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUid,
    this.senderAvatarUrl,
    this.senderAvatarFrameKey,
    this.senderName,
    this.senderUid,
    required this.onReact,
    required this.onReply,
    this.onReplyMode,
    this.onEdit,
    this.onDeleteForMe,
    this.onModeratorDelete,
    this.onGifTap,
    this.onDeleteForEveryone,
    required this.onTogglePin,
    this.onJumpToMessage,
    this.onSenderTap,
    this.mentionFrameColor = const Color(0xFFFFD54F),
    this.roomId,
  });

  bool _currentUserIsMentioned(ChatMessageEntity message) {
    final ids = message.metadata?['mention_user_ids'];
    if (ids is! List) return false;
    return ids.map((e) => e.toString()).contains(currentUid);
  }

  void _showActions(BuildContext context) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: QuickReactionBar(
                onSelect: (emoji) {
                  Navigator.pop(sheetContext);
                  onReact(emoji);
                },
                onMore: () {
                  Navigator.pop(sheetContext);
                  EmojiPickerSheet.show(context, onReact);
                },
              ),
            ),
            const Divider(height: 20),
            _ActionTile(
                icon: Icons.reply_outlined,
                label: 'رد',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReply();
                }),
            _ActionTile(
              icon: Icons.format_quote_rounded,
              label: 'اقتباس',
              onTap: () {
                Navigator.pop(sheetContext);
                onReplyMode?.call('quote');
              },
            ),
            _ActionTile(
              icon: Icons.view_in_ar_outlined,
              label: 'رد 3D',
              onTap: () {
                Navigator.pop(sheetContext);
                onReplyMode?.call('reply_3d');
              },
            ),
            _ActionTile(
              icon: Icons.view_in_ar_outlined,
              label: 'اقتباس 3D',
              onTap: () {
                Navigator.pop(sheetContext);
                onReplyMode?.call('quote_3d');
              },
            ),
            _ActionTile(
              icon: Icons.share_rounded,
              label: 'مشاركة',
              onTap: () {
                Navigator.pop(sheetContext);
                final t = [message.text, message.mediaUrl ?? '']
                    .where((e) => e.trim().isNotEmpty)
                    .join('\n');
                if (t.isNotEmpty) Share.share(t);
              },
            ),
            _ActionTile(
              icon: message.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: message.isPinned ? 'إلغاء التثبيت' : 'تثبيت',
              onTap: () {
                Navigator.pop(sheetContext);
                onTogglePin();
              },
            ),
            if (isMine && onEdit != null && message.type == MessageType.text)
              _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'تعديل',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onEdit!.call();
                  }),
            if (onDeleteForMe != null)
              _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'حذف لديّ فقط',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onDeleteForMe!.call();
                  }),
            if (!isMine && onModeratorDelete != null)
              _ActionTile(
                icon: Icons.gavel_rounded,
                label: 'حذف إداري',
                color: p.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onModeratorDelete!.call();
                },
              ),
            if (isMine && onDeleteForEveryone != null)
              _ActionTile(
                icon: Icons.delete_forever_outlined,
                label: 'حذف لدى الجميع',
                color: p.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDeleteForEveryone!.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _vipLinkPreview(String text) {
    final match = RegExp(r'(https?://\S+|www\.\S+)', caseSensitive: false).firstMatch(text);
    if (match == null) return const SizedBox.shrink();
    return VipLinkPreview(url: match.group(0)!);
  }

  IconData _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.seen:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
      case MessageStatus.edited:
        return Icons.check;
      case MessageStatus.deleted:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    // profiles.message_color defaults to 0xFFFFFFFF (opaque white) for anyone
    // who hasn't picked a store message color — treat that sentinel as "no
    // preference" and keep the original theme color, so nothing changes
    // visually for the vast majority of users who never bought one.
    final myMessageColorValue = ref.watch(currentProfileProvider).valueOrNull?.messageColor;
    final myMessageColor = (myMessageColorValue == null || myMessageColorValue == 4294967295)
        ? null
        : Color(myMessageColorValue);
    final deletedForEveryone = message.status == MessageStatus.deleted;
    final hiddenForMe = message.deletedForUids.contains(currentUid);
    final effectiveSenderName = message.metadata?['anonymous_chat'] == true
        ? 'عضو مجهول'
        : senderName;
    if (hiddenForMe) return const SizedBox.shrink();
    // كانت تقرأ vip بصلاحيات currentUid (المُشاهد الحالي دائمًا، حسب موقع
    // استدعاء MessageBubble)، بينما chat_link_preview_plus وchat_media_plus
    // ميزتان يدفع ثمنهما المُرسِل نفسه لتحسين شكل رسائله لدى الآخرين — لا
    // علاقة لهما باشتراك من يُشاهد الرسالة. كانت النتيجة: مُشاهد VIP يرى
    // معاينة روابط وعرض وسائط أكبر من أي مُرسِل حتى لو لم يدفع، بينما
    // مُرسِل دفع فعليًا لا يحصل على أي أثر إن كان المُشاهد بلا اشتراك.
    final vip = ref.watch(profilePublicVipEffectsProvider(senderUid ?? currentUid)).valueOrNull ?? const <String, dynamic>{};
    final linkPreviewEnabled = (vip['chat_link_preview_plus'] as Map?)?['enabled'] == true;
    final mediaPlusEnabled = (vip['chat_media_plus'] as Map?)?['enabled'] == true;

    final bubble = GestureDetector(
      onLongPress: deletedForEveryone ? null : () => _showActions(context),
      child: Align(
        alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // النقاط الثلاث: رد، اقتباس، مشاركة، حذف (نفس قائمة الضغط المطوّل).
            if (!deletedForEveryone)
              GestureDetector(
                onTap: () => _showActions(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74),
              decoration: BoxDecoration(
                color: isMine ? p.surfaceHighlight : p.accent,
                borderRadius: BorderRadius.circular(14),
                border: message.isPinned
                    ? Border.all(color: p.accentBright, width: 1)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin,
                              size: 12,
                              color: isMine ? p.accent : p.background),
                          const SizedBox(width: 4),
                          Text(
                            'مثبّتة',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMine
                                  ? p.accent
                                  : p.background.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (effectiveSenderName != null &&
                      !deletedForEveryone && !message.type.isMedia && message.text.isNotEmpty &&
                      !RegExp(r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|tiktok\.com)\/\S+$', caseSensitive: false).hasMatch(message.text.trim()))
                    ServerChatInlineMessage(
                      uid: message.senderUid,
                      roomId: roomId,
                      fallbackName: effectiveSenderName,
                      text: message.text,
                      // كانت p.textPrimary دائمًا لرسائلي هنا، متجاهلة لون
                      // الرسالة المخصَّص (myMessageColor) كليًا — والويدجت
                      // نفسه يطبّق فحص تباين داخليًا فقط على القيمة التي
                      // يستلمها، فلو مُرِّر لون خاطئ من الأساس، الفحص
                      // الداخلي يحميه هو، لا اللون الصحيح الذي يريده المستخدم.
                      // إذا كانت رسالتي وفيها لون مخصَّص → مرّره؛ وإلا مرّر
                      // null لكي يقرأ ServerChatInlineMessage لون الرسالة من
                      // ملف المُرسِل الشخصي (identity) عبر stream Supabase.
                      // كان يُمرَّر p.textPrimary بشكل صريح فيتجاوز الكتالوج
                      // الخادمي ويتجاهل message_color_1/message_color_key التي
                      // تكتبها set_my_message_color فعليًا.
                      messageColor: isMine
                          ? (myMessageColor ?? Colors.white)
                          : Colors.white,
                      // The bubble's real fill, so a sender's own chosen
                      // message colour is checked for contrast against
                      // whatever it is actually rendered on top of.
                      backgroundColor: isMine ? p.surfaceHighlight : p.accent,
                      mentionColor: mentionFrameColor,
                      onNameTap: onSenderTap,
                      nameFontSize: 12,
                      messageFontSize: 14,
                      showMentionBadge: _currentUserIsMentioned(message),
                      mentionNames: (message.metadata?['mention_user_names'] is List)
                          ? (message.metadata!['mention_user_names'] as List<dynamic>)
                              .map((e) => e.toString())
                              .toSet()
                          : const <String>{},
                    ),
                  if (message.replyToId != null && !deletedForEveryone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: (message.metadata?['reply_mode'] == 'reply_3d' ||
                              message.metadata?['reply_mode'] == 'quote_3d')
                          ? Reply3DAnchor(
                              messageId: message.id,
                              targetMessageId: message.replyToId!,
                              preview: message.replyToPreview,
                              compact: true,
                              onTap: () =>
                                  onJumpToMessage?.call(message.replyToId!))
                          : InkWell(
                              onTap: () =>
                                  onJumpToMessage?.call(message.replyToId!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                    color: p.background.withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(
                                        right: BorderSide(
                                            color: isMine
                                                ? p.accent
                                                : p.background,
                                            width: 2.5))),
                                child: Text(message.replyToPreview ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: (isMine
                                                ? p.textSecondary
                                                : p.background)
                                            .withValues(alpha: .85))),
                              ),
                            ),
                    ),
                  if (!deletedForEveryone &&
                      message.type.isMedia &&
                      message.mediaUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ChatMediaContent(
                        message: message,
                        onMore: () => _showActions(context),
                        onGifTap: onGifTap,
                        maxWidth: MediaQuery.of(context).size.width * (mediaPlusEnabled ? .72 : .68),
                        vipPlus: mediaPlusEnabled,
                      ),
                    ),
                  if (!deletedForEveryone &&
                      !message.type.isMedia &&
                      message.text.isNotEmpty &&
                      RegExp(r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|tiktok\.com)\/\S+$',
                              caseSensitive: false)
                          .hasMatch(message.text.trim()))
                    SizedBox(
                        width: 240,
                        child: EmbeddedMediaPlayer(
                            url: message.text.trim().startsWith('http')
                                ? message.text.trim()
                                : 'https://${message.text.trim()}')),
                  if (!deletedForEveryone &&
                      !message.type.isMedia &&
                      message.text.isNotEmpty &&
                      (isMine || effectiveSenderName == null ||
                       RegExp(r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|tiktok\.com)\/\S+$', caseSensitive: false).hasMatch(message.text.trim())))
                    _PrivateMentionText(
                        text: message.text,
                        // كان اللون هنا يُستخدم مباشرة بلا أي فحص تباين مع
                        // خلفية الفقاعة الفعلية (bubbleBg أدناه)، بخلاف
                        // الرسائل العامة المحمية أصلًا عبر ServerChatInline
                        // Message. لون رسالة مخصَّص قريب من لون الفقاعة كان
                        // يجعل النص غير مقروء تمامًا في الخاص.
                        textColor: _readablePrivateTextColor(
                            isMine ? (myMessageColor ?? Colors.white) : Colors.white,
                            isMine ? p.surfaceHighlight : p.accent),
                        frameColor: mentionFrameColor,
                        showMentionBadge: _currentUserIsMentioned(message),
                        fontFamily: localArabicFontFamily(isMine ? ref.watch(currentProfileProvider).valueOrNull?.messageFontFamily : 'system_default'),
                        mentionNames: (message.metadata?['mention_user_names'] is List)
                            ? (message.metadata!['mention_user_names'] as List<dynamic>)
                                .map((e) => e.toString())
                                .toSet()
                            : const <String>{}),
                  if (!deletedForEveryone && linkPreviewEnabled && !message.type.isMedia)
                    _vipLinkPreview(message.text),
                  if (deletedForEveryone)
                    Text('🚫 تم حذف هذه الرسالة',
                        style: TextStyle(
                            color: isMine ? p.textPrimary : p.background,
                            fontStyle: FontStyle.italic)),
                  if (message.type == MessageType.gift &&
                      !deletedForEveryone &&
                      message.metadata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (message.metadata!['giftEmoji'] ??
                                message.metadata!['gift_emoji']) as String? ??
                            '🎁',
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited && !deletedForEveryone)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'مُعدَّلة',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: (isMine ? p.textMuted : p.background)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      if ((vip['chat_favorites_plus'] as Map?)?['enabled'] == true)
                        VipFavoriteButton(
                          messageId: message.id,
                          enabled: ref.watch(vipFavoriteMessageProvider(message.id)).valueOrNull == true,
                        ),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: (isMine ? p.textMuted : p.background)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          _statusIcon(),
                          size: 13,
                          color: message.status == MessageStatus.seen
                              ? p.accentBright
                              : p.textMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (message.reactions.isNotEmpty && !deletedForEveryone)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (final entry in message.reactions.entries)
                      GestureDetector(
                        onTap: () => onReact(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entry.value.contains(currentUid)
                                ? p.accent.withValues(alpha: 0.25)
                                : p.surfaceHighlight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entry.value.contains(currentUid)
                                  ? p.accent
                                  : p.divider,
                            ),
                          ),
                          child: Text('${entry.key} ${entry.value.length}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (isMine) return bubble;

    // رسائل الطرف الآخر: صورة مصغّرة + شارة اسم ملوَّنة (بلون
    // عضويته/رتبته إن وُجدت) قبل الفقاعة — نفس النمط البصري
    // المرجعي (Avatar + Colored Name Badge) لكن بألوان ثيم التطبيق
    // الحالي دون تغيير.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(child: bubble),
          const SizedBox(width: 6),
          _SenderAvatar(
            url: senderAvatarUrl,
            frameKey: _resolveAvatarFrameKey(),
            frameId: _resolveFrameIdFromKey(_resolveAvatarFrameKey()),
            userId: senderUid,
          ),
        ],
      ),
    );
  }

  int? _resolveFrameIdFromKey(String? key) {
    final value = key?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'(\d{1,3})').firstMatch(value);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(1)!);
    return parsed != null && parsed >= 1 && parsed <= 100 ? parsed : null;
  }

  String? _resolveAvatarFrameKey() {
    final raw = message.metadata?['avatar_frame_key'];
    final value = raw?.toString().trim();
    return (value != null && value.isNotEmpty) ? value : senderAvatarFrameKey;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $period';
  }
}

class _PrivateMentionText extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color frameColor;
  final String? fontFamily;
  final Set<String> mentionNames;
  final bool showMentionBadge;
  const _PrivateMentionText({
    required this.text,
    required this.textColor,
    required this.frameColor,
    this.fontFamily,
    this.mentionNames = const <String>{},
    this.showMentionBadge = false,
  });
  static final RegExp _mention = RegExp(r'@[\w\u0600-\u06FF._-]+');

  RegExp _mentionPattern(Set<String> mentionNames) {
    final names = mentionNames
        .map((name) => name.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (names.isEmpty) return _mention;
    final escaped = names.map(RegExp.escape).join('|');
    return RegExp(r'@(?:' + escaped + r')(?![\w\u0600-\u06FF._-])', caseSensitive: false);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _mentionPattern(mentionNames).allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: TextStyle(color: textColor, fontFamily: fontFamily, fontSize: 14, height: 1.15));
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: TextStyle(color: textColor, fontFamily: fontFamily, fontSize: 14, height: 1.15)));
      }
      final raw = text.substring(match.start, match.end);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: showMentionBadge
            ? ChatMentionBadge(name: raw, fontSize: 13)
            : Text(
                raw,
                style: TextStyle(
                  color: textColor,
                  fontFamily: fontFamily,
                  fontSize: 14,
                  height: 1.15,
                ),
              ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: TextStyle(color: textColor, fontFamily: fontFamily, fontSize: 14, height: 1.15))); 
    return RichText(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        text: TextSpan(style: TextStyle(color: textColor), children: spans));
  }
}

/// صورة مصغّرة مضغوطة (28px) بجانب كل رسالة من الطرف الآخر — تُظهر
/// حرف الاسم الأول إن لم توجد صورة، بنفس أسلوب صورة البروفايل
/// المستخدَم في بقية التطبيق.
class _SenderAvatar extends StatelessWidget {
  final String? url;
  final String? frameKey;
  final int? frameId;
  final String? userId;
  const _SenderAvatar({required this.url, this.frameKey, this.frameId, this.userId});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final avatar = CircleAvatar(
      radius: 26,
      backgroundColor: p.surfaceHighlight,
      backgroundImage:
          (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty)
          ? Icon(Icons.person, size: 24, color: p.textMuted)
          : null,
    );
    return DynamicAvatarFrame(frameId: frameId, frameKey: frameKey, radius: 26, userId: userId, child: avatar);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      leading: Icon(icon, color: color ?? p.textPrimary),
      title: Text(label, style: TextStyle(color: color ?? p.textPrimary)),
      onTap: onTap,
    );
  }
}
