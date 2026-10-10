import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نغمات التطبيق كلها محفوظة في الخادم (جدول app_sounds) وليست في المشروع.
/// تُنزَّل عند أول استخدام (أو مسبقًا عبر [prefetch]) وتُخزَّن في الذاكرة،
/// ثم تُشغَّل من البايتات مباشرة. أي فشل (بلا اتصال/غير مسجّل) صامت ولا
/// يكسر التطبيق. لتغيير نغمة: حدّث صفها في app_sounds فقط — بلا تحديث للتطبيق.
class ServerSounds {
  ServerSounds._();
  static final ServerSounds instance = ServerSounds._();

  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, String> _mime = <String, String>{};
  final Map<String, Future<Uint8List?>> _loading = <String, Future<Uint8List?>>{};
  final Map<String, DateTime> _lastPlayed = <String, DateTime>{};
  bool _prefetched = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// يحوّل اسم حدث الدردشة القديم إلى مفتاح النغمة في الخادم.
  static String keyForEvent(String event) {
    switch (event) {
      case 'send':
        return 'message_send';
      case 'receive':
      case 'privateMessage':
        return 'message_receive';
      case 'mention':
        return 'mention';
      case 'reply':
        return 'reply';
      case 'friendRequest':
        return 'friend_request';
      case 'gift':
        return 'gift';
      case 'transfer':
        return 'transfer';
      case 'warning':
        return 'warning';
      case 'call':
        return 'call';
      case 'block':
        return 'block';
      case 'notification':
        return 'notification';
      case 'publicMessage':
      default:
        return 'public_message';
    }
  }

  Future<Uint8List?> _load(String key) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _loading[key] ??= () async {
      try {
        if (_db.auth.currentUser == null) return null;
        final raw = await _db.rpc('get_app_sound', params: {'p_key': key});
        if (raw is! List || raw.isEmpty) return null;
        final row = Map<String, dynamic>.from(raw.first as Map);
        final b64 = (row['data_b64'] ?? '').toString().replaceAll(RegExp(r'\s'), '');
        if (b64.isEmpty) return null;
        final bytes = base64Decode(b64);
        _cache[key] = bytes;
        _mime[key] = (row['mime'] ?? 'audio/wav').toString();
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _loading.remove(key);
      }
    }();
  }

  /// تنزيل كل النغمات مسبقًا في الخلفية كي تُشغَّل فورًا دون تأخير.
  Future<void> prefetch() async {
    if (_prefetched || _db.auth.currentUser == null) return;
    try {
      final raw = await _db.rpc('get_app_sound_keys');
      if (raw is! List) return;
      _prefetched = true;
      for (final r in raw) {
        final key = (r as Map)['key']?.toString();
        // أصوات الدخول الملكي كبيرة نسبيًا: تُنزَّل عند أول استخدام فقط.
        if (key != null && !key.startsWith('royal_')) await _load(key);
      }
    } catch (_) {
      _prefetched = false;
    }
  }

  /// يشغّل نغمة بمفتاحها. يعيد true إن بدأ التشغيل فعلًا.
  Future<bool> play(String key, {double volume = 0.85}) async {
    try {
      // منع التكرار المتزاحم لنفس النغمة خلال 120ms
      final now = DateTime.now();
      final last = _lastPlayed[key];
      if (last != null && now.difference(last).inMilliseconds <
              (key.startsWith('game_') ? 3000 : 120)) return true;
      _lastPlayed[key] = now;
      final bytes = await _load(key);
      if (bytes == null) return false;
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      unawaited(player.onPlayerComplete.first.then((_) => player.dispose()));
      Timer(const Duration(seconds: 12), () => unawaited(player.dispose()));
      await player.play(
        BytesSource(bytes, mimeType: _mime[key] ?? 'audio/wav'),
        volume: volume,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> playEvent(String event) => play(keyForEvent(event));
}

/// اختصار للاستدعاء من الواجهات.
void playServerSound(String key) => unawaited(ServerSounds.instance.play(key));
