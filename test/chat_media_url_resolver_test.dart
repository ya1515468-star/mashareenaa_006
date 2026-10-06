import 'package:flutter_test/flutter_test.dart';

import 'package:mashareena/features/chat/data/services/chat_media_url_resolver.dart';

void main() {
  test('recognizes canonical and legacy chat voice paths', () {
    expect(
      ChatMediaUrlResolver.bucketForPath(
        'chat/voice_private/u/voice_1.m4a',
      ),
      'chat-voice',
    );
    expect(
      ChatMediaUrlResolver.bucketForPath(
        'chat-voice/chat/voice_private/u/voice_1.m4a',
      ),
      'chat-voice',
    );
  });

  test('recognizes legacy chat media plus paths', () {
    expect(
      ChatMediaUrlResolver.bucketForPath(
        'chat-media-plus/chat/attachments/u/file.m4a',
      ),
      'chat-media-plus',
    );
  });
}
