import 'chat_sound_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ChatSoundEvent {
  send,
  receive,
  publicMessage,
  privateMessage,
  mention,
  reply,
  quote,
  friendRequest,
  gift,
  notification,
  warning,
  call,
  transfer,
  block,
}

class ChatSoundService {
  final SupabaseClient client;
  final Map<ChatSoundEvent, DateTime> _lastPlayed = <ChatSoundEvent, DateTime>{};

  ChatSoundService(this.client);

  Future<void> play(ChatSoundEvent event, {String? roomId}) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // السبب المُثبت لصمت المنشن/الرد/الاقتباس في الغرف: الغرفة العامة بلا
      // أي إعداد أصوات محفوظ (settings.notification_sounds = null)، وكان
      // غياب الإعداد يُعامَل كـ"صامت" فتسكت كل نغمات الغرفة. الآن إعداد الغرفة
      // يُطبَّق فقط إن ضبطه المالك صراحةً؛ وإلا تُستخدم إعدادات المستخدم
      // ونغمات الخادم الافتراضية. القيمة 'none' وحدها تعني الصمت.
      final personalRaw =
          await client.rpc('get_my_chat_notification_preferences');
      final personal = personalRaw is Map
          ? Map<String, dynamic>.from(personalRaw)
          : const <String, dynamic>{};
      if (personal['master_chat_sound'] == false) return;
      Map<String, dynamic> roomPrefs = const <String, dynamic>{};
      if (roomId != null) {
        try {
          roomPrefs = await _loadRoomSoundPreferences(roomId);
        } catch (_) {}
      }
      final m = personal;

      if (event != ChatSoundEvent.call && event != ChatSoundEvent.warning) {
        final smartRaw = await client.rpc('get_profile_service_runtime', params: {'p_feature_key': 'chat_smart_mute'});
        if (smartRaw is Map && smartRaw['enabled'] == true) {
          final settings = smartRaw['settings'];
          final seconds = int.tryParse((settings is Map ? settings['value'] : null)?.toString() ?? '') ?? 30;
          final now = DateTime.now();
          final last = _lastPlayed[event];
          if (last != null && now.difference(last).inSeconds < seconds) return;
          _lastPlayed[event] = now;
        }
      }

      final roomKey = switch (event) {
        ChatSoundEvent.publicMessage => 'publicMessage',
        ChatSoundEvent.privateMessage => 'privateMessage',
        ChatSoundEvent.send => 'publicMessage',
        ChatSoundEvent.receive => 'privateMessage',
        ChatSoundEvent.mention => 'mention',
        ChatSoundEvent.reply => 'reply',
        ChatSoundEvent.quote => 'quote',
        ChatSoundEvent.friendRequest => 'friendRequest',
        ChatSoundEvent.gift => 'gift',
        ChatSoundEvent.notification => 'notification',
        ChatSoundEvent.warning => 'warning',
        ChatSoundEvent.call => 'call',
        ChatSoundEvent.transfer => 'gift',
        ChatSoundEvent.block => 'notification',
      };

      final roomSound = roomPrefs[roomKey]?.toString();
      if (roomSound == 'none') return;

      final personalKey = switch (event) {
        ChatSoundEvent.publicMessage => 'public_message_sound',
        ChatSoundEvent.privateMessage => 'private_message_sound',
        ChatSoundEvent.send => 'public_message_sound',
        ChatSoundEvent.receive => 'private_message_sound',
        ChatSoundEvent.mention => 'mention_sound',
        ChatSoundEvent.reply => 'reply_sound',
        ChatSoundEvent.quote => 'reply_sound',
        ChatSoundEvent.friendRequest ||
        ChatSoundEvent.gift ||
        ChatSoundEvent.notification ||
        ChatSoundEvent.transfer ||
        ChatSoundEvent.block =>
          'notifications_sound',
        ChatSoundEvent.warning => 'warning_sound',
        ChatSoundEvent.call => 'calls_sound',
      };
      if (m[personalKey] == false) return;
      if (roomSound != null && roomSound.isNotEmpty) {
        await playChatSound(roomSound);
        return;
      }
      await playChatSound(event.name);
    } catch (_) {
      // Sound is non-critical and must never break chat functionality.
    }
  }

  Future<Map<String, dynamic>> _loadRoomSoundPreferences(String roomId) async {
    final raw = await client.rpc(
      'get_room_notification_sounds',
      params: {'p_room_id': roomId},
    );
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }
}
