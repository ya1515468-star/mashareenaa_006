import 'package:flutter/services.dart';

import '../../../../core/services/server_sounds.dart';

/// النغمات تأتي من الخادم (ServerSounds). صوت النظام احتياطي فقط عند تعذّر التحميل.
Future<void> playChatSound(String event) async {
  final ok = await ServerSounds.instance.playEvent(event);
  if (ok) return;
  final type = switch (event) {
    'warning' || 'mention' || 'call' => SystemSoundType.alert,
    _ => SystemSoundType.click,
  };
  await SystemSound.play(type);
}

Future<bool> unlockChatAudio() async => true;
