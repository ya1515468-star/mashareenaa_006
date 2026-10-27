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
import '../../../../core/widgets/animated_gold.dart';
import '../../../../core/services/server_font_for_user.dart';
import '../../../../core/services/server_fonts.dart';
import '../../../../core/chat/message_text_style.dart';
import 'chat_feature_settings_page.dart';
import 'chat_notification_settings_page.dart';
import 'directory_list_page.dart';
import 'friends_wall_page.dart';
import 'sponsored_ads_page.dart';
import '../widgets/chat_theme_picker_sheet.dart';
import '../../data/services/chat_sound_service.dart';
import '../../data/services/chat_sound_player.dart';

// تقسيم بنيوي: الودجات المساعدة نُقلت إلى ملفات part.
// part لا يغيّر أي نطاق وصول — الأعضاء الخاصّة تبقى مشتركة بين الأجزاء,
// فلا حاجة لأي استيراد جديد ولا لتغيير أي اسم.
part 'chat_lobby_top_bar.dart';
part 'chat_lobby_message_row.dart';
part 'chat_lobby_event_overlay.dart';
part 'chat_lobby_feed_rows.dart';
part 'chat_lobby_mentions.dart';
part 'chat_lobby_avatar.dart';
part 'chat_lobby_composer.dart';
part 'chat_lobby_states.dart';

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
  final List<String> _pendingGifs = [];

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

  /// مُعرِّفي المستعار في هذه الغرفة.
  ///
  /// بعد أن صار الخادم لا يكتب user_id في صفّ الرسالة المجهولة، لم يعد
  /// بالإمكان تمييز رسائلي بمقارنة المعرّف. والعلامة لا تُبَثّ في الصفّ
  /// لأنّه صفّ واحد يصل الجميع، فتصير «لي» عند كل من يراها.
  String? _myAnonHandle;

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
      // منشورات بوت المحتوى صامتة: تتكرر كل بضع دقائق، ونغمة لكل منشور
      // ستزعج الأعضاء.
      if (metadata['system_event']?.toString() == 'content_bot') continue;
      // الرد والاقتباس الموجّهان لي أولًا (الخادم يضيفني أيضًا إلى
      // mention_user_ids عند الرد، فكان المنشن يطغى عليهما)، ثم المنشن العادي.
      final replyMode = metadata['reply_mode']?.toString();
      if (replyToUid == currentUid && replyMode == 'quote') {
        unawaited(_sound.play(ChatSoundEvent.quote, roomId: _roomId));
      } else if (replyToUid == currentUid) {
        unawaited(_sound.play(ChatSoundEvent.reply, roomId: _roomId));
      } else if (mentioned.contains(currentUid)) {
        unawaited(_sound.play(ChatSoundEvent.mention, roomId: _roomId));
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
        // ascending:true مع limit يجلب **أقدم** N صفّ؛ متى تجاوز الجدول N لا تدخل
        // أي رسالة جديدة القائمة أبدًا (الغرفة بلغت 161 > 150 فاختفى كل جديد).
        // الأحدث أولًا ثم يُعاد الترتيب تصاعديًا في البناء (displayRows.sort).
        .order('created_at', ascending: false)
        .limit(150);
    _globalEvents = _db
        .from('chat_global_events')
        .stream(primaryKey: ['id'])
        // ascending:true مع limit يجلب **أقدم** N صفّ؛ متى تجاوز الجدول N لا تدخل
        // أي رسالة جديدة القائمة أبدًا (الغرفة بلغت 161 > 150 فاختفى كل جديد).
        // الأحدث أولًا ثم يُعاد الترتيب تصاعديًا في البناء (displayRows.sort).
        .order('created_at', ascending: false)
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
    // البند 4: عدّة GIF تُرسَل في رسالة واحدة (فقاعة واحدة). الخادم يرفض
    // أي kind جديد (`p_kind not in ('text','emoji','gif',…)`)، لكنه يحفظ
    // مفاتيح p_metadata غير المعروفة كما هي (v_meta := coalesce(p_metadata,
    // '{}') ثم jsonb_set فوقه) — فالقائمة تُحمَل هنا بلا أي هجرة خادمية،
    // ويبقى kind='gif' وattachment_url = أول GIF لتوافق الرسائل القديمة.
    List<String>? gifUrls,
  }) async {
    final user = _user;
    final payload = (message ?? body).trim();
    if (user == null || payload.isEmpty) {
      throw const FormatException('EMPTY_MESSAGE');
    }
    final requestId = const Uuid().v4();
    // البند 10: الاقتباس يجعل صاحب الرسالة المقتبسة مَنشونًا فعليًا — اسمه
    // يظهر كمنشن ويصله تنبيه صوتي. منطق الاستقبال الموجود أصلًا يشغّل نغمة
    // المنشن حين يجد معرّف القارئ في mention_user_ids، فإضافته هنا تكفي
    // ولا تحتاج أي تغيير في الخادم ولا في مسار الاستقبال.
    final mentionIds = _mentionUserIds.values.toSet();
    final mentionNames = _mentionUserNames.toSet();
    final quoting = replyMode.contains('quote');
    if (quoting && replyToSenderUid != null && replyToSenderUid.isNotEmpty) {
      // لا يُمنشَن المرء نفسه فلا تصله نغمة على اقتباسه الخاص.
      if (replyToSenderUid != user.id) {
        mentionIds.add(replyToSenderUid);
        final quotedName = _replyingTo?['display_name']?.toString().trim();
        if (quotedName != null && quotedName.isNotEmpty) {
          mentionNames.add(quotedName);
        }
      }
    }
    final metadata = <String, dynamic>{
      'reply_mode': replyMode,
      'mention_user_ids': mentionIds.toList(),
      'mention_user_names': mentionNames.toList(),
      'request_id': requestId,
      if (replyToId != null && quoting) 'quoted_message_id': replyToId,
      if (gifUrls != null && gifUrls.length > 1) 'gif_urls': gifUrls,
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
    final gifs = List<String>.from(_pendingGifs);
    if ((text.isEmpty && gifs.isEmpty) || _user == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // البند 4: كانت حلقة ترسل رسالة مستقلة لكل GIF، فثلاث سمايلات تنتج
      // ثلاث فقاعات. الآن رسالة واحدة تحمل كل الروابط في metadata.gif_urls
      // فتُعرَض في فقاعة واحدة.
      if (gifs.isNotEmpty) {
        await _insertPublicMessage(
          body: gifs.first,
          message: 'GIF',
          kind: 'gif',
          attachmentUrl: gifs.first,
          gifUrls: gifs,
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
        _pendingGifs.clear();
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
      backgroundColor: const Color(0xFF15141A),
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
      backgroundColor: const Color(0xFF15141A),
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
      backgroundColor: const Color(0xFF15141A),
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

  /// إعادة بناء قنوات اللعبة بعد انقطاع.
  ///
  /// كانت الثلاث تشترك بـ(_, __) {} فتبتلع الخطأ ولا تعود أبدًا: انقطاع
  /// لحظي يعني ألّا يصل اللاعب تحدٍّ ولا تُفتح له مباراة قُبلت، بلا أي
  /// أثر ظاهر يفسّر له السبب.
  void _resubscribeDice() {
    if (!mounted) return;
    _subscribeDice();
  }

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
        .subscribe(retryOnChannelError(_resubscribeDice,
            isAlive: () => mounted));
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
          .subscribe(retryOnChannelError(_resubscribeDice,
              isAlive: () => mounted));
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
          .subscribe(retryOnChannelError(_resubscribeDice,
              isAlive: () => mounted));
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
      multiGif: true,
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
        setState(() => _pendingGifs.add(gif));
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
      // الأغنية تُرسَل أولًا فقاعةً بصورة الفيديو، ولا تُشغَّل إلا بالضغط
      // على الفقاعة نفسها — كان التشغيل يبدأ فورًا قبل ظهورها في الشات.
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

  void _removePendingGif(int i) => setState(() => _pendingGifs.removeAt(i));

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

  /// كشف كاتب رسالة مجهولة — للمالك وحده، والخادم هو من يتحقّق.
  Future<void> _revealAnonymousAuthor(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final res = await _db.rpc('owner_reveal_anonymous_author',
          params: {'p_message_id': id});
      if (!mounted) return;
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (m['found'] != true) {
        ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(
            content: Text('لا سجلّ لكاتب هذه الرسالة')));
        return;
      }
      final uid = m['user_id']?.toString();
      await showDialog<void>(
        context: context,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('كاتب الرسالة المجهولة'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${m['display_name'] ?? m['username'] ?? 'عضو'}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('أُرسلت: ${m['sent_at'] ?? ''}',
                  style: const TextStyle(fontSize: 11)),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('إغلاق')),
              if (uid != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    _openMiniProfile(uid);
                  },
                  child: const Text('فتح البروفايل'),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text('تعذّر الكشف: $e')));
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> row) async {
    final body = (row['body'] ?? row['message'])?.toString() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15141A),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            // المالك يرى ويتحكّم بكل شيء: الهوية خلف الرسالة المجهولة
            // محفوظة خادميًّا، وكشفها حكرٌ عليه ويُسجَّل كل كشف.
            if (_isPlatformOwner &&
                row['metadata'] is Map &&
                (row['metadata'] as Map)['anonymous_chat'] == true) ...[
              ListTile(
                leading: const Icon(Icons.visibility_rounded,
                    color: Color(0xFFFFD166)),
                title: const Text('كشف هوية المُرسِل',
                    style: TextStyle(color: Color(0xFFFFD166))),
                subtitle: const Text('يُسجَّل باسمك في سجلّ التدقيق',
                    style: TextStyle(fontSize: 11, color: Colors.white54)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_revealAnonymousAuthor(row));
                },
              ),
              const Divider(height: 1, color: Colors.white12),
            ],
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
    // فشله صامت: تمييز رسائلي تحسينٌ بصري لا يُعطَّل لأجله الشات.
    unawaited(() async {
      try {
        final h = await _db.rpc('my_anon_handle', params: {'p_room_id': _roomId});
        final v = h?.toString();
        if (mounted && v != null && v.isNotEmpty) {
          setState(() => _myAnonHandle = v);
        }
      } catch (_) {}
    }());
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
      backgroundColor: const Color(0xFF0A0A0C),
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
                              final isContentBot = kind == 'system' &&
                                  metadata['system_event']?.toString() == 'content_bot';
                              if (!isGlobalEvent && !isWelcomeBot && !isContentBot) {
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
                                // بوت المحتوى: فقاعة خاصة بلون وخط مميزين
                                // (لا تمرّ بمسار رسائل الأعضاء ولا هويتهم).
                                if (row['kind']?.toString() == 'system' &&
                                    metadata['system_event']?.toString() ==
                                        'content_bot') {
                                  return KeyedSubtree(
                                    key: ValueKey(occurrenceKey),
                                    child: _ContentBotRow(
                                      message: row['message']?.toString() ?? '',
                                      label: metadata['bot_label']?.toString() ??
                                          'معلومة',
                                      icon: metadata['bot_icon']?.toString() ?? '💡',
                                      category:
                                          metadata['bot_category']?.toString() ?? '',
                                    ),
                                  );
                                }
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
                                              _user?.id ||
                                          (_myAnonHandle != null &&
                                              row['metadata'] is Map &&
                                              (row['metadata']
                                                      as Map)['anon_handle'] ==
                                                  _myAnonHandle),
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
                                            setState(() => _pendingGifs.add(url));
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
                    '${_replyMode == 'quote' ? 'اقتباس من' : 'رد على'} ${_replyingTo!['display_name'] ?? 'عضو'}: '
                    '${(_replyingTo!['body'] ?? '📎 مرفق').toString()}',
                onCancel: _cancelReply,
              ),
            if (_pendingGifs.isNotEmpty)
              _PendingGifBar(
                gifs: _pendingGifs,
                onRemove: _removePendingGif,
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
      backgroundColor: const Color(0xFF15141A),
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
          .order('created_at', ascending: false)
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
                backgroundColor: const Color(0xFF15141A),
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
                          fillColor: const Color(0xFF1E1C24),
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
                          fillColor: const Color(0xFF1E1C24),
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
                  color: const Color(0xFF15141A),
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
                              colors: [Color(0xFF8A6D1C), Color(0xFFB04CE4)]),
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
