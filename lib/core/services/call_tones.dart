import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../monitoring/error_monitor.dart';
import 'server_sounds.dart';

/// نغمات المكالمات المتكرّرة (حلقة) — من الخادم مثل باقي النغمات:
///  • `call`          : رنين المستقبِل طوال حالة "ترنّ".
///  • `call_ringback` : نغمة انتظار المتصل حتى يدخل الطرف الآخر.
/// كانت المكالمة الواردة تُصدر نغمة واحدة قصيرة فقط ثم صمت، والمتصل لا
/// يسمع أي شيء أثناء الانتظار. مشغّل واحد ثابت لكل نوع، لا يُتخلَّص منه
/// (نفس سبب مجمّع ServerSounds: dispose يرمي خطأً غير ملتقَط على أندرويد).
class CallTones {
  CallTones._();
  static final CallTones instance = CallTones._();

  AudioPlayer? _player;
  String? _playing;

  Future<AudioPlayer> _ensure() async {
    final p = _player ??= AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    return p;
  }

  /// يحترم إعدادات المستخدم (الصوت العام + أصوات المكالمات).
  Future<bool> _allowed() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('get_my_chat_notification_preferences');
      if (raw is Map) {
        if (raw['master_chat_sound'] == false) return false;
        if (raw['calls_sound'] == false) return false;
      }
    } catch (_) {
      // تعذّر قراءة الإعداد: الرنين أهم من الصمت في مكالمة واردة.
    }
    return true;
  }

  Future<void> startRingtone() => _start('call', volume: 1.0);

  Future<void> startRingback() => _start('call_ringback', volume: 0.6);

  Future<void> _start(String key, {required double volume}) async {
    if (_playing == key) return;
    if (!await _allowed()) return;
    try {
      final bytes = await ServerSounds.instance.bytesFor(key);
      if (bytes == null) return;
      final p = await _ensure();
      try {
        await p.stop();
      } catch (_) {}
      _playing = key;
      await p.play(
        BytesSource(bytes, mimeType: ServerSounds.instance.mimeFor(key)),
        volume: volume,
      );
    } catch (e, st) {
      _playing = null;
      unawaited(ErrorMonitor.report('CALL_TONE_FAILED($key): $e',
          stack: st, source: 'call_tones', severity: 'warning'));
    }
  }

  /// يوقف أي نغمة مكالمة جارية. آمن للاستدعاء المتكرر.
  Future<void> stop([String? onlyKey]) async {
    if (_playing == null) return;
    if (onlyKey != null && _playing != onlyKey) return;
    _playing = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> stopRingtone() => stop('call');
  Future<void> stopRingback() => stop('call_ringback');
}
