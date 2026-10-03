import 'package:flutter/services.dart';

Future<void> playChatSound(String event) async {
  final type = switch (event) {
    'warning' || 'mention' || 'call' => SystemSoundType.alert,
    _ => SystemSoundType.click,
  };
  await SystemSound.play(type);
}


Future<bool> unlockChatAudio() async => true;
