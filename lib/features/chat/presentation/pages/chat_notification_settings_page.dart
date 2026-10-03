import 'package:flutter/material.dart';
import '../../../../core/typography/local_glyph_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatNotificationSettingsPage extends StatefulWidget {
  const ChatNotificationSettingsPage({super.key});
  @override
  State<ChatNotificationSettingsPage> createState() =>
      _ChatNotificationSettingsPageState();
}

class _ChatNotificationSettingsPageState
    extends State<ChatNotificationSettingsPage> {
  Map<String, dynamic> values = {};
  bool loading = true, saving = false;
  final db = Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await db.rpc('get_my_chat_notification_preferences');
      if (mounted) setState(() => values = Map<String, dynamic>.from(r as Map));
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _set(String key, bool value) async {
    setState(() {
      values[key] = value;
      saving = true;
    });
    try {
      await db.rpc('update_chat_notification_preferences', params: {
        'p_values': {key: value}
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ الإعداد: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget row(String key, String title) => SwitchListTile(
      value: values[key] != false,
      onChanged: saving ? null : (v) => _set(key, v),
      title: LocalGlyphText(title));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('أصوات وإشعارات الدردشة')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                row('master_chat_sound', 'Master Chat Sound'),
                row('public_message_sound', 'صوت رسائل العام'),
                row('private_message_sound', 'صوت رسائل الخاص'),
                row('mention_sound', 'صوت المنشن'),
                row('reply_sound', 'صوت الرد والاقتباس'),
                row('calls_sound', 'صوت المكالمات'),
                row('warning_sound', 'صوت التحذيرات'),
                row('notifications_sound', 'أصوات الإشعارات'),
                const Divider(),
                row('call_notifications', 'إشعارات المكالمات'),
                row('audio_calls_enabled', 'المكالمات الصوتية'),
                row('video_calls_enabled', 'مكالمات الفيديو'),
                row('youtube_enabled', 'YouTube'),
                row('tiktok_enabled', 'TikTok'),
                row('mini_player_enabled', 'Mini Player'),
              ]));
  }
}
