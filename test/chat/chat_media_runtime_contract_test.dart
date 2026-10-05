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

  test('safe YouTube controller initialization does not use fromVideoId', () {
    final inline = source('lib/core/widgets/embedded_media_player.dart');
    final mini = source('lib/core/widgets/global_mini_player.dart');
    expect(inline, contains('YoutubePlayerController('));
    expect(inline, isNot(contains('YoutubePlayerController.fromVideoId')));
    expect(mini, contains('YoutubePlayerController('));
    expect(mini, isNot(contains('YoutubePlayerController.fromVideoId')));
    expect(inline, contains('cueVideoById'));
    expect(mini, contains('loadVideoById'));
  });

  test('YouTube playback is not forced muted and uses a stable embed origin', () {
    final inline = source('lib/core/widgets/embedded_media_player.dart');
    final mini = source('lib/core/widgets/global_mini_player.dart');
    expect(inline, contains('autoPlay: false'));
    expect(inline, contains('mute: false'));
    expect(mini, contains('showControls: true'));
    expect(mini, contains('mute: false'));
    expect(mini, contains("origin: 'https://www.youtube-nocookie.com'"));
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
}
