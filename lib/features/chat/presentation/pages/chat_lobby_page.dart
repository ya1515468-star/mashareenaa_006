import 'package:mashareena/core/utils/safe_launch.dart';
import '../../../../core/widgets/mini_player_chip.dart';
import '../../../../core/services/snack_sfx.dart';
import '../widgets/room_mic_seats.dart';
import '../widgets/animated_dice_roller.dart';
import '../widgets/game_hub.dart';
import '../widgets/trix_game.dart';
import '../../../../core/services/server_sounds.dart';
import '../../data/gif_catalog.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/voice_message_player.dart';
import '../providers/unread_dm_provider.dart';
import '../../../../core/widgets/song_search_sheet.dart';
import '../../../../core/providers/mini_player_provider.dart';
import '../widgets/voice_hold_button.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/typography/local_glyph_text.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/resilient_realtime_channel.dart';
import '../../../../core/widgets/embedded_media_player.dart';
import 'conversations_page.dart';
import '../../../friends/presentation/pages/friends_list_page.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../leaderboard/presentation/leaderboard_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../presence_directory/presentation/online_now_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../store/presentation/store_features_tab.dart';
import '../../../store/presentation/widgets/store_effect_engines.dart';
import '../../../store/domain/entities/store_item_entity.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../gamification/domain/entities/username_effect.dart';
import '../../../gamification/presentation/widgets/username_cosmetic_name.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../../rbac/presentation/widgets/server_rank_badge.dart';
import '../../../profile/presentation/widgets/account_setting_tiles.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';
import '../widgets/chat_mention_badge.dart';
import '../widgets/chat_message_frame.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_dialog.dart';
import '../../../reports/presentation/pages/platform_safety_warnings_page.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../subscriptions/presentation/pages/subscriptions_page.dart';
import 'package:uuid/uuid.dart';
import '../../../gifts/presentation/widgets/gift_picker_sheet.dart';
import '../../domain/lobby_directory_service.dart';
import '../../domain/chat_visual_size_service.dart';
import '../widgets/sticker_and_gif_sheet.dart';
import '../widgets/mini_profile_popup.dart';
import '../widgets/mini_chat_overlay.dart';
import 'chat_thread_page.dart';
import '../../../store/presentation/profile_cosmetic_store_page.dart';
import 'room_management_page.dart';
import 'chat_rooms_page.dart';
import 'chat_feature_settings_page.dart';
import 'chat_notification_settings_page.dart';
import 'directory_list_page.dart';
import 'friends_wall_page.dart';
import 'sponsored_ads_page.dart';
import '../widgets/chat_theme_picker_sheet.dart';
import '../../data/services/chat_sound_service.dart';
import '../../data/services/chat_sound_player.dart';

/// true إن كان [url] مسار تخزين خامًا (لا رابطًا جاهزًا ولا أصلًا محليًا)
/// — الحالة التي يُعيدها رفع إلى bucket خاص (chat-media-plus لمستخدمي
/// VIP+)، ويحتاج توقيعًا عبر SupabaseService.resolvePrivateMediaUrl قبل
/// أي عرض فعلي. bucket "media" العام يُعيد رابطًا كاملًا جاهزًا دائمًا،
/// فلا تلتقطه هذه الدالة إطلاقًا — صفر تغيير سلوك للحالة الشائعة.
bool _needsPrivateSigning(String url) =>
    !url.startsWith('http://') &&
    !url.startsWith('https://') &&
    !url.startsWith('assets/');

/// خلفية الغرفة الحقيقية من الخادم — بثّ حي فور تغييرها من أي مدير غرفة،
/// يظهر لكل الأعضاء الحاضرين في اللحظة نفسها بلا حاجة لإعادة فتح الغرفة.
final roomBackgroundProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, roomId) {
  return Supabase.instance.client
      .from('chat_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map((rows) => rows.isEmpty ? null : rows.first['background_url'] as String?);
});

class ChatLobbyPage extends ConsumerStatefulWidget {
  final String roomId;

  const ChatLobbyPage({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<ChatLobbyPage> createState() => _ChatLobbyPageState();
}

class _ChatLobbyPageState extends ConsumerState<ChatLobbyPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;
  bool _showMic = true;
  bool _showGames = true;
  bool _showMedia = true;
  bool _isPlatformOwner = false;
  bool _canManageVisualSize = false;
  bool _chatAudioUnlocked = false;
  bool _canManageBroadcast = false;
  int _rankRevision = 0;
  String? _profileAvatarUrl;
  String _chatThemeId = 'royal_dark';
  String _mentionFrameColor = 'gold';
  String? _activeMediaUrl;
  bool _mediaExpanded = false;
  Map<String, dynamic> _roomControls = const {};
  // _roomName و_roomMemberCount حُذفا مع شريط _RoomHeader: كانا
  // يُجلبان من الخادم في كل تحديث حضور ثم لا يُقرآن أبدًا.

  /// هدية/GIF مختارة من المنتقي لكنها لم تُرسَل بعد — تبقى معلَّقة
  /// حتى يضغط المستخدم صراحة زر الإرسال (تنفيذ حرفي لبند "لا تُرسَل
  /// السمايلات/الـGIF إلا عند اختيارها والضغط على زر الإرسال").
  String? _pendingGif;

  /// الرسالة التي يردّ عليها المستخدم حاليًا (اقتباس مضمَّن في نص
  /// الرسالة المُرسَلة، دون حاجة لعمود جديد في قاعدة البيانات).
  Map<String, dynamic>? _replyingTo;
  final Map<String, BuildContext> _publicMessageContexts = <String, BuildContext>{};
  List<Map<String, dynamic>> _mentionSuggestions = const [];
  Timer? _mentionTimer;
  Timer? _blockWatchTimer;
  RealtimeChannel? _diceChannel;
  RealtimeChannel? _challengeChannel;
  RealtimeChannel? _matchChannel;
  final Set<String> _diceSeen = <String>{};
  Timer? _roomTypingHeartbeat;
  Timer? _roomTypingStopTimer;
  Timer? _roomPresenceHeartbeat;
  final Map<String, String> _mentionUserIds = <String, String>{};
  final Set<String> _mentionUserNames = <String>{};
  final Set<String> _knownPublicMessageIds = <String>{};
  bool _publicMessageStreamInitialized = false;
  late final ChatSoundService _sound = ChatSoundService(_db);
  String _replyMode = 'reply';

  late Stream<List<Map<String, dynamic>>> _messages;
  late Stream<List<Map<String, dynamic>>> _globalEvents;
  // كل قناة أدناه كانت .subscribe() بلا أي معالجة لحالتها — أي
  // channelError أو timedOut (توكن منتهٍ، انقطاع لحظي) يُسقطها ميتة
  // إلى الأبد بلا أي تعافٍ تلقائي، فيبدو الشات "متصلًا" ظاهريًا بينما
  // الكتابة/الحضور/الرسائل الخاصة الواردة لم تَعُد تصل فعليًا. الآن كل
  // قناة مغلَّفة بـResilientRealtimeChannel فتُعيد الاشتراك بقناة جديدة
  // تلقائيًا بدل الموت الصامت — هذا هو تنفيذ "اتصال دائم لحظي لاينقطع".
  ResilientRealtimeChannel? _liveStateRes;
  ResilientRealtimeChannel? _rankRes;
  ResilientRealtimeChannel? _profileRes;
  ResilientRealtimeChannel? _incomingMessageRes;
  ResilientRealtimeChannel? _roomTypingRes;
  RealtimeChannel? get _roomTypingChannel => _roomTypingRes?.channel;
  bool _isRoomTyping = false;
  final Set<String> _roomTypingUids = <String>{};

  SupabaseClient get _db => Supabase.instance.client;
  User? get _user => _db.auth.currentUser;

  void _unlockRoomAudio() {
    if (_chatAudioUnlocked) return;
    unawaited(unlockChatAudio().then((ok) {
      if (ok && mounted) setState(() => _chatAudioUnlocked = true);
    }));
  }
  String get _roomId => widget.roomId;

  void _handlePublicSound(List<Map<String, dynamic>> rows) {
    final currentUid = _user?.id;
    if (currentUid == null) return;
    final currentIds =
        rows.map((r) => r['id']?.toString()).whereType<String>().toSet();
    if (!_publicMessageStreamInitialized) {
      _knownPublicMessageIds
        ..clear()
        ..addAll(currentIds);
      _publicMessageStreamInitialized = true;
      return;
    }
    final fresh = rows.where((row) {
      final id = row['id']?.toString();
      return id != null && !_knownPublicMessageIds.contains(id);
    }).toList();
    _knownPublicMessageIds
      ..clear()
      ..addAll(currentIds);
    for (final row in fresh) {
      if (row['user_id']?.toString() == currentUid) continue;
      final metadata = row['metadata'] is Map
          ? Map<String, dynamic>.from(row['metadata'] as Map)
          : const <String, dynamic>{};
      final mentioned = (metadata['mention_user_ids'] is List)
          ? (metadata['mention_user_ids'] as List<dynamic>)
              .map<String>((e) => e.toString())
              .toSet()
          : <String>{};
      final replyToUid = row['reply_to_sender_uid']?.toString();
      final kind = row['kind']?.toString();
      if (mentioned.contains(currentUid)) {
        unawaited(_sound.play(ChatSoundEvent.mention, roomId: _roomId));
      } else if (replyToUid == currentUid) {
        unawaited(_sound.play(ChatSoundEvent.reply, roomId: _roomId));
      } else if (kind == 'gift') {
        unawaited(_sound.play(ChatSoundEvent.gift, roomId: _roomId));
      } else {
        unawaited(_sound.play(ChatSoundEvent.publicMessage, roomId: _roomId));
      }
    }
  }

  @override
  void initState() {
    // عند الدخول لغرفة مفتوحة كصفحة مستقلة: إن طُرد/حُظر المستخدم يُخرَج فورًا.
    _blockWatchTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || !Navigator.of(context).canPop()) return;
      try {
        final msg = await Supabase.instance.client
            .rpc('my_room_block_message', params: {'p_room_id': widget.roomId});
        if (msg is String && msg.isNotEmpty && mounted) {
          final nav = Navigator.of(context);
          ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(msg)));
          nav.pop();
        }
      } catch (_) {}
    });
    super.initState();
    _controller.addListener(_refreshMentionSuggestions);
    _controller.addListener(_handleRoomTypingChanged);
    _roomTypingRes = ResilientRealtimeChannel(
      client: _db,
      build: (client) => client.channel(
        'room:$_roomId:typing',
        opts: const RealtimeChannelConfig(private: true),
      )..onBroadcast(event: 'room_typing', callback: _onRoomTypingBroadcast),
    );
    unawaited(_loadRoomControls());
    unawaited(_loadVisualSizeAccess());
    // لم تكن هناك أي ذاكرة لآخر غرفة دخلها المستخدم (البند ٨)؛ كل دخول
    // فعلي لغرفة يُسجَّل خادميًا فيعود إليها العضو تلقائيًا في زيارته
    // التالية (get_entry_room في home_shell.dart تقرأ هذا الحقل).
    unawaited(_db.rpc('set_my_last_room', params: {'p_room_id': _roomId}).catchError((_) {}));
    // Register presence FIRST, then load the header — _markRoomPresence
    // refreshes the header itself once the write lands, so the count is
    // computed after this account is actually recorded as present in the room.
    unawaited(_markRoomPresence());
    _roomPresenceHeartbeat =
        Timer.periodic(const Duration(seconds: 45), (_) => unawaited(_markRoomPresence()));
    unawaited(_loadChatTheme());
    unawaited(_loadMentionFrameColor());

    _messages = _db
        .from('public_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', _roomId)
        .order('created_at', ascending: true)
        .limit(150);
    _globalEvents = _db
        .from('chat_global_events')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(40);
    _subscribeDice();

    _liveStateRes = ResilientRealtimeChannel(
      client: _db,
      build: (client) => client.channel('chat-live-$_roomId')
        ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'id', value: _roomId),
            callback: (_) => unawaited(_loadRoomControls()))
        ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_room_members',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: _roomId),
            callback: (_) => unawaited(_loadRoomControls()))
        ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'platform_chat_settings',
            callback: (_) => unawaited(_loadRoomControls())),
      // كان هنا مستمع على user_presence يستدعي _markRoomPresence (كتابة) عند
      // كل تغيّر في الحضور — وتلك الكتابة نفسها تغيّر user_presence، فتنشأ
      // حلقة لا تتوقف تتضاعف مع كل عضو في الغرفة: 692 ألف استدعاء لـ
      // set_my_presence مع 3 مستخدمين، أغرقت محرّك Realtime وأسقطت الاتصال.
      // الغرض كان تحديث عدّاد ترويسة الغرفة، والترويسة حُذفت؛ الحضور يبقى
      // دقيقًا بنبضة الـ45 ثانية وقائمة المتصلين الخادمية.
    );

    // Server broadcasts role updates on this exact topic.
    _rankRes = ResilientRealtimeChannel(
      client: _db,
      build: (client) => client.channel('room:$_roomId:rank')
        ..onBroadcast(
          event: 'rank_changed',
          callback: (_) {
            if (!mounted) return;
            setState(() => _rankRevision++);
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'gamification_stats',
          callback: (payload) {
            final changedUid = payload.newRecord['user_id']?.toString().trim();
            if (changedUid != null && changedUid.isNotEmpty) {
              ref.invalidate(serverUserRankBadgeProvider(changedUid));
              ref.invalidate(
                serverUserIdentityInRoomProvider((
                  uid: changedUid,
                  roomId: _roomId,
                )),
              );
              ref.invalidate(serverUserIdentityProvider(changedUid));
            }
            if (!mounted) return;
            setState(() => _rankRevision++);
          },
        ),
    );

    if (_user != null) {
      _profileRes = ResilientRealtimeChannel(
        client: _db,
        build: (client) => client.channel('profile-sync-${_user!.id}')
          ..onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: _user!.id,
            ),
            callback: (payload) {
              final next = payload.newRecord;
              final avatar = next['avatar_url']?.toString();
              final uid = _user?.id;
              if (uid != null) {
                ref.invalidate(
                  serverUserIdentityInRoomProvider((uid: uid, roomId: _roomId)),
                );
                ref.invalidate(serverUserIdentityProvider(uid));
              }
              if (mounted) {
                setState(() {
                  _profileAvatarUrl = avatar;
                  _rankRevision++;
                });
              }
            },
          ),
      );

      // Auto-floats the mini chat the instant a private message ARRIVES,
      // for the recipient — not just for whoever opened it to send. RLS on
      // chat_messages already restricts delivery to actual participants, so
      // this only ever fires for messages that genuinely involve this user.
      _incomingMessageRes = ResilientRealtimeChannel(
        client: _db,
        build: (client) => client.channel('incoming-private-${_user!.id}')
          ..onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            callback: (payload) async {
              final row = payload.newRecord;
              final senderUid = row['sender_uid']?.toString();
              final myUid = _user?.id;
              if (senderUid == null || myUid == null || senderUid == myUid) return;
              // Respects "the user decides": never reopens a conversation the
              // user explicitly closed during this room visit.
              if (ref.read(dismissedThreadIdsProvider).contains(row['thread_id']?.toString())) return;
              try {
                final profile = await _db
                    .from('profiles')
                    .select('id,display_name,avatar_url')
                    .eq('id', senderUid)
                    .maybeSingle();
                if (!mounted || profile == null) return;
                ref.read(miniChatTargetProvider.notifier).state = MiniChatTarget(
                  threadId: row['thread_id']?.toString() ?? '',
                  peerUid: senderUid,
                  peerName: profile['display_name']?.toString() ?? 'عضو',
                  peerAvatar: profile['avatar_url']?.toString(),
                );
                ref.read(miniChatModeProvider.notifier).state = MiniChatMode.normal;
              } catch (_) {
                // Auto-opening is a convenience; a failure here must never
                // interrupt the room.
              }
            },
          ),
      );
    }

    // إعلان دخول آمن يُنشأ على الخادم فقط.
    // إعلان الترحيب يُنشأ على الخادم بعد جاهزية Realtime.
    if (_user != null) {
      // The welcome bot is the only join announcement. The server decides
      // whether this user is allowed in the room and creates the event.
      unawaited(_announceChatWelcome());
    }
  }

  String _friendlyChatError(Object error) {
    playServerSound('error');
    String code = '';
    String message = '';
    if (error is PostgrestException) {
      code = error.code ?? '';
      message = error.message;
    } else if (error.toString().contains('StorageException')) {
      try {
        final dyn = error as dynamic;
        code = dyn.statusCode?.toString() ?? '';
        message = dyn.message?.toString() ?? error.toString();
      } catch (_) {
        message = error.toString();
      }
    } else {
      final raw = error.toString();
      code = RegExp(r'code[:=]\s*([A-Z0-9_]+)').firstMatch(raw)?.group(1) ?? '';
      message = RegExp(r'message[:=]\s*([^,\)]+)').firstMatch(raw)?.group(1) ?? raw;
    }
    // قيود الكتم/الحظر/الطرد يُرجعها الخادم بصيغة "RESTRICTED_MUTE: أنت
    // مكتوم… تبقّى… السبب…" أو "CHAT_RESTRICTED: …". كان التطبيق يعرضها كما
    // هي فيرى العضو الرمز الإنجليزي ملتصقًا بالرسالة. النص العربي بعد
    // النقطتين هو الرسالة الكاملة (نوع القيد والمدة والسبب) فنعرضه وحده.
    final restricted = RegExp(
            r'^(?:CHAT_RESTRICTED|RESTRICTED_[A-Z_]+|DM_LOCKED)\s*:\s*(.+)$',
            dotAll: true)
        .firstMatch(message.trim());
    if (restricted != null) {
      final text = restricted.group(1)!.trim();
      if (text.isNotEmpty) return text;
    }
    final c = code.trim().toUpperCase();
    switch (c) {
      case 'INSUFFICIENT_POINTS':
        return 'رصيد النقاط غير كافٍ لهذه العملية.';
      case 'INSUFFICIENT_GEMS':
        return 'رصيد الجواهر غير كافٍ لهذه العملية.';
      case 'PRODUCT_NOT_AVAILABLE':
      case 'OUT_OF_STOCK':
        return 'العنصر المطلوب غير متاح حاليًا أو نفد المخزون.';
      case 'BADGE_NOT_AVAILABLE':
        return 'هذه الشارة غير متاحة حاليًا؛ اختر شارة أخرى.';
      case 'FORBIDDEN':
        return 'هذه العملية غير متاحة لحسابك في هذه الغرفة.';
      case 'AUTH_REQUIRED':
        return 'انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.';
      case 'ROOM_NOT_FOUND':
        return 'الغرفة غير متاحة حاليًا.';
      case 'EMPTY_MESSAGE':
        return 'اكتب رسالة أو أضف مرفقًا قبل الإرسال.';
      case 'INVALID_MESSAGE_TYPE':
        return 'نوع الرسالة غير مدعوم.';
      case 'REQUEST_ID_REQUIRED':
        return 'تعذر حفظ الطلب الآمن؛ أعد المحاولة.';
      case 'REPLY_TARGET_NOT_FOUND':
        return 'الرسالة التي تحاول الرد عليها لم تعد موجودة.';
      case 'INVALID_WELCOME_MESSAGE':
        return 'اكتب نص ترحيب صالحًا قبل الحفظ.';
      default:
        break;
    }
    final raw = message.trim();
    if (raw.isEmpty || raw == 'Exception' || raw == 'null') {
      return 'لم تكتمل العملية. تحقق من الاتصال ثم أعد المحاولة.';
    }
    final cleaned = raw
        .replaceFirst(RegExp(r'^PostgrestException\('), '')
        .replaceFirst(RegExp(r'^StorageException\('), '')
        .replaceFirst(RegExp(r'\)$'), '')
        .trim();
    return cleaned.isEmpty
        ? 'لم تكتمل العملية. تحقق من الاتصال ثم أعد المحاولة.'
        : cleaned;
  }

  Future<void> _announceChatWelcome() async {
    if (_user == null) return;
    final requestId = const Uuid().v4();
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.rpc('announce_chat_welcome', params: {
          'p_room_id': _roomId,
          'p_request_id': requestId,
        });
        return;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
        }
      }
    }
    assert(() {
      debugPrint('announce_chat_welcome failed: $lastError');
      return true;
    }());
  }

  Future<void> _insertPublicMessage({
    required String body,
    required String kind,
    String? attachmentUrl,
    String? message,
    String? replyToId,
    String? replyToSenderUid,
    String? replyToPreview,
    String replyMode = 'none',
  }) async {
    final user = _user;
    final payload = (message ?? body).trim();
    if (user == null || payload.isEmpty) {
      throw const FormatException('EMPTY_MESSAGE');
    }
    final requestId = const Uuid().v4();
    final metadata = <String, dynamic>{
      'reply_mode': replyMode,
      'mention_user_ids': _mentionUserIds.values.toSet().toList(),
      'mention_user_names': _mentionUserNames.toList(),
      'request_id': requestId,
      if (replyToId != null && replyMode.contains('quote'))
        'quoted_message_id': replyToId,
    };
    await _db.rpc('send_public_chat_message_v2', params: {
      'p_room_id': _roomId,
      'p_message': payload,
      'p_kind': kind,
      'p_attachment_url': attachmentUrl,
      'p_reply_to_id': replyToId,
      'p_reply_to_sender_uid': replyToSenderUid,
      'p_reply_to_preview': replyToPreview,
      'p_metadata': metadata.isEmpty ? <String, dynamic>{} : metadata,
      'p_request_id': requestId,
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    final gif = _pendingGif;
    if ((text.isEmpty && gif == null) || _user == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (gif != null) {
        await _insertPublicMessage(
          body: gif,
          message: 'GIF',
          kind: 'gif',
          attachmentUrl: gif,
        );
      }
      if (text.isNotEmpty) {
        final reply = _replyingTo;
        await _insertPublicMessage(
          body: text,
          message: text,
          kind: 'text',
          replyToId: reply?['id']?.toString(),
          replyToSenderUid: reply?['user_id']?.toString(),
          // كانت تحفظ نص الرسالة الأصلية وحده بلا اسم مرسِلها؛ بطاقة
          // الاقتباس تحتاج الاثنين معًا (المرسل + المحتوى) لا المحتوى فقط.
          // شكل مُشفَّر بفاصل: اسم المرسل|نص المعاينة|رابط مصغّرة (قد يكون
          // فارغاً). البطاقة تعرض الصورة الفعلية حين يتوفر الرابط، لا
          // النص الوصفي وحده.
          replyToPreview: reply == null ? null : '${reply['display_name']?.toString().trim().isNotEmpty == true ? reply['display_name'] : 'عضو'}|${_replySourcePreviewText(reply)}|${_replySourceThumbnail(reply)}',
          replyMode: reply == null ? 'none' : _replyMode,
        );
      }
      if (!mounted) return;
      _controller.clear();
      _mentionUserIds.clear();
      _mentionUserNames.clear();
      setState(() {
        _pendingGif = null;
        _replyingTo = null;
        _replyMode = 'reply';
      });
      // The server awards activity XP as part of the message transaction.
      // Refresh the sender's room identity so a newly reached L-level is
      // reflected immediately on subsequent chat renders.
      final senderUid = _user?.id;
      if (senderUid != null) {
        ref.invalidate(serverUserIdentityInRoomProvider((uid: senderUid, roomId: _roomId)));
        _rankRevision++;
      }
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyChatError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// زر "+" يفتح لوحات داخلية في التطبيق، ولا ينقل المستخدم إلى متصفح خارجي.
  Future<void> _showQuickActionsSheet() async {
    if (_sending) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.white),
              title: const Text('إرفاق ملف',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAttachment();
              },
            ),
            // بحث الأغاني انتقل إلى داخل زر + (كان أيقونة مستقلة في شريط
            // الكتابة) تنفيذًا لبند "نقل زر الموسيقى إلى داخل زر +".
            ListTile(
              leading:
                  const Icon(Icons.music_note_rounded, color: Colors.white),
              title: const Text('بحث أغنية',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSongSearch();
              },
            ),
            if (_showGames)
              ListTile(
                leading: const Icon(Icons.sports_esports_rounded,
                    color: Colors.white),
                title: const Text('الألعاب داخل الشات',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openGamesPanel();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBroadcastSuggestion() async {
    if (!_canManageBroadcast) return;
    String text = '';
    String type = 'idea';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اقتراح / بث المنصة',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'idea', label: Text('فكرة')),
                  ButtonSegment(value: 'live', label: Text('بث مباشر')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 10),
              TextField(
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => text = value,
                decoration: const InputDecoration(
                    hintText: 'اكتب الفكرة أو تفاصيل البث',
                    hintStyle: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final value = text.trim();
                  if (value.isEmpty) return;
                  await _db.rpc('submit_platform_broadcast_request', params: {
                    'p_request_type': type,
                    'p_body': value,
                    'p_room_id': _roomId,
                  });
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: Icon(type == 'live'
                    ? Icons.live_tv_rounded
                    : Icons.lightbulb_rounded),
                label: const Text('إرسال للجهات المخولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGamesPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('الألعاب داخل الشات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ListTile(
                leading:
                    const Icon(Icons.casino_rounded, color: Color(0xFFDFA8FF)),
                title: const Text('رمي النرد',
                    style: TextStyle(color: Colors.white)),

                onTap: () {
                  Navigator.pop(sheetContext);
                  _rollDiceInChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_rounded,
                    color: Color(0xFFDFA8FF)),
                title: const Text('ألعاب ثلاثية الأبعاد',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('أربعة في صف • حجر ورقة مقص • العملة',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showGameHub(context,
                      roomId: _roomId,
                      onIncoming: (req) async {
                        forgetPromptedGameRequest(req['id']?.toString());
                        await _routeGameRequest(req);
                      });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── النرد (الرمية والتحدي) ─────────────────────
  // النتيجة تُحسم في الخادم حصرًا (roll_dice_in_room / accept_dice_challenge)
  // ثم تُعرَض الأرقام نفسها في النرد ثلاثي الأبعاد؛ لا يوجد أي رقم محلي.

  void _subscribeDice() {
    final me = _user?.id;
    unawaited(ServerSounds.instance.prefetch());
    _diceChannel = _db
        .channel('dice-$_roomId-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_global_events',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: _roomId),
          callback: (payload) => unawaited(_onDiceEvent(payload.newRecord)),
        )
        .subscribe();
    if (me != null) {
      _challengeChannel = _db
          .channel('dice-challenge-$me-${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'game_requests',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'to_uid',
                value: me),
            callback: (payload) =>
                unawaited(_routeGameRequest(payload.newRecord)),
          )
          .subscribe();
      // المرسِل يدخل اللعبة تلقائيًا فور قبول الطرف الآخر (ينشأ صف المباراة).
      _matchChannel = _db
          .channel('game-match-$me-${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'game_matches',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'p1', value: me),
            callback: (payload) {
              final id = payload.newRecord['id']?.toString();
              if (id != null && mounted) unawaited(openGameMatch(context, id));
            },
          )
          // التركس: المرسِل يدخل عند قبول الطلب (game_requests ← accepted).
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'game_requests',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'from_uid',
                value: me),
            callback: (payload) {
              final r = payload.newRecord;
              final t = r['game_type']?.toString() ?? '';
              final res = r['result'];
              if (t.startsWith('trix_') &&
                  r['status']?.toString() == 'accepted' &&
                  res is Map &&
                  res['game_id'] != null &&
                  mounted) {
                unawaited(openTrixGame(context, res['game_id'].toString()));
              }
            },
          )
          .subscribe();
      unawaited(_checkPendingChallenge(me));
    }
  }

  Future<void> _checkPendingChallenge(String me) async {
    try {
      final since =
          DateTime.now().toUtc().subtract(const Duration(minutes: 10)).toIso8601String();
      final rows = await _db
          .from('game_requests')
          .select()
          .eq('to_uid', me)
          .eq('status', 'pending')
          .inFilter('game_type', ['dice', 'connect4', 'rps', 'coin', 'trix_solo', 'trix_partner'])
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(3);
      for (final r in rows) {
        if (!mounted) return;
        await _routeGameRequest(Map<String, dynamic>.from(r));
      }
    } catch (_) {}
  }

  Future<void> _routeGameRequest(Map<String, dynamic> req) async {
    if (!mounted) return;
    if (req['game_type']?.toString() == 'dice') {
      await _promptDiceChallenge(req);
    } else {
      await promptGameRequest(context, req);
    }
  }

  Future<void> _onDiceEvent(Map<String, dynamic> rec) async {
    if (!mounted || rec['event_type']?.toString() != 'dice_roll') return;
    final id = rec['id']?.toString() ?? '';
    if (id.isNotEmpty && !_diceSeen.add(id)) return;
    final payload = rec['payload'] is Map
        ? Map<String, dynamic>.from(rec['payload'] as Map)
        : const <String, dynamic>{};
    final me = _user?.id;
    if (payload['mode']?.toString() == 'duel') {
      final fromRoll = (payload['from_roll'] as num?)?.toInt() ?? 1;
      final toRoll = (payload['to_roll'] as num?)?.toInt() ?? 1;
      final winner = payload['winner_uid']?.toString();
      final fromName = (payload['from_name'] ?? 'عضو').toString();
      final toName = (payload['to_name'] ?? 'عضو').toString();
      final winnerName = winner == null || winner.isEmpty || winner == 'null'
          ? null
          : (winner == payload['from_uid']?.toString() ? fromName : toName);
      await AnimatedDiceRoller.showDuel(
        context,
        fromName: fromName,
        toName: toName,
        fromRoll: fromRoll,
        toRoll: toRoll,
        stake: (payload['stake'] as num?)?.toInt() ?? 0,
        winnerName: winnerName,
        finishSound: winner == null || winner.isEmpty || winner == 'null'
            ? 'game_draw'
            : (winner == me ? 'game_win' : 'game_lose'),
      );
      return;
    }
    // رمية فردية من عضو آخر: صاحبها يراها في مساره الخاص.
    if (rec['actor_uid']?.toString() == me) return;
    final result = (payload['result'] as num?)?.toInt();
    if (result == null) return;
    final prize = (payload['prize'] as num?)?.toInt() ?? 0;
    final who = (payload['from_name'] ?? 'عضو').toString();
    await AnimatedDiceRoller.show(context, result,
        label: who,
        jackpot: prize > 0,
        footer: prize > 0 ? '🎉 $who حصل على 6 وربح $prize نقطة!' : null);
  }

  Future<void> _promptDiceChallenge(Map<String, dynamic> req) async {
    if (!mounted || req['game_type']?.toString() != 'dice') return;
    if (req['status']?.toString() != 'pending') return;
    final reqId = req['id']?.toString();
    if (reqId == null || !_diceSeen.add('req-$reqId')) return;
    final stake = (req['stake_points'] as num?)?.toInt() ?? 0;
    var fromName = 'عضو';
    try {
      final row = await _db
          .from('profiles')
          .select('display_name,username')
          .eq('id', req['from_uid'].toString())
          .maybeSingle();
      final n = (row?['display_name'] ?? row?['username'])?.toString().trim();
      if (n != null && n.isNotEmpty) fromName = n;
    } catch (_) {}
    if (!mounted) return;
    playServerSound('game_request');
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('تحدي نرد 🎲'),
        content: Text(
          stake > 0
              ? '$fromName يتحداك بالنرد على $stake نقطة.\nيرمي كل منكما نردًا، والأعلى يربح $stake نقطة من الآخر، وعند التعادل لا يتغير شيء.'
              : '$fromName يتحداك بنرد ودّي (بلا نقاط).',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('رفض')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('قبول')),
        ],
      ),
    );
    if (!mounted || accept == null) return;
    try {
      if (!accept) {
        await _db.rpc('decline_dice_challenge', params: {'p_request_id': reqId});
        return;
      }
      final res = await _db.rpc('accept_dice_challenge', params: {'p_request_id': reqId});
      if (res is! Map || !mounted) return;
      // إن كان التحدي في هذه الغرفة فالحدث الحي يعرضه للجميع؛ وإلا نعرضه محليًا.
      if (res['room_id']?.toString() != _roomId) {
        final winner = res['winner_uid']?.toString();
        await AnimatedDiceRoller.showDuel(
          context,
          fromName: (res['from_name'] ?? 'عضو').toString(),
          toName: (res['to_name'] ?? 'عضو').toString(),
          fromRoll: (res['from_roll'] as num).toInt(),
          toRoll: (res['to_roll'] as num).toInt(),
          stake: (res['stake'] as num?)?.toInt() ?? 0,
          winnerName: winner == null || winner == 'null'
              ? null
              : (winner == res['from_uid']?.toString()
                  ? res['from_name']?.toString()
                  : res['to_name']?.toString()),
          finishSound: winner == null || winner == 'null'
              ? 'game_draw'
              : (winner == _user?.id ? 'game_win' : 'game_lose'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('CHALLENGER_INSUFFICIENT_POINTS')
          ? 'رصيد المتحدّي لا يكفي لهذا الرهان.'
          : raw.contains('INSUFFICIENT_POINTS')
              ? 'رصيدك من النقاط لا يكفي لقبول التحدي.'
              : raw.contains('REQUEST_EXPIRED')
                  ? 'انتهت صلاحية التحدي.'
                  : raw.contains('BLOCKED')
                      ? 'لا يمكن إكمال التحدي بسبب الحظر.'
                      : 'تعذّر إكمال التحدي.';
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(msg)));
    }
  }

  /// رمية نرد سريعة: الخادم يحسم الرقم ويبثّه لكل من في الغرفة.
  Future<void> _rollDiceInChat() async {
    if (_user == null || _sending) return;
    int roll;
    try {
      final raw = await _db.rpc('roll_dice_in_room', params: {'p_room_id': _roomId});
      roll = (raw as num).toInt();
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('DICE_LIMIT_REACHED')) {
        ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(
            content: Text('استنفدت رميات النرد المسموحة (6 رميات كل 24 ساعة).')));
      } else {
        setState(() => _error = _friendlyChatError(e));
      }
      return;
    }
    if (!mounted) return;
    await AnimatedDiceRoller.show(context, roll,
        label: 'رميتك',
        jackpot: roll == 6,
        footer: roll == 6 ? '🎉 حصلت على 6 — ربحت 10000 نقطة!' : null);
    if (!mounted) return;
    const faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    try {
      await _insertPublicMessage(
        body: 'رمى النرد وحصل على ${faces[roll - 1]} ($roll)',
        message: 'رمى النرد وحصل على $roll',
        kind: 'text',
      );
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyChatError(e));
    }
  }

  /// "أي ملف من الهاتف" — بلا قيد امتداد بعد الآن (كانت FileType.custom
  /// بقائمة امتدادات ثابتة تمنع رفع أي شيء خارجها، كملفات docx/pptx/apk).
  /// الحد الفعلي للحجم يبقى مفروضًا خادميًا على مستوى سطل التخزين نفسه
  /// (file_size_limit على bucket في Supabase Storage)، لا قيمة يختارها
  /// التطبيق فقط؛ هذا الفحص المحلي مجرّد رسالة مبكرة ودودة تطابق الحد
  /// الخادمي الحقيقي (10MB عادي/25MB لمشترك وسائط Plus) بدل حد 25MB ثابت
  /// كان يسمح برفع ما بين 10 و25MB محليًا ثم يُرفَض خادميًا بخطأ غامض.
  Future<void> _pickAttachment() async {
    if (_user == null || _sending) return;
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'تعذر قراءة المرفق من الجهاز.');
      return;
    }
    bool vipPlus = false;
    try {
      final vipRaw = await _db.rpc(
        'get_profile_service_runtime',
        params: {'p_feature_key': 'chat_media_plus'},
      );
      vipPlus = vipRaw is Map && vipRaw['enabled'] == true;
    } catch (_) {}
    final limit = vipPlus ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
    if (bytes.length > limit) {
      setState(() => _error = vipPlus
          ? 'حد الوسائط Plus هو 25MB.'
          : 'الحد الأساسي 10MB. فعّل وسائط Plus للوصول إلى 25MB.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final uploader = MediaUploadService(bucket: vipPlus ? 'chat-media-plus' : 'media');
      final url = await uploader.uploadBytes(
        bytes: bytes,
        fileName: file.name,
        // سياسة RLS على bucket "chat-media-plus" (VIP+) تفرض حرفيًا
        // chat/attachments/<uid>/...؛ "chat/lobby" كان يُرفَض خادميًا
        // بخطأ 403 لكل عضو VIP+ يرفع صورة/فيديو في شات الغرفة (مرصود
        // فعليًا كـ"ليس لديك صلاحية رفع هذا الملف"). bucket "media"
        // العادي لا يتقيّد بهذا، فالتوحيد هنا آمن للطرفين معًا.
        folder: 'chat/attachments',
        uid: _user!.id,
      );
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif']
          .contains(file.extension?.toLowerCase());
      final isVideo =
          ['mp4', 'webm', 'mov'].contains(file.extension?.toLowerCase());
      await _insertPublicMessage(
        body: file.name,
        message: file.name,
        kind: isImage ? 'image' : (isVideo ? 'video' : 'file'),
        attachmentUrl: url,
      );
      if (!mounted) return;
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyChatError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// لوحة "السمايل" الموحَّدة: إيموجي ثابتة + GIF متحركة معًا بتبويبين
  /// ضمن قسم واحد (بدل ظهور كل واحد منفصلاً بزر وورقة خاصة به).
  /// اختيار إيموجي يُدرَج مباشرة في نص الرسالة الجاري كتابتها.
  /// اختيار GIF لا يُرسَل فورًا — يُخزَّن كمعلَّق فقط ويظهر كمعاينة صغيرة
  /// أعلى صندوق الكتابة، ولا يُرسَل إلا بالضغط الصريح على زر الإرسال
  /// (مطابقة حرفية لبند "لا تُرسَل السمايلات أو الـGIF إلا عند اختيارها
  /// والضغط على زر الإرسال").
  Future<void> _showStickerAndGifPicker() async {
    await StickerAndGifSheet.show(
      context,
      onEmojiSelected: (emoji) {
        final selection = _controller.selection;
        final text = _controller.text;
        final insertAt = selection.isValid ? selection.start : text.length;
        final newText = text.replaceRange(
            insertAt, selection.isValid ? selection.end : text.length, emoji);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: insertAt + emoji.length),
        );
      },
      onGifSelected: (gif) {
        if (_user == null || !mounted) return;
        setState(() => _pendingGif = gif);
      },
    );
  }

  /// بحث أغنية/فيديو ← لا شيء يُرسَل إلا بالضغط الصريح على زر "إرسال" داخل
  /// لوحة البحث نفسها (SongSearchSheet). عند الإرسال: تُرسَل كرسالة يوتيوب
  /// عادية في الغرفة، وتُشغَّل فورًا حصرًا في المشغّل المصغّر العائم — لا
  /// تضمين تلقائي داخل الفقاعة (انظر EmbeddedMediaPlayer.routeYoutubeTo
  /// FloatingPlayer: أي رابط يوتيوب في رسالة شات يفتح عبر هذا المشغّل
  /// فقط، لا مشغّلاً مضمّنًا منفصلاً).
  Future<void> _showSongSearch() async {
    if (_user == null) return;
    await SongSearchSheet.show(context, onSend: (videoId, title) async {
      ref.read(miniPlayerProvider.notifier).state =
          MiniPlayerTrack(videoId: videoId, title: title);
      await _insertPublicMessage(
        body: 'https://www.youtube.com/watch?v=$videoId',
        message: 'https://www.youtube.com/watch?v=$videoId',
        kind: 'text',
      );
      if (!mounted) return;
      _scrollToEnd();
    });
  }

  Future<void> _sendVoice(String url) async {
    if (_user == null) return;
    try {
      await _insertPublicMessage(
        body: 'رسالة صوتية',
        message: 'رسالة صوتية',
        kind: 'audio',
        attachmentUrl: url,
      );
      if (!mounted) return;
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyChatError(e));
    }
  }



  /// نص معاينة للرسالة المُقتبَسة: كان يتحقق من body قبل kind، وbody
  /// لرسائل السمايل/الصورة/الصوت يحمل مسار المرفق نفسه (غير فارغ أبدًا)،
  /// فكانت معاينة الرد على سمايل متحرك تعرض مسار الملف الخام بدل تسمية
  /// مفهومة أو الصورة الفعلية — هذا سبب "يظهر gif بدل ظهوره". فحص النوع
  /// أولاً لكل نوع له عرض خاص، والنص الخام فقط لرسائل نصية حقيقية.
  String _replySourcePreviewText(Map<String, dynamic> row) {
    switch (row['kind']?.toString()) {
      case 'image': return '📷 صورة';
      case 'video': return '🎬 فيديو';
      case 'audio': return '🎙️ رسالة صوتية';
      case 'gif': return '';
      case 'file': return '📎 ملف';
      case 'gift': return '🎁 هدية';
    }
    final body = row['body']?.toString().trim() ?? '';
    return body.isNotEmpty ? body : (row['message']?.toString() ?? '');
  }

  /// رابط الصورة/السمايل الأصلي (إن وُجد) ليُعرَض مصغّراً فعلياً داخل
  /// بطاقة الاقتباس، لا نصاً وصفياً فقط.
  String _replySourceThumbnail(Map<String, dynamic> row) {
    final kind = row['kind']?.toString();
    if (kind == 'gif' || kind == 'image') {
      return row['attachment_url']?.toString() ?? row['body']?.toString() ?? '';
    }
    return '';
  }

  void _setReplyTo(Map<String, dynamic> row, {String mode = 'reply'}) {
    setState(() {
      _replyingTo = row;
      _replyMode = mode;
    });
  }

  void _cancelReply() => setState(() {
        _replyingTo = null;
        _replyMode = 'reply';
      });

  void _cancelPendingGif() => setState(() => _pendingGif = null);

  /// إدراج "@الاسم " في نقطة المؤشر الحالية — منشن سريع دون الحاجة
  /// لكتابة الاسم يدويًا.
  Future<void> _mentionUsernameOnly(String? uid, String? cachedUsername) async {
    final targetUid = uid?.trim();
    if (targetUid == null || targetUid.isEmpty) return;
    String? displayName;
    try {
      final raw = await _db.rpc(
        'get_user_chat_identity',
        params: <String, dynamic>{
          'p_user_id': targetUid,
          'p_room_id': _roomId,
        },
      );
      if (raw is Map) {
        displayName = raw['display_name']?.toString().trim();
      }
    } catch (_) {
      return;
    }
    if (!mounted || displayName == null || displayName.isEmpty) return;
    _mention(displayName, uid: targetUid);
  }

  void _mention(String name, {String? uid}) {
    // The trigger '@' is a typing aid only. It is removed from the actual
    // input text after selecting a member; the mention target is persisted
    // separately in metadata.
    final cleanName = name.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanName.isEmpty) return;
    final mention = '$cleanName ';
    final selection = _controller.selection;
    final text = _controller.text;
    final cursor = selection.isValid ? selection.start : text.length;
    final before = text.substring(0, cursor);
    final trigger = RegExp(r'@[^\s@]*$').firstMatch(before);
    final start = trigger?.start ?? cursor;
    final end = selection.isValid ? selection.end : cursor;
    final newText = text.replaceRange(start, end, mention);
    if (uid != null && uid.isNotEmpty) {
      final normalizedName = cleanName.toLowerCase();
      _mentionUserIds[cleanName] = uid;
      if (normalizedName.isNotEmpty) _mentionUserNames.add(normalizedName);
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + mention.length),
    );
    setState(() => _mentionSuggestions = const []);
  }

  /// قائمة إجراءات سريعة عند الضغط المطوَّل على رسالة عضو آخر: رد
  /// (اقتباس)، منشن، أو نسخ النص.
  /// الحذف يظهر لصاحب الرسالة، أو لمن يملك صلاحية إشراف في الغرفة. الخادم
  /// (delete_message) يعيد التحقق ويفرض الهرم: لا يُحذف لمن هو أعلى رتبة.
  bool _canDeleteRoomMessage(Map<String, dynamic> row) {
    final meta = row['metadata'];
    if (meta is Map && meta['deleted_by_role'] == 'moderator') return false;
    final author = row['user_id']?.toString();
    if (author != null && author == _user?.id) {
      return !(meta is Map && meta['deleted'] == true);
    }
    final c = _roomControls;
    return c['is_platform_owner'] == true ||
        c['is_room_owner'] == true ||
        c['can_mute'] == true ||
        c['can_ban'] == true ||
        c['can_kick'] == true ||
        c['can_manage_room'] == true;
  }

  Future<void> _deleteRoomMessage(Map<String, dynamic> row) async {
    final mine = row['user_id']?.toString() == _user?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: Text(mine
            ? 'ستُحذف رسالتك لدى الجميع.'
            : 'ستُحذف الرسالة لدى الجميع حذفًا إداريًا نهائيًا لا يستطيع صاحبها التراجع عنه.'),
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
      await _db.rpc('delete_message',
          params: {'p_scope': 'room', 'p_message_id': row['id'].toString()});
      m.showSnackBarSfx(const SnackBar(content: Text('حُذفت الرسالة')));
    } catch (e) {
      final t = e.toString();
      m.showSnackBarSfx(SnackBar(
          content: Text(t.contains('MESSAGE_REMOVED_BY_MODERATOR')
              ? 'حذفت الإدارة هذه الرسالة نهائيًا.'
              : t.contains('TARGET_ROLE_TOO_HIGH') || t.contains('FORBIDDEN') || t.contains('MEMBER_NOT_FOUND')
                  ? 'لا يمكنك حذف رسالة عضو أعلى منك رتبة.'
                  : 'تعذّر الحذف: $t')));
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> row) async {
    final body = (row['body'] ?? row['message'])?.toString() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: const Text('رد', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _setReplyTo(row, mode: 'reply');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.format_quote_rounded, color: Colors.white),
              title:
                  const Text('اقتباس', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _setReplyTo(row, mode: 'quote');
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded, color: Colors.white),
              title: const Text('إعادة توجيه', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                ForwardMessageSheet.show(context,
                    body: body,
                    kind: row['kind']?.toString() ?? 'text',
                    attachmentUrl: row['attachment_url']?.toString());
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white),
              title: const Text('مشاركة', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                final url = row['attachment_url']?.toString() ?? '';
                final text = [body, if (url.isNotEmpty) url]
                    .where((e) => e.trim().isNotEmpty)
                    .join('\n');
                if (text.isNotEmpty) Share.share(text);
              },
            ),
            if (_canDeleteRoomMessage(row))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('حذف', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_deleteRoomMessage(row));
                },
              ),
            ListTile(
              leading: const Icon(Icons.alternate_email, color: Colors.white),
              title: const Text('منشن', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(
                  _mentionUsernameOnly(
                    row['user_id']?.toString(),
                    null,
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.card_giftcard, color: Color(0xFFFFD54F)),
              title: const Text('إرسال هدية',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final targetUid = row['user_id']?.toString();
                if (targetUid == null ||
                    targetUid.isEmpty ||
                    targetUid == _user?.id) {
                  return;
                }
                await GiftPickerSheet.show(context, (gift) async {
                  if (!mounted) return;
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('تأكيد إرسال الهدية'),
                          content: Text(
                            'هل تريد إرسال ${gift.nameAr} ${gift.emoji} إلى العضو؟',
                            textAlign: TextAlign.right,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('تأكيد'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (!confirmed || !mounted) return;
                  try {
                    final result =
                        await _db.rpc('send_room_gift_atomic', params: {
                      'p_room_id': _roomId,
                      'p_to_uid': targetUid,
                      'p_gift_id': gift.id,
                      'p_request_id': const Uuid().v4(),
                    });
                    if (!mounted) return;
                    final map = result is Map
                        ? Map<String, dynamic>.from(result)
                        : <String, dynamic>{};
                    final replayed = map['replayed'] == true;
                    final fromName = map['fromName']?.toString() ?? 'عضو';
                    final toName = map['toName']?.toString() ?? 'عضو';
                    ScaffoldMessenger.of(context).showSnackBarSfx(
                      SnackBar(
                        content: Text(
                          replayed
                              ? 'تمت معالجة الهدية مسبقًا.'
                              : '🎁 $fromName أرسل ${map['giftName'] ?? gift.nameAr} ${map['emoji'] ?? gift.emoji} إلى $toName ✓',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBarSfx(
                        SnackBar(content: Text('تعذر إرسال الهدية: $e')));
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: Colors.white),
              title:
                  const Text('نسخ النص', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (body.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: body));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMiniProfile(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    final action = await MiniProfilePopup.show(context, uid, roomId: _roomId);
    if (!mounted || action != 'full_profile') return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileViewPage(uid: uid)),
    );
  }

  Future<void> _loadMentionFrameColor() async {
    try {
      final response = await _db.rpc('get_chat_username_frame_color');
      if (!mounted) return;
      final value = response?.toString().toLowerCase() ?? 'gold';
      if (value == 'gold' || value == 'red' || value == 'blue') {
        setState(() => _mentionFrameColor = value);
      }
    } catch (_) {
      // Keep the server-safe default if settings cannot be loaded.
    }
  }

  Future<void> _loadChatTheme() async {
    final user = _user;
    if (user == null) return;
    try {
      final response = await _db.rpc(
        'get_my_chat_theme',
        params: {'p_room_id': _roomId},
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(
          () => _chatThemeId = data['theme_id']?.toString() ?? 'royal_dark');
    } catch (_) {
      // الثيم إعداد غير أساسي؛ لا يمنع الشات ولا يعرض خطأً أحمر للمستخدم.
    }
  }

  Future<void> _saveChatTheme(ChatThemeDefinition theme) async {
    try {
      await _db.rpc(
        'set_my_chat_theme',
        params: {
          'p_room_id': _roomId,
          'p_theme_id': theme.id,
          'p_background_key': theme.backgroundKey,
        },
      );
      if (!mounted) return;
      setState(() => _chatThemeId = theme.id);
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تم حفظ ثيم "${theme.name}" لهذا الشات ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تعذّر حفظ الثيم: $e')),
      );
    }
  }

  Future<void> _openChatThemes() async {
    await ChatThemePickerSheet.show(
      context: context,
      selectedId: _chatThemeId,
      onSelected: _saveChatTheme,
    );
  }

  Future<void> _loadRoomControls() async {
    final user = _user;
    if (user == null) return;
    try {
      Map<String, dynamic> controls = <String, dynamic>{};
      try {
        final response = await _db.rpc(
          'get_my_room_controls',
          params: {'p_room_id': _roomId},
        );
        if (response is Map) {
          controls = Map<String, dynamic>.from(response);
        }
      } catch (_) {
        // The RPC remains the authority; this fallback only reconstructs the
        // owner UI state from the canonical room row so the options button
        // cannot become read-only because of a transient RPC/read issue.
      }

      if (controls.isEmpty ||
          (!controls.containsKey('can_manage_room') &&
              !controls.containsKey('is_room_owner'))) {
        final row = await _db
            .from('chat_rooms')
            .select('owner_id,settings,is_active')
            .eq('id', _roomId)
            .maybeSingle();
        final roomOwner = row?['owner_id']?.toString();
        final isRoomOwner = roomOwner == user.id;
        bool isPlatformOwner = false;
        try {
          isPlatformOwner = await _db.rpc('is_my_platform_owner') == true;
        } catch (_) {}
        final settings = row?['settings'] is Map
            ? Map<String, dynamic>.from(row!['settings'] as Map)
            : const <String, dynamic>{};
        controls = <String, dynamic>{
          ...controls,
          'is_room_owner': isRoomOwner,
          'is_platform_owner': isPlatformOwner,
          'can_manage_room': isRoomOwner || isPlatformOwner,
          'show_mic': settings['show_mic'] != false,
          'show_games': settings['show_games'] != false,
          'show_media': settings['show_media'] != false,
          'locked': settings['locked'] == true,
          'youtube_enabled': settings['youtube_enabled'] != false,
          'tiktok_enabled': settings['tiktok_enabled'] != false,
        };
      }
      String? avatar;
      try {
        final raw = await _db.rpc(
          'get_public_profile_cosmetics',
          params: {'p_user_id': user.id},
        );
        final profile = raw is List && raw.isNotEmpty && raw.first is Map
            ? Map<String, dynamic>.from(raw.first as Map)
            : const <String, dynamic>{};
        avatar = _normalizeProfileAvatarUrl(profile['avatar_url']?.toString());
      } catch (_) {}
      var isPlatformOwner = controls['is_platform_owner'] == true;
      if (!isPlatformOwner) {
        try {
          isPlatformOwner = await _db.rpc('is_my_platform_owner') == true;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _roomControls = controls;
        _showMic = controls['show_mic'] != false;
        _showGames = controls['show_games'] != false;
        _showMedia = controls['show_media'] != false;
        _isPlatformOwner = isPlatformOwner;
        _profileAvatarUrl = avatar;
      });
      try {
        final permission = await _db.rpc('has_permission',
            params: {'requested_permission': 'broadcast_messages'});
        if (mounted) setState(() => _canManageBroadcast = permission == true);
      } catch (_) {
        if (mounted) setState(() => _canManageBroadcast = _isPlatformOwner);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyChatError(e));
    }
  }

  Future<void> _loadVisualSizeAccess() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      final raw = await _db.rpc('get_chat_visual_size_config', params: {'p_user_id': uid});
      if (!mounted || raw is! Map) return;
      final m = Map<String, dynamic>.from(raw);
      setState(() {
        _canManageVisualSize = m['can_manage_self'] == true;
      });
    } catch (_) {
      if (mounted) setState(() => _canManageVisualSize = _isPlatformOwner);
    }
  }

  Future<void> _markRoomPresence() async {
    if (_user == null) return;
    try {
      // Uses the EXISTING presence RPC (it already writes current_room_id and
      // handles the paid "appear offline" rule) instead of a second function
      // doing the same job.
      await _db.rpc('set_my_presence',
          params: {'p_is_online': true, 'p_current_room_id': _roomId});
      // Refresh the header immediately after registering. Previously the
      // header was loaded BEFORE presence was written, so it always computed
      // 0, and nothing re-read it afterwards unless a realtime event happened
      // to arrive — which is why "0 عضو" never changed.
    } catch (_) {
      // Presence is best-effort and must never interrupt chatting.
    }
  }


  void _scrollToEnd() {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 120), () async {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      await _scroll.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }));
  }

  void _onRoomTypingBroadcast(Map<String, dynamic> payload) {
    final uid = payload['user_id']?.toString();
    if (uid == null || uid.isEmpty || uid == _user?.id || !mounted) return;
    final typing = payload['is_typing'] == true;
    setState(() {
      if (typing) {
        _roomTypingUids.add(uid);
      } else {
        _roomTypingUids.remove(uid);
      }
    });
  }

  void _handleRoomTypingChanged() {
    final uid = _user?.id;
    final channel = _roomTypingChannel;
    if (uid == null || channel == null) return;
    final hasText = _controller.text.trim().isNotEmpty;
    _roomTypingHeartbeat?.cancel();
    _roomTypingStopTimer?.cancel();
    if (hasText != _isRoomTyping) {
      _isRoomTyping = hasText;
      unawaited(channel.sendBroadcastMessage(
        event: 'room_typing',
        payload: <String, dynamic>{
          'room_id': _roomId,
          'user_id': uid,
          'is_typing': hasText,
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      ));
    }
    if (hasText) {
      _roomTypingHeartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isRoomTyping) return;
        unawaited(channel.sendBroadcastMessage(
          event: 'room_typing',
          payload: <String, dynamic>{
            'room_id': _roomId,
            'user_id': uid,
            'is_typing': true,
            'ts': DateTime.now().toUtc().toIso8601String(),
          },
        ));
      });
      _roomTypingStopTimer = Timer(const Duration(milliseconds: 3200), () {
        if (!_isRoomTyping) return;
        _isRoomTyping = false;
        unawaited(channel.sendBroadcastMessage(
          event: 'room_typing',
          payload: <String, dynamic>{
            'room_id': _roomId,
            'user_id': uid,
            'is_typing': false,
            'ts': DateTime.now().toUtc().toIso8601String(),
          },
        ));
      });
    }
  }

  void _refreshMentionSuggestions() {
    final text = _controller.text;
    final cursor = _controller.selection.isValid
        ? _controller.selection.start
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
        final raw = await _db.rpc(
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
    final cleanName = name.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanName.isEmpty) return;
    final uid = row['id']?.toString();
    final text = _controller.text;
    final cursor = _controller.selection.isValid
        ? _controller.selection.start
        : text.length;
    final before = text.substring(0, cursor);
    final m = RegExp(r'@([\w\u0600-\u06FF._-]*)$').firstMatch(before);
    if (m == null) return;
    final mention = '$cleanName ';
    _controller.value = TextEditingValue(
        text: text.replaceRange(m.start, cursor, mention),
        selection: TextSelection.collapsed(offset: m.start + mention.length));
    if (uid != null && uid.isNotEmpty) {
      final normalizedName = cleanName.toLowerCase();
      _mentionUserIds[cleanName] = uid;
      if (normalizedName.isNotEmpty) _mentionUserNames.add(normalizedName);
    }
    setState(() => _mentionSuggestions = const []);
  }


  @override
  void dispose() {
    _blockWatchTimer?.cancel();
    final diceCh = _diceChannel;
    if (diceCh != null) unawaited(_db.removeChannel(diceCh));
    final chCh = _challengeChannel;
    if (chCh != null) unawaited(_db.removeChannel(chCh));
    final mCh = _matchChannel;
    if (mCh != null) unawaited(_db.removeChannel(mCh));
    _mentionTimer?.cancel();
    _controller.removeListener(_refreshMentionSuggestions);
    _controller.removeListener(_handleRoomTypingChanged);
    _roomTypingHeartbeat?.cancel();
    _roomTypingStopTimer?.cancel();
    _roomPresenceHeartbeat?.cancel();
    final uid = _user?.id;
    if (uid != null && _roomTypingChannel != null) {
      unawaited(_roomTypingChannel!.sendBroadcastMessage(
        event: 'room_typing',
        payload: <String, dynamic>{'room_id': _roomId, 'user_id': uid, 'is_typing': false},
      ));
    }
    unawaited(_roomTypingRes?.dispose());
    _publicMessageContexts.clear();
    _controller.dispose();
    _scroll.dispose();
    unawaited(_liveStateRes?.dispose());
    unawaited(_rankRes?.dispose());
    unawaited(_profileRes?.dispose());
    unawaited(_incomingMessageRes?.dispose());
    if (_user != null) {
      unawaited(_db.rpc('set_my_presence',
          params: {'p_is_online': false, 'p_current_room_id': null}));
    }
    super.dispose();
  }

  void _jumpToPublicMessage(String id) {
    final ctx = _publicMessageContexts[id];
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
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _unlockRoomAudio(),
      child: Scaffold(
      backgroundColor: const Color(0xFF0C0714),
      // The private conversation floats ABOVE the room in a Stack, so the
      // public chat stays visible and usable underneath instead of being
      // covered by a full-screen page.
      body: SafeArea(
        child: Stack(
          children: [
        // خلفية الغرفة الحقيقية من الخادم (إن وُجدت) — تُرسم خلف كل شيء،
        // ولم تكن هذه الطبقة موجودة إطلاقًا قبل هذه الميزة.
        Consumer(builder: (context, ref, _) {
          final bg = ref.watch(roomBackgroundProvider(_roomId)).valueOrNull;
          if (bg == null || bg.isEmpty) return const SizedBox.shrink();
          return Positioned.fill(
            child: Image.network(bg, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          );
        }),
        Column(
          children: [
            _TopBar(
              onMenu: _showMenu,
              onVip: _openMemberships,
              onPrinces: _openLeaderboard,
              onMessages: _openMessages,
              onRequest: _openRequests,
              onNotifications: _openNotifications,
              onReport: _openReport,
              onSettings: _openSettings,
              onThemes: _openChatThemes,
              onBroadcastSuggestion: _openBroadcastSuggestion,
              canManageBroadcast: _canManageBroadcast,
              avatarUrl: _profileAvatarUrl,
            ),
            // شريط اسم الغرفة/عدد الخياطين أُزيل بطلب المالك —
            // الشريط العلوي وحده يكفي.
            // كراسي المايك (نمط تيك توك): الحالة والصلاحيات كلها خادمية.
            if (_showMic) RoomMicSeats(roomId: _roomId) else const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _globalEvents,
                builder: (context, globalSnapshot) {
                  final globalRows =
                      globalSnapshot.data ?? const <Map<String, dynamic>>[];
                  Map<String, dynamic>? latestGlobal;
                  if (globalRows.isNotEmpty) {
                    final now = DateTime.now();
                    for (final e in globalRows.reversed) {
                      final type = e['event_type']?.toString();
                      final roomId = e['room_id']?.toString();
                      final expires =
                          DateTime.tryParse(e['expires_at']?.toString() ?? '');
                      if (type == 'welcome_bot' && roomId != _roomId) continue;
                      if (expires == null || expires.isAfter(now)) {
                        latestGlobal = e;
                        break;
                      }
                    }
                  }
                  final recentGlobal = globalRows.where((e) {
                    final type = e['event_type']?.toString();
                    final created =
                        DateTime.tryParse(e['created_at']?.toString() ?? '');
                    final expires =
                        DateTime.tryParse(e['expires_at']?.toString() ?? '');
                    return (type == 'gift' ||
                            type == 'points_transfer' ||
                            type == 'gems_transfer') &&
                        (created == null ||
                            created.isAfter(DateTime.now()
                                .subtract(const Duration(days: 7)))) &&
                        (expires == null || expires.isAfter(DateTime.now()));
                  }).toList()
                    ..sort((a, b) =>
                        (DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                                DateTime.fromMillisecondsSinceEpoch(0))
                            .compareTo(DateTime.tryParse(
                                    b['created_at']?.toString() ?? '') ??
                                DateTime.fromMillisecondsSinceEpoch(0)));
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ChatThemeBackground(
                        theme: ChatThemeDefinition.byId(_chatThemeId),
                        // خلفية الغرفة المرفوعة تُرسم أسفل هذه الطبقة؛
                        // فإن وُجدت نتنحّى عنها كليًا لتظهر الصورة ولا
                        // يبقى فوقها إلا فقاعات الرسائل.
                        transparent: (ref
                                    .watch(roomBackgroundProvider(_roomId))
                                    .valueOrNull
                                    ?.isNotEmpty ??
                                false),
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _messages,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return _ErrorState(
                                  error: snapshot.error.toString());
                            }
                            final rows = snapshot.data ?? const [];
                            final displayRows = <Map<String, dynamic>>[
                              ...recentGlobal.map((e) => {
                                    'id': 'global-${e['id']}',
                                    'user_id': e['actor_uid'],
                                    'room_id': _roomId,
                                    'display_name': (e['payload'] is Map)
                                        ? ((e['payload'] as Map)['from_name'] ??
                                            'عضو')
                                        : 'عضو',
                                    'avatar_url': (e['payload'] is Map)
                                        ? ((e['payload']
                                                as Map)['avatar_url'] ??
                                            '')
                                        : '',
                                    'message': '',
                                    'body': '',
                                    'kind': 'global_event',
                                    'attachment_url': '',
                                    'metadata': {'global_event': e},
                                    'created_at': e['created_at'],
                                  }),
                              ...rows,
                            ];
                            displayRows.sort((a, b) => (DateTime.tryParse(
                                        a['created_at']?.toString() ?? '') ??
                                    DateTime.fromMillisecondsSinceEpoch(0))
                                .compareTo(DateTime.tryParse(
                                        b['created_at']?.toString() ?? '') ??
                                    DateTime.fromMillisecondsSinceEpoch(0)));
                            var messageFrameIndex = 0;
                            for (final messageRow in displayRows) {
                              final kind = messageRow['kind']?.toString();
                              final metadata = messageRow['metadata'] is Map
                                  ? Map<String, dynamic>.from(messageRow['metadata'] as Map)
                                  : const <String, dynamic>{};
                              final isGlobalEvent = kind == 'global_event';
                              final isWelcomeBot = kind == 'system' &&
                                  metadata['system_event']?.toString() == 'welcome_bot';
                              if (!isGlobalEvent && !isWelcomeBot) {
                                messageRow['_message_frame_index'] = messageFrameIndex++;
                              }
                            }
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _handlePublicSound(
                                    List<Map<String, dynamic>>.from(rows));
                              }
                            });
                            if (displayRows.isEmpty) return const _EmptyLobby();
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => _scrollToEnd());
                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              itemCount: displayRows.length,
                              itemBuilder: (_, i) {
                                final row = displayRows[i];
                                if (row['kind'] == 'global_event') {
                                  return _GlobalChatEventRow(
                                      event: (row['metadata']
                                              as Map)['global_event']
                                          as Map<String, dynamic>);
                                }
                                final metadata = row['metadata'] is Map
                                    ? Map<String, dynamic>.from(row['metadata'] as Map)
                                    : const <String, dynamic>{};
                                final isWelcomeBot = row['kind']?.toString() == 'system' &&
                                    metadata['system_event']?.toString() == 'welcome_bot';
                                final rowId = row['id']?.toString() ?? 'row-$i';
                                final occurrenceKey = '$rowId#$i';
                                // إعلان هدية داخل الغرفة: يُعرض كصفّ مميّز
                                // يُبرز رمز الهدية الحقيقي (صورتها إن وُجدت،
                                // وإلا الإيموجي الخاص بها من كتالوج الهدايا
                                // على الخادم) — فالسيجارة تظهر سيجارة فعلًا،
                                // لا نصًّا عامًّا.
                                if (row['kind']?.toString() == 'gift' &&
                                    metadata['announcement'] == true) {
                                  return KeyedSubtree(
                                    key: ValueKey(occurrenceKey),
                                    child: _GiftAnnouncementRow(
                                      message: row['message']?.toString() ?? '',
                                      emoji: metadata['emoji']?.toString() ?? '🎁',
                                      imageUrl: metadata['image_url']?.toString(),
                                    ),
                                  );
                                }
                                return Builder(
                                  builder: (itemContext) {
                                    if (itemContext.mounted &&
                                        !_publicMessageContexts.containsKey(rowId)) {
                                      _publicMessageContexts[rowId] = itemContext;
                                    } else if (itemContext.mounted) {
                                      _publicMessageContexts[rowId] = itemContext;
                                    }
                                    return KeyedSubtree(
                                      key: ValueKey(occurrenceKey),
                                      child: _ChatMessageRow(
                                      row: row,
                                      messageFrameIndex: (row['_message_frame_index'] as int?) ?? -1,
                                      mine: row['user_id']?.toString() ==
                                          _user?.id,
                                      mentionFrameColor: _mentionFrameColor,
                                      onAvatarTap: () => _openMiniProfile(
                                          row['user_id']?.toString()),
                                      onLongPress: () =>
                                          _showMessageActions(row),
                                      onReplyQuote: () =>
                                          _setReplyTo(row, mode: 'quote'),
                                      onJumpToMessage: _jumpToPublicMessage,
                                      roomId: _roomId,
                                      rankRevision: _rankRevision,
                                      isSystemBot: isWelcomeBot,
                                      currentUid: _user?.id,
                                      onNameTap: () => unawaited(
                                          _mentionUsernameOnly(
                                              row['user_id']?.toString(),
                                              row['username']?.toString())),
                                          onGifTap: (url) {
                                            // سلوك سمايل عادي بالضبط: يوضع في
                                            // صندوق الإرسال بصمت (المعاينة فوق
                                            // الحقل كافية)، ويُرسَل بالسهم — بلا
                                            // أي رسالة تأكيد تقاطع المستخدم.
                                            setState(() => _pendingGif = url);
                                          },
                                          onVideoTap: (url) {
                                          if (!mounted) return;
                                          setState(() {
                                            _activeMediaUrl = url;
                                            _mediaExpanded = true;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (latestGlobal != null)
                        Positioned.fill(
                            child: _GlobalEventOverlay(
                                key: ValueKey(latestGlobal['id']),
                                event: latestGlobal)),
                    ],
                  );
                },
              ),
            ),
            if (_mentionSuggestions.isNotEmpty)
              Container(
                  height: 52,
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
                                    color: const Color(0xFF21142D),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text('@${r['username'] ?? 'عضو'}',
                                    style: const TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800))));
                      })),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 11))),
              ),
            if (_replyingTo != null)
              _PendingBar(
                icon: Icons.reply,
                label:
                    '${_replyMode == 'quote' || _replyMode == 'quote_3d' ? 'اقتباس من' : 'رد على'} ${_replyingTo!['display_name'] ?? 'عضو'}: '
                    '${(_replyingTo!['body'] ?? '📎 مرفق').toString()}',
                onCancel: _cancelReply,
              ),
            if (_pendingGif != null)
              _PendingGifBar(
                gif: _pendingGif!,
                onCancel: _cancelPendingGif,
              ),
            if (_activeMediaUrl != null && _showMedia)
              Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          const Icon(Icons.music_note_rounded,
                              color: Color(0xFFC187FF), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                              child: Text('مشغل الوسائط',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800))),
                          IconButton(
                              icon: Icon(
                                  _mediaExpanded
                                      ? Icons.expand_more
                                      : Icons.expand_less,
                                  color: Colors.white),
                              onPressed: () => setState(
                                  () => _mediaExpanded = !_mediaExpanded)),
                          IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white70),
                              onPressed: () => setState(() {
                                    _activeMediaUrl = null;
                                    _mediaExpanded = false;
                                  })),
                        ],
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: _mediaExpanded ? 200 : 28,
                    child: EmbeddedMediaPlayer(url: _activeMediaUrl!),
                  ),
                ],
              ),
            _VideoStyleBottomBar(
              showOptions: true,
              onRooms: _openRooms,
              onOnline: _openOnline,
              onFriends: _openFriends,
              onChatStore: _openChatStore,
              showMediaPlay: _activeMediaUrl != null,
              onMedia: _activeMediaUrl == null
                  ? null
                  : () => setState(() => _mediaExpanded = true),
              onOptions: () async {
                final navigator = Navigator.of(context);
                await _loadRoomControls();
                if (!mounted) return;
                final deleted = await navigator.push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RoomManagementPage(
                      roomId: _roomId,
                      initialControls: Map<String, dynamic>.from(_roomControls),
                    ),
                  ),
                );
                if (!mounted) return;
                if (deleted == true) {
                  navigator.maybePop();
                  return;
                }
                await _loadRoomControls();
              },
            ),
            if (_roomTypingUids.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _roomTypingUids.length == 1
                        ? 'عضو يكتب الآن…'
                        : '${_roomTypingUids.length} أعضاء يكتبون الآن…',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            _Composer(
              controller: _controller,
              sending: _sending,
              onAttach: _showQuickActionsSheet,
              onSticker: _showStickerAndGifPicker,
              onVoice: _sendVoice,
              onSend: _sendText,
              textColor: () {
                // Same canonical profiles.message_color the sent bubble
                // renders with — one source for composer + sent message,
                // in both public rooms and private chat (spec item 6).
                final v = ref
                    .watch(currentProfileProvider)
                    .valueOrNull
                    ?.messageColor;
                return (v == null || v == 4294967295) ? null : Color(v);
              }(),
            ),
          ],
        ),
        // Floating private chat (mini messages) — minimize / fullscreen /
        // close, with its own per-conversation wallpaper.
        MiniChatOverlay(
          contentBuilder: (target) => ChatThreadPage(
            threadId: target.threadId,
            otherUid: target.peerUid,
            otherName: target.peerName,
          ),
        ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _openRooms() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChatRoomsPage()));
  }

  Future<void> _openOnline() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OnlineNowPage(roomId: _roomId)));
  }

  Future<void> _openFriends() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FriendsListPage()));
  }

  Future<void> _openChatStore() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileCosmeticStorePage()));
  }

  Future<void> _openMessages() async {
    // إن كانت هناك محادثة خاصة عائمة مفتوحة أصلًا لكن مُصغَّرة إلى فقاعة
    // (miniChatTargetProvider != null، والوضع minimized)، فزر "رسالة" هنا
    // يعيدها إلى وضعها الطبيعي بدل فتح قائمة المحادثات من جديد — تمامًا
    // كما يفعل الضغط على الفقاعة المصغَّرة نفسها في mini_chat_overlay.dart.
    // تُستعاد فقط إن كانت مُصغَّرة فعلًا؛ إن كانت مفتوحة أصلًا فالضغط لا
    // يفعل شيئًا (كان المستخدم يرى الزر «لا يُظهر المحادثات»)، فنفتح القائمة.
    if (ref.read(miniChatTargetProvider) != null &&
        ref.read(miniChatModeProvider) == MiniChatMode.minimized) {
      ref.read(miniChatModeProvider.notifier).state = MiniChatMode.normal;
      return;
    }
    // لا محادثة عائمة قائمة حاليًا: ورقة منزلقة لا شاشة كاملة، كانت
    // MaterialPageRoute تغطّي الغرفة كليًا فتنقطع متابعة الدردشة لمجرد
    // إلقاء نظرة على الرسائل. الورقة تترك أعلى الغرفة ظاهرًا، وتُغلق بالسحب
    // لأسفل، واختيار محادثة منها يفتحها كنافذة عائمة كالمعتاد.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .94,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: ConversationsPage(scrollController: scrollController),
        ),
      ),
    );
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const FriendsListPage(initialTabIndex: 1)),
    );
  }

  Future<void> _openNotifications() async {
    await NotificationsPage.showSheet(context);
  }

  Future<void> _openMemberships() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionsPage()),
    );
  }

  Future<void> _openLeaderboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  Future<void> _openReport() async {
    await showReportDialog(
      context: context,
      ref: ref,
      targetType: ReportTargetType.chatMessage,
      targetId: 'public_lobby',
    );
  }

  /// 1- "الحالة": متصل/مشغول/بعيد — تُخزَّن في accounts/{uid}.presenceStatus.
  Future<void> _openStatusPicker() async {
    if (_user == null) return;
    final current =
        await AccountSettingsStore.readField(_user!.id, 'presenceStatus');
    if (!mounted) return;
    const options = {
      'online': ('متصل', Icons.circle, Colors.greenAccent),
      'busy': ('مشغول', Icons.do_not_disturb_on, Colors.redAccent),
      'away': ('بعيد', Icons.bedtime, Colors.amberAccent),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: options.entries.map((e) {
            final (label, icon, color) = e.value;
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(label, style: const TextStyle(color: Colors.white)),
              trailing: current == e.key
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
              onTap: () => Navigator.pop(sheetContext, e.key),
            );
          }).toList(),
        ),
      ),
    );
    if (selected == null) return;
    await AccountSettingsStore.writeField(
        _user!.id, 'presenceStatus', selected);
  }

  /// 2- "حائط الأصدقاء".
  Future<void> _openFriendsWall() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FriendsWallPage()));
  }

  /// 3- "الاعلانات الممولة".
  Future<void> _openSponsoredAds() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SponsoredAdsPage()));
  }

  /// 4- "تحديث التطبيق او الصفحه ان علق التطبيق بسبب النت" — يعيد
  /// الاشتراك في تيّار الرسائل من جديد ويعيد بناء الشاشة، أبسط
  /// إجراء "تحديث يدوي" ممكن دون إعادة تشغيل التطبيق كاملًا.
  void _refreshLobby() {
    setState(() {
      _messages = _db
          .from('public_chat_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', _roomId)
          .order('created_at', ascending: true)
          .limit(150);
    });
    ScaffoldMessenger.of(context).showSnackBarSfx(
      const SnackBar(
          content: Text('تم تحديث الشات'), duration: Duration(seconds: 1)),
    );
  }

  /// 5- "البحث" (ضمن المنصة كلها).
  Future<void> _openSearch() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchPage()));
  }

  /// 6- "ملوك النقاط" و7- "ملوك الجواهر" — نفس صفحة لوحة الصدارة،
  /// على تبويب مختلف.
  Future<void> _openPointsKings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const LeaderboardPage(initialTabIndex: 0)),
    );
  }

  Future<void> _openGemsKings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const LeaderboardPage(initialTabIndex: 2)),
    );
  }

  /// 8- "العرش الملكي للعضويات المدفوعة".
  Future<void> _openRoyalThrone() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const DirectoryListPage(
        title: 'العرش الملكي 👑',
        emptyIcon: Icons.workspace_premium_outlined,
        emptyMessage: 'لا يوجد مشتركون في عضوية مدفوعة بعد',
        fetcher: LobbyDirectoryService.fetchTopSubscribers,
      ),
    ));
  }

  /// 9- "عدد تفاعل المستخدمين النشيطين" — يعيد استخدام شاشة
  /// "المتواجدون الآن" الموجودة مسبقًا.
  Future<void> _openActiveMembers() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OnlineNowPage(roomId: _roomId)));
  }

  /// 10- "طاقم الادارة".
  Future<void> _openAdminTeam() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const DirectoryListPage(
        title: 'طاقم الإدارة 🛡️',
        emptyIcon: Icons.shield_outlined,
        emptyMessage: 'لم يُعيَّن طاقم إداري بعد',
        fetcher: LobbyDirectoryService.fetchAdminTeam,
      ),
    ));
  }

  /// 11- "زر التواصل مع مدير المنصة دراغون".
  Future<void> _contactDragonOwner() async {
    final myUid = _user?.id;
    if (myUid == null) return;
    final dragonUid = await LobbyDirectoryService.findPlatformOwnerUid();
    if (!mounted) return;
    if (dragonUid == null) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('تعذّر العثور على حساب DRAGON حاليًا')),
      );
      return;
    }
    final sorted = [myUid, dragonUid]..sort();
    openPrivateChat(
      context,
      ref,
      threadId: '${sorted[0]}_${sorted[1]}',
      peerUid: dragonUid,
      peerName: 'DRAGON',
    );
  }

  Future<void> _openCreateRoom() async {
    if (!_isPlatformOwner) return;
    String roomName = '';
    String roomDescription = '';
    var isPublic = true;
    final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF171126),
                title: const Text('إنشاء غرفة جديدة',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        onChanged: (value) => roomName = value,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'اسم الغرفة *',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF241832),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => roomDescription = value,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'وصف الغرفة',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF241832),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isPublic,
                        onChanged: (value) =>
                            setDialogState(() => isPublic = value),
                        title: const Text('غرفة عامة',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                        subtitle: const Text(
                            'يمكن للأعضاء الوصول إليها من دليل الغرف.',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء')),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_home_work_rounded),
                    label: const Text('إنشاء'),
                    onPressed: () async {
                      final name = roomName.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBarSfx(
                            const SnackBar(content: Text('أدخل اسم الغرفة.')));
                        return;
                      }
                      try {
                        final response =
                            await _db.rpc('create_chat_room', params: {
                          'p_name': name,
                          'p_description':
                              roomDescription.trim().isEmpty
                                  ? null
                                  : roomDescription.trim(),
                          'p_is_public': isPublic,
                        });
                        final roomId = response?.toString();
                        if (roomId == null || roomId.isEmpty) {
                          throw Exception('لم يتم إرجاع معرف الغرفة.');
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext, true);
                        if (!mounted) return;
                        await Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => ChatLobbyPage(roomId: roomId)));
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBarSfx(
                            SnackBar(content: Text('تعذر إنشاء الغرفة: $e')));
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    if (result == true && mounted) await _loadRoomControls();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    if (!mounted) return;
    await _loadRoomControls();
  }

  Future<void> _showMenu() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'قائمة الشات',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: math.min(
                    MediaQuery.of(dialogContext).size.width * .86, 390),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * .82,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF171126),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x663E1B50)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 24,
                        offset: Offset(0, 10))
                  ],
                ),
                // The decorated container paints its own background, which
                // hides ListTile's ink/splash layer and made Flutter log
                // "ListTile background color or ink splashes may be invisible"
                // on every frame. A transparent Material gives the tiles a
                // proper ancestor to paint their ripples on, without changing
                // the dialog's appearance.
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('قائمة الساحة العامة',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 3),
                              Text(
                                  'الرسائل والطلبات والإشعارات والبلاغات لها أزرار ثابتة في الشريط العلوي.',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70)),
                      ],
                    ),
                    if (_isPlatformOwner) ...[
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF7E0BB8), Color(0xFFB04CE4)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Colors.white12,
                              child: Icon(Icons.add_home_work_rounded,
                                  color: Colors.white)),
                          title: const Text('إنشاء غرفة جديدة',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),

                          onTap: () {
                            Navigator.pop(dialogContext);
                            _openCreateRoom();
                          },
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 24),
                    ],
                    ListTile(
                        leading: const Icon(Icons.circle,
                            color: Colors.greenAccent, size: 14),
                        title: const Text('الحالة (متصل / مشغول / بعيد)',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openStatusPicker();
                        }),
                    ListTile(
                        leading: const Icon(Icons.groups_2_outlined,
                            color: Colors.white),
                        title: const Text('حائط المنتجات',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openFriendsWall();
                        }),
                    ListTile(
                        leading: const Icon(Icons.campaign_outlined,
                            color: Colors.white),
                        title: const Text('الإعلانات الممولة',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openSponsoredAds();
                        }),
                    ListTile(
                        leading: const Icon(Icons.refresh, color: Colors.white),
                        title: const Text('تحديث التطبيق / الصفحة',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _refreshLobby();
                        }),
                    ListTile(
                        leading: const Icon(Icons.search, color: Colors.white),
                        title: const Text('البحث',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openSearch();
                        }),
                    ListTile(
                        leading: const Icon(Icons.stars, color: Colors.white),
                        title: const Text('ملوك النقاط',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openPointsKings();
                        }),
                    ListTile(
                        leading: const Icon(Icons.diamond_outlined,
                            color: Colors.white),
                        title: const Text('ملوك الجواهر',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openGemsKings();
                        }),
                    ListTile(
                        leading: const Icon(Icons.workspace_premium,
                            color: Colors.white),
                        title: const Text('العرش الملكي للعضويات المدفوعة',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openRoyalThrone();
                        }),
                    ListTile(
                        leading: const Icon(Icons.bolt_outlined,
                            color: Colors.white),
                        title: const Text('الأعضاء النشطون الآن',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openActiveMembers();
                        }),
                    if (_canManageVisualSize)
                      ListTile(
                          leading: const Icon(Icons.straighten_rounded,
                              color: Colors.amberAccent),
                          title: const Text('حجم الإطار والسمايل (1–10)',
                              style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ChatFeatureSettingsPage()));
                          }),
                    ListTile(
                        leading: const Icon(Icons.shield_outlined,
                            color: Colors.white),
                        title: const Text('طاقم الإدارة',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openAdminTeam();
                        }),
                    ListTile(
                        leading: const Icon(Icons.support_agent,
                            color: Colors.white),
                        title: const Text('التواصل مع مدير المنصة DRAGON',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _contactDragonOwner();
                        }),
                    // الرسائل وطلبات الصداقة والإشعارات والبلاغات لها أزرار
                    // ثابتة في الشريط العلوي؛ لا نكررها داخل هذه القائمة.
                    const Divider(color: Colors.white24, height: 24),
                    ListTile(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: Colors.orangeAccent),
                        title: const Text('تحذيرات الأمان المنشورة',
                            style: TextStyle(color: Colors.white)),
                        subtitle: const Text(
                            'بلاغات تم اعتمادها ونشرها من الإدارة',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  const PlatformSafetyWarningsPage()));
                        }),
                    ListTile(
                        leading: const Icon(Icons.volume_up_outlined,
                            color: Colors.white),
                        title: const Text('أصوات وإشعارات الدردشة',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  const ChatNotificationSettingsPage()));
                        }),
                  ],
                ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(-0.06, -0.04), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  final VoidCallback onMenu;
  final VoidCallback onVip;
  final VoidCallback onPrinces;
  final VoidCallback onMessages;
  final VoidCallback onRequest;
  final VoidCallback onNotifications;
  final VoidCallback onReport;
  final VoidCallback onSettings;
  final VoidCallback onThemes;
  final VoidCallback onBroadcastSuggestion;
  final bool canManageBroadcast;
  final String? avatarUrl;

  const _TopBar({
    required this.onMenu,
    required this.onVip,
    required this.onPrinces,
    required this.onMessages,
    required this.onRequest,
    required this.onNotifications,
    required this.onReport,
    required this.onSettings,
    required this.onThemes,
    required this.onBroadcastSuggestion,
    required this.canManageBroadcast,
    required this.avatarUrl,
  });

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool legendary = false,
    Widget? iconChild,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.003)
                ..rotateX(-0.10)
                ..rotateY(0.045),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: legendary
                        ? const [
                            Color(0xFFFFF3A3),
                            Color(0xFFFFD45C),
                            Color(0xFF8A5A00)
                          ]
                        : const [Color(0xFF6E3B8F), Color(0xFF30153F)],
                  ),
                  border: Border.all(
                    color: legendary
                        ? const Color(0xAAFFE58A)
                        : Colors.white.withValues(alpha: .20),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: legendary
                          ? const Color(0x77FFD45C)
                          : Colors.black.withValues(alpha: .35),
                      blurRadius: legendary ? 14 : 8,
                      offset: const Offset(1.5, 2.5),
                    ),
                    const BoxShadow(
                      color: Colors.white24,
                      blurRadius: 2,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: iconChild ??
                    Icon(
                      icon,
                      color: legendary ? const Color(0xFF2B1400) : Colors.white,
                      size: 14,
                    ),
              ),
            ),
            const SizedBox(height: 0),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: legendary ? const Color(0xFFFFD45C) : Colors.white,
                fontSize: 6.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withBadge(Widget child, int count) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 1,
          right: 1,
          child: Container(
            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppNotificationEntity> notifications =
        ref.watch(notificationsProvider).valueOrNull ??
            const <AppNotificationEntity>[];
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ??
            notifications.where((n) => !n.isRead).length;
    // من المحادثات الخاصة نفسها، لا من الإشعارات (انظر unread_dm_provider).
    final messageCount = ref.watch(unreadDmCountProvider).valueOrNull ?? 0;
    final reportCount = notifications
        .where((n) => n.type == AppNotificationType.report && !n.isRead)
        .length;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final requestCount = uid == null
        ? 0
        : (ref.watch(pendingFriendRequestsProvider(uid)).valueOrNull?.length ??
            0);

    // الترتيب RTL: «ملفي» في الزاوية الأولى، والقائمة في الزاوية الثانية.
    // الأزرار المهمة تبقى مرئية دائماً ولا تُنقل إلى القائمة المنسدلة.
    final actions = <Widget>[
      _action(
        icon: Icons.person_rounded,
        label: 'ملفـي',
        onTap: onSettings,
        iconChild: avatarUrl == null || avatarUrl!.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
            : ClipOval(
                child: Image.network(
                  avatarUrl!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
      ),
      _withBadge(
        _action(icon: Icons.mail_rounded, label: 'رسالة', onTap: onMessages),
        messageCount,
      ),
      _withBadge(
        _action(
            icon: Icons.person_add_alt_1_rounded,
            label: 'طلبات',
            onTap: onRequest),
        requestCount,
      ),
      _withBadge(
        _action(
            icon: Icons.notifications_rounded,
            label: 'إشعارات',
            onTap: onNotifications),
        unreadNotifications,
      ),
      _action(
          icon: Icons.workspace_premium_rounded,
          label: 'العضويات',
          onTap: onVip,
          legendary: true),
      _action(
          icon: Icons.emoji_events_rounded,
          label: 'الأمراء',
          onTap: onPrinces,
          legendary: true),
      _withBadge(
        _action(icon: Icons.flag_rounded, label: 'ابلاغ', onTap: onReport),
        reportCount,
      ),
      if (canManageBroadcast)
        _action(
          icon: Icons.campaign_rounded,
          label: 'بث المنصة',
          onTap: onBroadcastSuggestion,
        ),
      _action(icon: Icons.menu_rounded, label: 'القائـمة', onTap: onMenu),
    ];

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: Container(
        width: double.infinity,
        height: 38,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFF4E0B78), Color(0xFF7E0BB8), Color(0xFF321042)],
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final actionWidth = width >= 900
                  ? 78.0
                  : width >= 650
                      ? 66.0
                      : 58.0;
              return Row(
                children: [
                  for (final action in actions)
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: actionWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: action,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}



class _ChatMessageRow extends ConsumerWidget {
  final Map<String, dynamic> row;
  final bool mine;
  final String mentionFrameColor;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyQuote;
  final ValueChanged<String>? onJumpToMessage;
  final VoidCallback? onNameTap;
  final ValueChanged<String>? onVideoTap;

  /// الضغط على سمايل متحرك في الفقاعة ينسخه إلى صندوق الإرسال.
  final ValueChanged<String>? onGifTap;
  final String? roomId;
  final int rankRevision;
  final bool isSystemBot;
  final int messageFrameIndex;
  final String? currentUid;

  const _ChatMessageRow({
    required this.row,
    required this.mine,
    this.mentionFrameColor = 'gold',
    this.onAvatarTap,
    this.onLongPress,
    this.onReplyQuote,
    this.onJumpToMessage,
    this.onNameTap,
    this.onVideoTap,
    this.onGifTap,
    this.roomId,
    this.rankRevision = 0,
    this.isSystemBot = false,
    this.messageFrameIndex = -1,
    this.currentUid,
  });

  static final RegExp _linkPattern = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|tiktok\.com)\/\S+$',
      caseSensitive: false);

  /// كان اللون هنا ثابتًا (0xFF1E293B) فيدهس لون الرسالة الذي يختاره
  /// العضو من المتجر ويحفظه الخادم في profiles.message_color — وهو سبب
  /// شكوى "ألوان كتابة الرسائل لم تظهر في الغرفة". صار يُمرَّر من
  /// build() بعد قراءته من هوية المُرسِل الخادمية.
  /// بطاقة الرسالة الأصلية كاملة (المرسل + المحتوى)، والضغط عليها يقفز
  /// لتلك الرسالة إن كانت محمَّلة ضمن الشاشة (نفس آلية _jumpToPublicMessage
  /// وonJumpToMessage الموجودتين أصلًا). replyToPreview مخزَّنة بصيغة
  /// "اسم المرسل|المحتوى" (انظر _sendMessage)؛ قيمة قديمة بلا الفاصل
  /// (من قبل هذا الإصلاح) تُعرض كمحتوى فقط بلا اسم.
  Widget? _replyQuoteCard() {
    final replyToId = row['reply_to_id']?.toString();
    if (replyToId == null || replyToId.isEmpty) return null;
    final raw = row['reply_to_preview']?.toString() ?? '';
    // صيغة قديمة محتملة (قبل إضافة رابط المصغّرة): جزءان فقط بلا كسر.
    final parts = raw.split('|');
    final senderName = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'عضو';
    final content = parts.length > 1 ? parts[1] : (parts.isNotEmpty ? parts[0] : '');
    final thumbUrl = parts.length > 2 ? parts[2] : '';
    final isQuote = row['metadata'] is Map &&
        ((row['metadata'] as Map)['reply_mode'] == 'quote' ||
            (row['metadata'] as Map)['reply_mode'] == 'quote_3d');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onJumpToMessage?.call(replyToId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(8),
          border: const Border(right: BorderSide(color: Color(0xFFFFD700), width: 2.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isQuote ? 'اقتباس من $senderName' : senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFFD700), fontSize: 11.5, fontWeight: FontWeight.w800)),
                  if (content.trim().isNotEmpty)
                    Text(content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            // السمايل/الصورة الأصلية تُعرض مصغَّرة فعلياً هنا، لا وصفاً
            // نصياً فقط — هذا بالضبط ما كان غائباً ("يظهر gif بدل ظهوره").
            if (thumbUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbUrl.startsWith('assets/')
                    ? Image.asset(thumbUrl, width: 28, height: 28, fit: BoxFit.contain)
                    : Image.network(thumbUrl, width: 28, height: 28, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content(double smileySize, Color textColor,
      {bool bold = false, bool italic = false, double scale = 1.0}) {
    final fw = bold ? FontWeight.w800 : FontWeight.w500;
    final fs = italic ? FontStyle.italic : FontStyle.normal;
    final sz = (14.0 * scale).clamp(11.0, 22.0);
    final body = (row['body'] ?? row['message'])?.toString() ?? '';
    final type = row['kind']?.toString() ?? 'text';
    final url = row['attachment_url']?.toString() ?? '';

    if (type == 'gif') {
      final banner = isMashareenaBannerGif(url);
      final gifW = banner ? 150.0 : 25.0;
      final gifH = banner ? 47.0 : 25.0;
      final image = url.startsWith('assets/')
          ? Image.asset(url, width: gifW, height: gifH, fit: BoxFit.contain)
          : Image.network(url, width: gifW, height: gifH, fit: BoxFit.contain, gaplessPlayback: true);
      final tile = SizedBox(width: gifW, height: gifH, child: image);
      if (onGifTap == null || url.isEmpty) return tile;
      // لقمة لمس 40×40 حول صورة 25×25 — نفس منطق الاختيار من القائمة،
      // فلا يبدو الضغط على فقاعة مرسَلة "لا يعمل" لضيق مساحته الفعلية.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onGifTap!(url),
        child: SizedBox(width: banner ? gifW : 40, height: banner ? gifH : 40, child: Center(child: tile)),
      );
    }
    if (type == 'image' && url.isNotEmpty) {
      // الضغط يفتح الصورة كاملة، وزر النقاط الثلاث في العارض يفتح قائمة الفقاعة.
      Widget buildImage(String u) => Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showFullscreenImage(context, u, onMore: onLongPress),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(u,
                    width: 220,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Text('تعذر تحميل الصورة', style: TextStyle(color: textColor))),
              ),
            ),
          );
      // mediaUrl قد يكون مسار تخزين خامًا (لا رابطًا جاهزًا) حين يأتي من
      // bucket خاص — chat-media-plus لمستخدمي VIP+ — فيحتاج توقيعًا عبر
      // جلسة القارئ الحالية قبل أي عرض فعلي؛ راجع التعليق على
      // _needsPrivateSigning أعلى الملف وSupabaseService.resolvePrivateMediaUrl.
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? buildImage(snap.data!)
              : const SizedBox(
                  width: 220,
                  height: 170,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
        );
      }
      return buildImage(url);
    }
    // كانت الرسائل الصوتية تُفتح خارج التطبيق عبر launchUrl تمامًا كالملفات
    // والفيديو — لا مشغّل داخلي إطلاقًا. صوت الغرفة الآن يُشغَّل من الفقاعة
    // نفسها حصرًا؛ الفيديو والملف يبقيان بفتح خارجي كما كانا.
    if (type == 'audio' && url.isNotEmpty) {
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? VoiceMessagePlayer(url: snap.data!)
              : const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
        );
      }
      return VoiceMessagePlayer(url: url);
    }
    if ((type == 'video' || type == 'file') && url.isNotEmpty) {
      final icon = type == 'video' ? Icons.play_circle_fill : Icons.insert_drive_file;
      Widget buildOpenRow(String u) => InkWell(
            onTap: () async {
              await safeLaunch(u);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFF7D32A6), size: 30),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(body.isEmpty ? 'مرفق' : body,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, size: 16),
            ]),
          );
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? buildOpenRow(snap.data!)
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return buildOpenRow(url);
    }
    // اليوتيوب/تيك توك: إن كان جسم الرسالة رابطًا خامًا من هاتين
    // المنصتين، يُضمَّن مباشرة عبر EmbeddedMediaPlayer (يوتيوب فعليًا
    // داخل التطبيق، وتيك توك ببطاقة فتح خارجي أنيقة) بدل عرضه كنص.
    final trimmedBody = body.trim();
    if (type == 'text' && _linkPattern.hasMatch(trimmedBody)) {
      final normalized =
          trimmedBody.startsWith('http') ? trimmedBody : 'https://$trimmedBody';
      // يوتيوب: البطاقة نفسها (EmbeddedMediaPlayer مع routeYoutubeToFloating
      // Player) تملك ضغطتها الخاصة لتشغيل المشغّل العائم مباشرة — لا حاجة
      // لـonVideoTap هنا، وتفعيله أيضًا كان سيفتح "مشغل الوسائط" الذي
      // يُضمِّن الفيديو من جديد داخل الغرفة، فيناقض "حصرًا بمشغل عائم".
      // تيك توك يبقى بسلوكه القديم (فتح مشغل الوسائط) لأنه غير مطلوب تغييره.
      final isYoutubeLink = Uri.tryParse(normalized)?.host.toLowerCase().contains('youtu') ?? false;
      return InkWell(
        onTap: (onVideoTap == null || isYoutubeLink)
            ? null
            : () => onVideoTap!(normalized),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            width: 240,
            // يوتيوب يُشغَّل حصرًا عبر المشغّل العائم العام لا تضمينًا داخل
            // الفقاعة — تيك توك يبقى كما هو.
            child: EmbeddedMediaPlayer(
                url: normalized, routeYoutubeToFloatingPlayer: true)),
      );
    }
    final metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : const <String, dynamic>{};
    final mentionedIds = metadata['mention_user_ids'] is List
        ? (metadata['mention_user_ids'] as List<dynamic>)
            .map((e) => e.toString())
            .toSet()
        : const <String>{};
    final showMentionBadge = currentUid != null &&
        currentUid!.isNotEmpty && mentionedIds.contains(currentUid);

    return _MentionRichText(
      text: body.isEmpty ? 'رسالة فارغة' : body,
      baseColor: textColor,
      fontWeight: fw,
      fontStyle: fs,
      fontSize: sz.toDouble(),
      showMentionBadge: showMentionBadge,
      mentionNames: (metadata['mention_user_names'] is List)
          ? (metadata['mention_user_names'] as List<dynamic>)
              .map<String>((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet()
          : const <String>{},
    );
  }


  Widget _systemBotIdentity() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Icon(Icons.smart_toy_rounded, size: 15, color: Color(0xFFB25CFF)),
        SizedBox(width: 4),
        Text(
          'بوت الترحيب',
          style: TextStyle(
            color: Color(0xFFB25CFF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 3),
        Text(':', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualSize = isSystemBot || row['user_id']?.toString().trim().isEmpty != false
        ? null
        : ref.watch(chatVisualSizeProvider(row['user_id'].toString())).valueOrNull;
    final smileySize = visualSize?.smileySize ?? 18.0;

    // لون نص الرسالة = ما اختاره المُرسِل نفسه في المتجر، لا لونًا
    // ثابتًا. الخادم يعيده عبر get_user_chat_identity بمفتاحين:
    // message_color_1 (hex من كتالوج الألوان، وهو ما تكتبه
    // set_my_message_color فعليًا) وmessage_color (bigint قديم).
    // 4294967295 = أبيض افتراضي أي "بلا اختيار" فيُترك اللون الأساسي.
    final senderUid = row['user_id']?.toString().trim() ?? '';
    Color messageTextColor = const Color(0xFF1E293B);
    // تنسيق الخط الذي اختاره المُرسِل (غامق/مائل/حجم) — يُحفظ على
    // profiles ويصل مع اللون في نداء الهوية نفسه.
    bool msgBold = false;
    bool msgItalic = false;
    double msgScale = 1.0;
    if (!isSystemBot && senderUid.isNotEmpty) {
      final identity = (roomId == null || roomId!.isEmpty)
          ? ref.watch(serverUserIdentityProvider(senderUid)).valueOrNull
          : ref
              .watch(serverUserIdentityInRoomProvider(
                  (uid: senderUid, roomId: roomId!)))
              .valueOrNull;
      if (identity != null) {
        final hex = (identity['message_color_1'] ?? '')
            .toString()
            .replaceAll('#', '')
            .trim();
        final legacy =
            int.tryParse(identity['message_color']?.toString() ?? '');
        if (hex.length == 6) {
          final n = int.tryParse('FF$hex', radix: 16);
          if (n != null) messageTextColor = Color(n);
        } else if (legacy != null && legacy != 4294967295) {
          messageTextColor = Color(legacy);
        }
        msgBold = identity['message_bold'] == true;
        msgItalic = identity['message_italic'] == true;
        msgScale = double.tryParse(
                identity['message_font_scale']?.toString() ?? '') ??
            1.0;
      }
    }
    // Username size is profile-owned and rendered at its exact server value.
    // The frame/smiley visual-size control must not distort the user's name.
    final displayName = row['display_name']?.toString().trim();
    final username = row['username']?.toString().trim();
    final avatarName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : ((username != null && username.isNotEmpty) ? username : 'عضو');
    final chatDisplayName = avatarName;

    final identity = isSystemBot
        ? _systemBotIdentity()
        : _ChatIdentityHeader(
            uid: row['user_id']?.toString(),
            roomId: roomId,
            fallbackName: chatDisplayName,
            revision: rankRevision,
            onTap: onNameTap,
            sizeMultiplier: 1.0,
            anonymous: row['metadata'] is Map &&
                (row['metadata'] as Map)['anonymous_chat'] == true,
          );

    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final timeText = createdAt == null
        ? ''
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    // أفاتار البوت كان 58×58 بينما أفاتار العضو 50×50، فيبدو أضخم
    // من الجميع ويكسر انتظام الصف. صار 42 — أصغر من أفاتار العضو
    // لأنه رسالة نظام لا مشارِكًا.
    final baseAvatar = isSystemBot
        ? Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2A173A),
              boxShadow: [BoxShadow(color: Color(0x663B1E55), blurRadius: 7)],
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Color(0xFFB25CFF), size: 21),
          )
        : _VideoStyleAvatar(
            url: row['avatar_url']?.toString(),
            rowUid: row['user_id']?.toString(),
            name: avatarName,
            roomId: roomId,
            frameKey: row['metadata'] is Map
                ? (row['metadata'] as Map)['avatar_frame_key']?.toString()
                : null,
            below: (row['user_id']?.toString().trim().isNotEmpty == true)
                ? IgnorePointer(
                    child: ServerRoleBadgeUnderAvatar(
                      uid: row['user_id'].toString(),
                      roomId: roomId,
                    ),
                  )
                : null,
          );

    // شارة الرتبة/السلطة (مالك المنصة، سوبر أدمن، الرتب المهنية...)
    // كانت تُرسم بجانب الاسم داخل ServerUsernameDisplay — نُقلت تحت
    // الأفاتار كما طُلب.
    //
    // أول محاولة استعملت Positioned بإزاحات سالبة (bottom:-8, left/
    // right:-6) داخل الـStack، فظهرت الشارة بعيدة عن الأفاتار فعليًا:
    // Positioned بـleft وright معًا يتمدّد ليملأ عرض صندوق الـStack
    // كاملًا لا عرض الأفاتار نفسه، وأي اختلاف بسيط في حجم الصندوق
    // (من الإطارات المتحركة، توسّع الخط...) يُبعد المركز الفعلي عن
    // مركز الأفاتار المرئي. Column بترتيب طبيعي (لا تمركز حسابي ولا
    // إزاحات سالبة) يضمن التصاقها مباشرة بلا أي احتمال انحراف.
    final avatarWithBadges = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isSystemBot || row['user_id']?.toString().trim().isEmpty != false)
          baseAvatar
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              baseAvatar,
              Positioned(
                right: -3,
                top: -4,
                child: IgnorePointer(
                  child: ServerRankBadge(
                    uid: row['user_id'].toString(),
                    diameter: 20,
                  ),
                ),
              ),
            ],
          ),
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Username/identity is deliberately OUTSIDE ChatMessageFrame.
                    //
                    // DefaultTextStyle.merge كان يفرض هنا لونًا كحليًا
                    // ثابتًا (#152033) على أي Text بلا style صريح تحته —
                    // وServerUsernameDisplay بالضبط هو ذلك النص: يرث اللون
                    // المفروض فتُدهَس ألوان المؤثرات والقوالب كلها قبل أن
                    // تصل الشاشة. هذا هو سبب "الاسم يظهر أبيض/كحلي عاديًا"
                    // رغم صحة كل حلقة في السلسلة الخادمية — الودجت الصحيح
                    // كان يُبنى وسط شجرة تفرض عليه لونًا لا يملك حق رفضه.
                    // إزالة اللون من DefaultTextStyle تكفي: كل نص فرعي لم
                    // يعد يُجبَر على الكحلي، بينما الحجم والوزن يبقيان
                    // كافتراض يستطيع أي نص فرعي تجاوزه.
                    SizedBox(
                      width: double.infinity,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: DefaultTextStyle.merge(
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            child: identity,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // The panel grows with the message and is capped for comfortable
                    // reading on both mobile and web.
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .82,
                        ),
                        child: ChatMessageFrame(
                          silver: messageFrameIndex.isOdd,
                          child: Directionality(
                            textDirection: _chatMessageDirection(
                              row['body']?.toString() ?? '',
                            ),
                            // كان الوقت يُرسم فوق النص داخل Stack بافتراض أن
                            // الزاوية السفلية اليسرى للفقاعة تبقى فارغة
                            // دائمًا — وينكسر هذا الافتراض كلما وصل آخر سطر
                            // من الرسالة إلى تلك الزاوية فعلًا (رسالة قصيرة،
                            // أو عربية تنتهي يسارًا)، فيتراكب الوقت على
                            // النص كما في صورتك. Column يضع الوقت دائمًا
                            // بعد النص في تدفّق طبيعي — نفس الترتيب ونفس
                            // الزاوية، بلا أي احتمال تراكب. المحاذاتان
                            // (يمين للنص، يسار للوقت) مطلقتان كما كانتا في
                            // الأصل (Alignment لا AlignmentDirectional) حتى
                            // لا ينعكس الترتيب مع رسائل الاتجاه المختلف
                            // (الأصل استعمل Positioned(left:0) أي يسار
                            // فعلي بصرف النظر عن اتجاه هذا الـDirectionality).
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // بطاقة الاقتباس/الرد: البيانات كانت تُلتقَط
                                // عند الإرسال (reply_to_id/preview) وtamam
                                // _jumpToPublicMessage جاهزة ومُمرَّرة أصلًا
                                // عبر onJumpToMessage — لكن build() هنا لم
                                // يكن يرسم منها أي بطاقة إطلاقًا، فتصل
                                // البيانات وتُفقَد بصمت. هذا هو العطل الذي
                                // وصفته الوثيقة بالضبط.
                                if (_replyQuoteCard() case final card?)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: SizedBox(width: double.infinity, child: card),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _content(smileySize, messageTextColor,
                                        bold: msgBold,
                                        italic: msgItalic,
                                        scale: msgScale),
                                  ),
                                ),
                                if (timeText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        timeText,
                                        textAlign: TextAlign.left,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          color: Color(0xFF6F7783),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                  // النقاط الثلاث: رد، اقتباس، مشاركة، حذف (نفس قائمة الضغط المطوّل).
                  if (onLongPress != null)
                    Positioned(
                      left: 2,
                      top: 0,
                      child: GestureDetector(
                        onTap: onLongPress,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar + rank are deliberately outside ChatMessageFrame and remain
          // on the right side of the message row. Kept as a plain child:
          // wrapping it in SizedBox/OverflowBox to fine-tune vertical
          // alignment gave it an unbounded width inside the Row and broke the
          // whole message layout, so alignment stays with crossAxisAlignment.
          GestureDetector(
            onTap: isSystemBot ? null : onAvatarTap,
            child: avatarWithBadges,
          ),
          ],
        ),
      ),
    );
  }

}

class _ChatIdentityHeader extends StatelessWidget {
  final String? uid;
  final String? roomId;
  final String fallbackName;
  final int revision;
  final VoidCallback? onTap;
  final bool anonymous;
  final double sizeMultiplier;

  const _ChatIdentityHeader({
    this.uid,
    this.roomId,
    required this.fallbackName,
    this.revision = 0,
    this.onTap,
    this.anonymous = false,
    this.sizeMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (anonymous || uid == null || uid!.trim().isEmpty) {
      return Text(
        '${anonymous ? 'عضو مجهول' : fallbackName} :',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      );
    }

    // revision is deliberately kept in the widget API because chat lobby
    // invalidates/rebuilds identity after profile changes.
    final _ = revision;

    final username = ServerUsernameDisplay(
      uid: uid!,
      roomId: roomId,
      fallbackName: fallbackName,
      fallbackFontSize: 11,
      showTitle: true,
      showBadges: true,
      showAchievements: false,
      sizeMultiplier: sizeMultiplier,
      badgesBeforeName: false,
      // Status is intentionally profile-only; public rooms must not show it.
      showStatus: false,
      onNameTap: onTap,
      // شارة الرتبة تُرسَم الآن تحت الأفاتار (ServerRoleBadgeUnderAvatar
      // في _avatar أعلاه)، فتُعطَّل هنا لمنع ازدواجها بجانب الاسم.
      hideRoleBadge: true,
    );

    return username;
  }
}

class _GlobalEventOverlay extends StatefulWidget {
  final Map<String, dynamic> event;
  const _GlobalEventOverlay({super.key, required this.event});
  @override
  State<_GlobalEventOverlay> createState() => _GlobalEventOverlayState();
}

class _GlobalEventOverlayState extends State<_GlobalEventOverlay> {
  Timer? _hideTimer;
  bool _visible = true;

  /// أصوات الدخول الملكي محفوظة في الخادم (royal_<effect>) وليست في المشروع.
  String _effectSoundKey(String effect) {
    const allowed = <String>{
      'lion_fire',
      'lion_gold',
      'dragon_fire',
      'crown_light',
      'phoenix_flame',
      'thunder_crown',
      'ice_dragon',
      'diamond_storm',
      'cosmic_gate',
      'golden_rain',
    };
    return allowed.contains(effect) ? 'royal_$effect' : 'royal_lion_fire';
  }

  @override
  void initState() {
    super.initState();
    final effect = widget.event['event_type']?.toString() == 'owner_entry'
        ? ((widget.event['payload'] is Map)
            ? (widget.event['payload'] as Map)['effect']?.toString()
            : null)
        : null;
    if (effect != null) {
      unawaited(ServerSounds.instance.play(_effectSoundKey(effect), volume: 1.0));
    }
    final expires = DateTime.tryParse(widget.event['expires_at']?.toString() ?? '');
    if (expires != null) {
      final delay = expires.difference(DateTime.now());
      _hideTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final type = widget.event['event_type']?.toString() ?? '';
    final payload = widget.event['payload'] is Map
        ? Map<String, dynamic>.from(widget.event['payload'] as Map)
        : const <String, dynamic>{};
    final actor = (payload['from_name'] ?? payload['actor_name'])?.toString().trim();
    final actorLabel = (actor == null || actor.isEmpty) ? 'عضو' : actor;
    final actorEffect = UsernameEffectX.fromWire(payload['username_effect']?.toString());
    final actorTemplateKey = payload['username_template_key']?.toString();
    final actorFontSize = ((payload['username_font_size'] as num?)?.toDouble() ?? 12.0)
        .clamp(8.0, 26.0)
        .toDouble();
    final actorBackgroundMode = payload['username_background_mode']?.toString();
    final actorBackgroundColor1 = payload['username_background_color1']?.toString();
    final actorBackgroundColor2 = payload['username_background_color2']?.toString();
    final actorBackgroundOpacity = ((payload['username_background_opacity'] as num?)?.toDouble() ?? .82).clamp(0.0, 1.0).toDouble();
    final actorBackgroundExternal = payload['username_background_external_effect']?.toString();
    final welcomeName = (payload['target_username'] ?? payload['actor_name'] ?? payload['from_name'])?.toString().trim();
    final rawWelcome = payload['message']?.toString().trim();
    final welcomeText = (rawWelcome == null || rawWelcome.isEmpty)
        ? 'أهلًا وسهلًا${welcomeName == null || welcomeName.isEmpty ? '' : ' يا $welcomeName'}، نورت الشات ونتمنى لك وقتًا جميلًا معنا'
        : (rawWelcome.contains(welcomeName ?? '') || welcomeName == null || welcomeName.isEmpty
            ? rawWelcome
            : 'أهلًا وسهلًا يا $welcomeName، $rawWelcome');
    final text = switch (type) {
      'welcome_bot' => welcomeText,
      'owner_entry' => '👑 ${payload['actor_name'] ?? payload['from_name'] ?? 'المالك'} دخل الغرفة',
      'gift' => '🎁 $actorLabel أهدى ${payload['gift_name'] ?? 'هدية'} ${payload['emoji'] ?? '🎁'}',
      'points_transfer' => '⭐ $actorLabel حوّل ${payload['amount'] ?? 0} نقطة إلى ${(payload['to_name'] ?? 'عضو')}',
      'gems_transfer' => '💎 $actorLabel حوّل ${payload['amount'] ?? 0} جوهرة إلى ${(payload['to_name'] ?? 'عضو')}',
      'platform_idea_suggestion' => '💡 اقتراح للمنصة',
      'platform_live_suggestion' => '🔴 اقتراح بث مباشر',
      'user_joined' => '✨ $actorLabel انضم إلى الغرفة',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    final imageUrl = (payload['image_url'] ?? payload['avatar_url'])?.toString();
    final isWelcome = type == 'welcome_bot';
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final cardWidth = math.min(420.0, math.max(0.0, availableWidth - 24.0));
          final cardMaxHeight = math.min(420.0, math.max(140.0, availableHeight * 0.62));
          final imageWidth = math.min(170.0, math.max(90.0, cardWidth * 0.46));

          Widget welcomeImage() {
            if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
            final image = imageUrl.startsWith('asset://')
                ? Image.asset(
                    imageUrl.substring('asset://'.length),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  );
            return SizedBox(
              width: imageWidth,
              child: AspectRatio(aspectRatio: 480 / 854, child: image),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cardWidth,
                maxHeight: cardMaxHeight,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xE62A0E42),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isWelcome ? const Color(0xFFFFD45C) : const Color(0xFFB85CFF),
                  ),
                  boxShadow: isWelcome
                      ? const [BoxShadow(color: Colors.black54, blurRadius: 18)]
                      : null,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWelcome)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: welcomeImage(),
                        ),
                      if (!isWelcome && imageUrl != null && imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            imageUrl,
                            width: math.min(140.0, cardWidth * 0.4),
                            height: math.min(95.0, cardWidth * 0.27),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      if (isWelcome || (imageUrl != null && imageUrl.isNotEmpty))
                        const SizedBox(height: 8),
                      if (isWelcome)
                        RichText(
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: cardWidth < 300 ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(text: 'أهلًا وسهلًا يـ '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: actorTemplateKey != null && actorTemplateKey.trim().isNotEmpty
                                    ? UsernameCosmeticName(
                                        name: (welcomeName == null || welcomeName.isEmpty) ? actorLabel : welcomeName,
                                        effect: actorEffect,
                                        fontSize: actorFontSize,
                                        backgroundMode: actorBackgroundMode,
                                        backgroundColor1: actorBackgroundColor1,
                                        backgroundColor2: actorBackgroundColor2,
                                        backgroundOpacity: actorBackgroundOpacity,
                                        externalEffect: actorBackgroundExternal,
                                        templateKey: actorTemplateKey,
                                      )
                                    : UsernameCosmeticName(
                                        name: (welcomeName == null || welcomeName.isEmpty) ? actorLabel : welcomeName,
                                        effect: actorEffect,
                                        fontSize: actorFontSize,
                                        backgroundMode: actorBackgroundMode,
                                        backgroundColor1: actorBackgroundColor1,
                                        backgroundColor2: actorBackgroundColor2,
                                        backgroundOpacity: actorBackgroundOpacity,
                                        externalEffect: actorBackgroundExternal,
                                      ),
                              ),
                              const TextSpan(text: '، نورت الشات ونتمنى لك وقتًا جميلًا معنا'),
                            ],
                          ),
                        )
                      else
                        LocalGlyphText(
                          text,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// إعلان هدية داخل الغرفة. النص والرمز يأتيان كلاهما من الخادم حصرًا
/// (public_chat_messages.metadata التي يكتبها send_gift_atomic من كتالوج
/// الهدايا) — لا قائمة رموز محلية إطلاقًا، فأي هدية يضيفها المالك للكتالوج
/// تظهر برمزها الصحيح تلقائيًا بلا أي تعديل في التطبيق.
class _GiftAnnouncementRow extends StatelessWidget {
  final String message;
  final String emoji;
  final String? imageUrl;
  const _GiftAnnouncementRow({
    required this.message,
    required this.emoji,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              const Color(0xFFD4AF37).withValues(alpha: .22),
              const Color(0xFF7A1F3D).withValues(alpha: .22),
            ]),
            border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: .45), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              // صورة الهدية الحقيقية إن وُجدت، وإلا الإيموجي الخاص بها.
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF5F1E8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalChatEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _GlobalChatEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return _GlobalEventOverlay(event: event);
  }
}

TextDirection _chatMessageDirection(String value) {
  final arabic = RegExp(r'[\u0600-\u06FF]');
  final latin = RegExp(r'[A-Za-z]');
  final arabicMatch = arabic.firstMatch(value);
  final latinMatch = latin.firstMatch(value);

  if (arabicMatch == null && latinMatch == null) {
    return TextDirection.rtl;
  }
  if (arabicMatch == null) return TextDirection.ltr;
  if (latinMatch == null) return TextDirection.rtl;

  return arabicMatch.start < latinMatch.start
      ? TextDirection.rtl
      : TextDirection.ltr;
}

class _MentionRichText extends StatelessWidget {
  final String text;
  final Color baseColor;
  final Set<String> mentionNames;
  final bool showMentionBadge;

  /// تنسيق الخط الذي اختاره المُرسِل. كان الحجم والوزن مثبّتين
  /// (15 / w600) فيتجاهلان اختيار العضو تمامًا.
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final double fontSize;

  const _MentionRichText({
    this.fontWeight = FontWeight.w600,
    this.fontStyle = FontStyle.normal,
    this.fontSize = 15,
    required this.text,
    required this.baseColor,
    this.mentionNames = const <String>{},
    this.showMentionBadge = false,
  });

  static final RegExp _wordChar = RegExp(r'[\w\u0600-\u06FF._-]');

  bool _isWordChar(String value) => _wordChar.hasMatch(value);

  bool _boundaryBefore(String source, int index) {
    if (index <= 0) return true;
    final previous = source.substring(index - 1, index);
    return previous == '@' || !_isWordChar(previous);
  }

  bool _boundaryAfter(String source, int index) {
    if (index >= source.length) return true;
    return !_isWordChar(source.substring(index, index + 1));
  }

  List<_MentionRange> _findMentionRanges() {
    final names = mentionNames
        .map((name) => name.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final ranges = <_MentionRange>[];
    final occupied = <int>{};

    void addRange(int start, int end, String display) {
      for (var i = start; i < end; i++) {
        if (occupied.contains(i)) return;
      }
      for (var i = start; i < end; i++) {
        occupied.add(i);
      }
      ranges.add(_MentionRange(start: start, end: end, display: display));
    }

    if (names.isEmpty) {
      final legacy = RegExp(r'@[\w\u0600-\u06FF._-]+');
      for (final match in legacy.allMatches(text)) {
        final raw = text.substring(match.start, match.end);
        final display = raw.substring(1);
        if (display.isNotEmpty) addRange(match.start, match.end, display);
      }
    } else {
      // New messages deliberately store the visible text without `@`. The
      // mention target is carried in metadata, so match both forms here.
      for (final name in names) {
        var searchFrom = 0;
        final lowerText = text.toLowerCase();
        final lowerName = name.toLowerCase();
        while (searchFrom < lowerText.length) {
          final index = lowerText.indexOf(lowerName, searchFrom);
          if (index < 0) break;
          final nameEnd = index + name.length;
          final hasAt = index > 0 && text[index - 1] == '@';
          final start = hasAt ? index - 1 : index;
          if ((hasAt || _boundaryBefore(text, index)) && _boundaryAfter(text, nameEnd)) {
            addRange(start, nameEnd, name);
          }
          searchFrom = nameEnd;
        }
      }
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _findMentionRanges();
    if (matches.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: _chatMessageDirection(text),
        softWrap: true,
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: 1.4,
        ),
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      // كان غير المُنشَن يرى المنشن بلا أي تمييز بصري — نفس لون
      // الرسالة العادي بالضبط — فيبدو "المنشن لا يعمل" رغم أن
      // المطابقة والبيانات كلاهما سليم. الشارة الكاملة تبقى محجوزة
      // لصاحب المنشن وحده (تنبيه شخصي)، لكن الجميع الآن يرى الاسم
      // بلون مميَّز وخلفية خفيفة فيُدرَك أنه إشارة لا نص عادي.
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: showMentionBadge
              ? ChatMentionBadge(name: match.display, fontSize: 13)
              // الإطار الأزرق يظهر حصرًا للعضو الذي أُشير إليه (showMentionBadge
              // = هو المُنشَن). بقية الأعضاء يرون الاسم نصًّا عاديًا بلون الرسالة.
              : Text(
                  text.substring(match.start, match.end),
                  style: TextStyle(
                    color: baseColor,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    fontStyle: fontStyle,
                    height: 1.4,
                  ),
                ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    final direction = _chatMessageDirection(text);
    return RichText(
      textAlign: TextAlign.right,
      textDirection: direction,
      softWrap: true,
      text: TextSpan(
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}

class _MentionRange {
  final int start;
  final int end;
  final String display;

  const _MentionRange({
    required this.start,
    required this.end,
    required this.display,
  });
}


String? _normalizeProfileAvatarUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final segments = [...uri.pathSegments];
  final marker = segments.indexOf('public');
  if (marker >= 0 && marker + 3 < segments.length &&
      segments[marker + 1] == 'profile-avatars' &&
      segments[marker + 2] == 'profile-avatars') {
    final fixed = [
      ...segments.sublist(0, marker + 2),
      ...segments.sublist(marker + 3),
    ];
    return uri.replace(pathSegments: fixed).toString();
  }
  return raw;
}

class _VideoStyleAvatar extends ConsumerWidget {
  final String? url;
  final String name;
  final String? rowUid;
  final String? frameKey;
  final String? roomId;

  /// عنصر يُرسم مباشرة أسفل الإطار (شارة الرتبة/السلطة). يوضع داخل نفس
  /// Transform.translate الذي يرفع الأفاتار، فيتحرّك معه ويلتصق به.
  /// خارج التحويل كان يُوضع تحت صندوق التخطيط الأصلي (قبل الرفع) فيظهر
  /// فراغ بمقدار الرفع (~0.45 من القطر) بين الصورة والشارة.
  final Widget? below;
  const _VideoStyleAvatar({
    this.url,
    required this.name,
    this.rowUid,
    this.frameKey,
    this.roomId,
    this.below,
  });

  Widget _withBelow(Widget framed) => below == null
      ? framed
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [framed, below!],
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = rowUid == null
        ? const AsyncValue<ProfileEntity?>.data(null)
        : ref.watch(profileByIdProvider(rowUid!));
    final serverIdentity = rowUid == null
        ? const AsyncValue<Map<String, dynamic>>.data({})
        : (roomId == null
            ? ref.watch(serverUserIdentityProvider(rowUid!))
            : ref.watch(serverUserIdentityInRoomProvider((uid: rowUid!, roomId: roomId))));

    final identity = serverIdentity.valueOrNull ?? const <String, dynamic>{};
    final serverAvatar = identity['avatar_url']?.toString();
    final serverAnimatedAvatar = identity['animated_avatar_url']?.toString();
    final serverFrame = identity['avatar_frame_key']?.toString();
    // Prefer the persisted normal avatar. The upload flow clears the animated
    // avatar when a new normal photo is saved, preventing stale GIF display.
    final imageUrl = _normalizeProfileAvatarUrl(
      (serverAvatar != null && serverAvatar.isNotEmpty)
          ? serverAvatar
          : (serverAnimatedAvatar != null && serverAnimatedAvatar.isNotEmpty)
              ? serverAnimatedAvatar
              : (url ?? profile.valueOrNull?.avatarUrl ?? profile.valueOrNull?.animatedAvatarUrl),
    );
    final effectiveFrameKey = (serverFrame != null && serverFrame.isNotEmpty)
        ? serverFrame
        : (frameKey != null && frameKey!.trim().isNotEmpty)
            ? frameKey
            : profile.valueOrNull?.avatarFrameKey;

    final visualSize = rowUid == null
        ? null
        : ref.watch(chatVisualSizeProvider(rowUid!)).valueOrNull;
    final avatarDiameter = visualSize?.avatarDiameter ?? 50.0;
    final avatarRadius = avatarDiameter / 2;
    final avatarFrameScale = visualSize?.frameScale ?? DynamicAvatarFrame.frameScaleForLevel(5);

    final avatar = SizedBox(
      width: avatarDiameter,
      height: avatarDiameter,
      child: ClipOval(
        child: imageUrl == null || imageUrl.isEmpty
            ? Container(
                color: const Color(0xFFEEE7F4),
                child: const Icon(Icons.person, color: Color(0xFF6D5A78)),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEEE7F4),
                  child: const Icon(Icons.person, color: Color(0xFF6D5A78)),
                ),
              ),
      ),
    );

    // Vertical alignment with the name row.
    //
    // The decorative frame artwork is considerably taller than the avatar
    // circle itself, so with the row's top alignment the visible circle ends
    // up sitting well below the name. Transform.translate is used rather than
    // SizedBox/OverflowBox because it shifts only the PAINTED result and
    // touches no constraints at all — an earlier OverflowBox attempt inherited
    // an unbounded width inside the Row and broke the entire message layout.
    //
    // TUNING: raise or lower this single factor if the circle still looks off
    // (larger value = avatar moves further up).
    const avatarVerticalLiftFactor = 0.45;

    // Colored ("simple") frames are drawn procedurally by StoreAvatarFrame,
    // not from a catalog image, so they cannot go through DynamicAvatarFrame.
    // The equipped id now arrives inside the chat identity payload (resolved
    // server-side, so OTHER members' colored frames render too), and the
    // colours are looked up from the shared store catalog by sku.
    // A normal avatar frame WINS over a colored one.
    //
    // Previously the colored branch ran first, so an old equipped colored
    // frame permanently hijacked the avatar and every normal frame silently
    // did nothing — it saved correctly on the server but never rendered.
    // The two are alternatives, so the explicitly-set avatar_frame_key takes
    // precedence and the colored frame only applies when no normal frame is set.
    final coloredFrameId = (effectiveFrameKey == null || effectiveFrameKey.isEmpty)
        ? (identity['colored_frame_id']?.toString().trim() ?? '')
        : '';
    if (coloredFrameId.isNotEmpty) {
      final catalog =
          ref.watch(storeCatalogProvider).valueOrNull ?? const <StoreItemEntity>[];
      StoreItemEntity? coloredItem;
      for (final it in catalog) {
        if (it.sku.toLowerCase() == coloredFrameId.toLowerCase()) {
          coloredItem = it;
          break;
        }
      }
      if (coloredItem != null && coloredItem.colors.isNotEmpty) {
        return Transform.translate(
          offset: Offset(0, -avatarDiameter * avatarVerticalLiftFactor),
          child: _withBelow(StoreAvatarFrame(
            colors: coloredItem.colors,
            padding: 3,
            child: avatar,
          )),
        );
      }
    }

    return Transform.translate(
      offset: Offset(0, -avatarDiameter * avatarVerticalLiftFactor),
      child: _withBelow(DynamicAvatarFrame(
        frameKey: effectiveFrameKey,
        radius: avatarRadius,
        frameScale: avatarFrameScale,
        userId: rowUid,
        child: avatar,
      )),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BottomItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStyleBottomBar extends StatelessWidget {
  final bool showOptions;
  final VoidCallback onOptions;
  final VoidCallback onRooms;
  final VoidCallback onOnline;
  final VoidCallback onFriends;
  final VoidCallback onChatStore;
  final VoidCallback? onMedia;
  final bool showMediaPlay;

  const _VideoStyleBottomBar({
    required this.showOptions,
    required this.onOptions,
    required this.onRooms,
    required this.onOnline,
    required this.onFriends,
    required this.onChatStore,
    required this.onMedia,
    this.showMediaPlay = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E0BB8), Color(0xFF4E0B78)],
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (final item
                  in <({IconData icon, String label, VoidCallback onTap})>[
                if (showMediaPlay && onMedia != null)
                  (icon: Icons.play_circle_fill, label: 'تشغيل', onTap: onMedia!),
                (icon: Icons.meeting_room_outlined, label: 'الغرف', onTap: onRooms),
                (icon: Icons.people_outline, label: 'المتصلون', onTap: onOnline),
                (icon: Icons.person_add, label: 'الأصدقاء', onTap: onFriends),
                (icon: Icons.storefront_outlined, label: 'المتجر', onTap: onChatStore),
                if (showOptions)
                  (
                    icon: Icons.settings_rounded,
                    label: 'الخيارات',
                    onTap: onOptions
                  ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    width: 76,
                    child: InkWell(
                      onTap: item.onTap,
                      child: _BottomItem(item.icon, item.label),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onSticker;
  final Future<void> Function(String url) onVoice;
  final VoidCallback onSend;
  final Color? textColor;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onSticker,
    required this.onVoice,
    required this.onSend,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget actionButton({
      required IconData icon,
      required VoidCallback onPressed,
      String? tooltip,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: sending ? null : onPressed,
        splashRadius: 22,
        icon: Icon(icon, size: 21),
        color: p.accentBright,
        disabledColor: p.textMuted,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .98),
        border: Border(
          top: BorderSide(color: p.divider.withValues(alpha: .75)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accent, p.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: .22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'إرسال',
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded, size: 21),
              color: p.background,
              disabledColor: p.background.withValues(alpha: .5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 138),
              decoration: BoxDecoration(
                color: p.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.divider.withValues(alpha: .9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 9,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final direction = _chatMessageDirection(value.text);
                  return Directionality(
                    textDirection: direction,
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textAlign: direction == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      textDirection: direction,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: p.accentBright,
                      style: TextStyle(
                      color: textColor ?? p.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: direction == TextDirection.rtl
                          ? 'اكتب رسالتك…'
                          : 'Write a message…',
                      hintStyle: TextStyle(
                        color: p.textMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        10,
                        14,
                        10,
                      ),
                    ),
                      onSubmitted: (_) => onSend(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 2),
          // السمايل: إيموجي ثابتة + GIF متحركة معًا بتبويبين ضمن قسم واحد
          // (بدل زرين/ورقتين منفصلتين).
          actionButton(
            icon: Icons.emoji_emotions_outlined,
            onPressed: onSticker,
            tooltip: 'السمايلات',
          ),
          // أيقونة المشغّل المصغَّر (تظهر فقط حين تُصغَّر نافذة اليوتيوب).
          const MiniPlayerChip(),
          // زر الموسيقى دُمج داخل زر + (مرفق) كأحد خياراته — "بحث أغنية"
          // في _showQuickActionsSheet — بدل أيقونة مستقلة هنا.
          actionButton(
            icon: Icons.add_circle_outline_rounded,
            onPressed: onAttach,
            tooltip: 'مرفق',
          ),
          // تسجيل بنمط واتساب: اضغط مطوّلًا، حرّر للإرسال، اسحب للإلغاء أو للقفل.
          VoiceHoldButton(onUploaded: onVoice),
        ],
      ),
    );
  }
}

/// شريط صغير أعلى صندوق الكتابة يعرض حالة معلَّقة (رد جارٍ تحضيره،
/// أو GIF بانتظار التأكيد) مع زر إلغاء — يُستخدم لكل من معاينة الرد
/// ومعاينة الـ GIF المعلَّق في _ChatLobbyPageState.build.
class _PendingBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onCancel;
  const _PendingBar(
      {required this.icon, required this.label, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF241733),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFC187FF), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        InkWell(
          onTap: onCancel,
          child: const Icon(Icons.close, color: Colors.white54, size: 18),
        ),
      ]),
    );
  }
}

class _PendingGifBar extends StatelessWidget {
  final String gif;
  final VoidCallback onCancel;

  const _PendingGifBar({required this.gif, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: const Color(0xFF241733),
      child: Row(
        children: [
          const Icon(Icons.gif_box_outlined,
              color: Color(0xFFC187FF), size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 25,
            height: 25,
            child: Image.asset(
              gif,
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'GIF جاهز للإرسال',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          InkWell(
            onTap: onCancel,
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }
}

class _EmptyLobby extends StatelessWidget {
  const _EmptyLobby();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('ابدأ أول رسالة في الشات الرئيسي',
          style: TextStyle(color: Colors.white54)));
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'تعذر تحميل الشات الآن. تحقق من الاتصال ثم أعد المحاولة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54))));
}





