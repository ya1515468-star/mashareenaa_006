// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import '../../../../core/services/server_sounds.dart';

/// فتح الصوت في المتصفح: يجب استدعاؤه من نقرة حقيقية. نولّد ثانية صمت
/// برمجيًا (بلا أي ملف صوتي في المشروع) لفك قفل التشغيل التلقائي.
Future<bool> unlockChatAudio() async {
  final wav = BytesBuilder();
  void le(int v, int n) {
    for (var i = 0; i < n; i++) {
      wav.addByte((v >> (8 * i)) & 255);
    }
  }

  const sr = 8000;
  const n = 800;
  wav.add(ascii.encode('RIFF'));
  le(36 + n * 2, 4);
  wav.add(ascii.encode('WAVEfmt '));
  le(16, 4);
  le(1, 2);
  le(1, 2);
  le(sr, 4);
  le(sr * 2, 4);
  le(2, 2);
  le(16, 2);
  wav.add(ascii.encode('data'));
  le(n * 2, 4);
  wav.add(Uint8List(n * 2));
  final audio = html.AudioElement('data:audio/wav;base64,${base64Encode(wav.toBytes())}')
    ..preload = 'auto'
    ..volume = 0.0;
  try {
    await audio.play();
    audio.pause();
    audio.currentTime = 0;
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> playChatSound(String event) async {
  await ServerSounds.instance.playEvent(event);
}
