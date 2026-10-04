import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/chat/data/services/chat_media_url_resolver.dart';

void main() {
  group('chat media storage contract', () {
    test('room voice namespace remains public-media compatible', () {
      expect(ChatMediaUrlResolver.bucketForPath('chat/voice_room/123/voice.m4a'), isNull);
    });
    test('private voice paths resolve to chat-voice', () {
      expect(
        ChatMediaUrlResolver.bucketForPath(
          'chat/voice_private/123/voice.m4a',
        ),
        'chat-voice',
      );
    });

    test('private Plus attachments resolve to chat-media-plus', () {
      expect(
        ChatMediaUrlResolver.bucketForPath(
          'chat/attachments/123/file.jpg',
        ),
        'chat-media-plus',
      );
    });

    test('legacy public relative paths are not incorrectly signed', () {
      expect(
        ChatMediaUrlResolver.bucketForPath('chat/room/123/file.jpg'),
        isNull,
      );
      expect(
        ChatMediaUrlResolver.bucketForPath(
          'https://example.supabase.co/storage/v1/object/public/media/x.jpg',
        ),
        isNull,
      );
    });
  });
}
