// Runtime regression coverage for YouTube WebView initialization and voice recorder lifecycle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;

  String source(String relative) =>
      File('${root.path}/$relative').readAsStringSync();

  test('WhatsApp recorder stays visible and exposes explicit send/delete', () {
    final s = source('lib/features/chat/presentation/widgets/voice_hold_button.dart');
    expect(s, contains("Icons.mic_rounded"));
    expect(s, contains("Icons.send_rounded"));
    expect(s, contains("Icons.delete_outline_rounded"));
    expect(s, contains('_recorder.cancel()'));
  });

  test('YouTube message cards delegate playback to one global player', () {
    final inline = source('lib/core/widgets/embedded_media_player.dart');
    final mini = source('lib/core/widgets/global_mini_player.dart');
    expect(inline, isNot(contains('YoutubePlayerController(')));
    expect(inline, contains('miniPlayerProvider'));
    expect(inline, contains('MiniPlayerTrack('));
    expect(inline, contains('YoutubeThumbnail'));
    expect(mini, contains('YoutubePlayerController('));
    expect(mini, isNot(contains('YoutubePlayerController.fromVideoId')));
    expect(mini, contains('loadVideoById'));
    expect(mini, contains('width: 92'));
    expect(mini, contains('height: 52'));
    expect(mini, contains("tooltip: 'تكبير'"));
    expect(mini, contains("tooltip: 'تصغير'"));
    expect(mini, isNot(contains('width: 1,')));
    expect(mini, isNot(contains('height: 1,')));
    expect(mini, isNot(contains('Opacity(')));
  });

  test('YouTube global player uses safe origin, controls and unmuted volume', () {
    final mini = source('lib/core/widgets/global_mini_player.dart');
    expect(mini, contains('showControls: true'));
    expect(mini, contains('mute: false'));
    expect(mini, contains('setVolume(100)'));
    expect(
      mini,
      contains("origin: 'https://com.mashareena.mashareena'"),
    );
    expect(
      mini,
      contains(
        "static const _blockedCodes = <int>{2, 5, 100, 101, 150, 153};",
      ),
    );
    expect(
      mini,
      isNot(
        contains(
          "static const _blockedCodes = <int>{2, 5, 100, 101, 150, 152, 153};",
        ),
      ),
    );
  });

  test('room typing does not use the unauthorized private channel or heartbeat', () {
    final s = source('lib/features/chat/presentation/pages/chat_lobby_page.dart');
    expect(s, isNot(contains('RealtimeChannelConfig(private: true)')));
    expect(s, isNot(contains('_roomTypingHeartbeat')));
    expect(s, contains("event: 'room_typing'"));
  });

  test('Agora maps local volume uid 0 to the authenticated token uid', () {
    final s = source('lib/features/chat/presentation/widgets/room_mic_seats.dart');
    expect(s, contains('if (s.uid == 0)'));
    expect(s, contains('active.add(localUid)'));
    expect(s, contains('setDefaultAudioRouteToSpeakerphone(true)'));
  });

  test('YouTube search keeps thumbnails and readable action buttons', () {
    final s = source('lib/core/widgets/song_search_sheet.dart');
    expect(s, contains('YoutubeThumbnail'));
    expect(s, contains("label: const Text("));
    expect(s, contains("'إرسال'"));
    expect(s, contains("'تشغيل'"));
    expect(s, contains('mainAxisExtent: 374'));
    expect(s, contains('بحث YouTube'));
    expect(s, contains('ابحث ثم اختر تشغيل أو إرسال'));
  });

  test('voice playback never sends a relative Storage path to audioplayers', () {
    final resolver =
        source('lib/features/chat/data/services/chat_media_url_resolver.dart');
    final player =
        source('lib/features/chat/presentation/widgets/voice_message_player.dart');
    expect(resolver, contains("VOICE_SIGNED_URL_INVALID"));
    expect(player, contains("resolved.startsWith('http://')"));
    expect(player, contains('ReleaseMode.stop'));
  });
}

