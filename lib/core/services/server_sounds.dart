import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sound_preferences.dart';

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
  final Map<String, String> _files = <String, String>{};
  bool _prefetched = false;

  /// هل فشل التشغيل من البايتات على هذا الجهاز؟
  ///
  /// BytesSource يمرّ على أندرويد عبر مصدر بيانات في الذاكرة، وبعض الأجهزة
  /// وإصدارات النظام ترفضه بصمت لملفات WAV فلا يُسمع شيء ولا يُرمى خطأ
  /// مفيد. عند أول فشل يُتحوَّل نهائيًّا إلى ملف على القرص — وهو المسار
  /// الذي يقبله كل جهاز. يُجرَّب مرّة واحدة لا عند كل نغمة.
  bool _bytesUnsupported = false;

  /// يكتب النغمة ملفًّا مؤقّتًا مرّة واحدة ويعيد مساره.
  Future<String?> _fileFor(String key, Uint8List bytes) async {
    final cached = _files[key];
    if (cached != null && File(cached).existsSync()) return cached;
    try {
      final dir = await getTemporaryDirectory();
      final ext = (_mime[key] ?? 'audio/wav').endsWith('mpeg') ? 'mp3' : 'wav';
      final f = File('${dir.path}/snd_$key.$ext');
      await f.writeAsBytes(bytes, flush: true);
      return _files[key] = f.path;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db => Supabase.instance.client;

  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = <AudioPlayer>[];
  int _poolNext = 0;

  Future<AudioPlayer> _nextPlayer() async {
    if (_pool.length < _poolSize) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    final p = _pool[_poolNext % _poolSize];
    _poolNext++;
    return p;
  }

  /// بايتات نغمة من الخادم (للمشغّلات الطويلة مثل رنين المكالمات).
  Future<Uint8List?> bytesFor(String key) => _load(key);

  String mimeFor(String key) => _mime[key] ?? 'audio/wav';

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
      case 'quote':
        return 'quote';
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
  Future<bool> play(String key,
      {double volume = 0.85, bool bypassPreferences = false}) async {
    try {
      // بوّابة التفضيلات في نقطة واحدة: كل نغمة في التطبيق تمرّ من هنا،
      // ففرضها هنا يعني أنّ أي نداء جديد يحترمها بلا أن يتذكّرها كاتبه.
      // (كانت مفاتيح البروفايل تُحفَظ في مكان لا يقرأه أحد، فالإطفاء
      // ينجح والأصوات تبقى.) تمريرة تجاوز للمعاينة في شاشة الأصوات.
      if (!bypassPreferences && !SoundPreferences.instance.allows(key)) {
        return false;
      }
      // منع التكرار المتزاحم لنفس النغمة خلال 120ms
      final now = DateTime.now();
      final last = _lastPlayed[key];
      if (last != null && now.difference(last).inMilliseconds <
              (key.startsWith('game_') ? 3000 : 120)) return true;
      _lastPlayed[key] = now;
      final bytes = await _load(key);
      if (bytes == null) return false;
      // مجمّع مشغّلات ثابت يُعاد استعماله ولا يُتخلَّص منه أبدًا.
      // السبب المُثبت لأكثر خطأ تكرارًا (87 مرة، fatal): تتبّع الجهاز يُظهر
      // AudioPlayer.dispose → release → stop يرمي على أندرويد
      // "Player has not yet been created or has already been disposed" كخطأ
      // غير ملتقَط من داخل المكتبة نفسها — try/catch حول dispose لا يلتقطه.
      // إنشاء مشغّل جديد والتخلّص منه لكل نغمة كان مصدره. المجمّع يلغي dispose.
      final player = await _nextPlayer();
      try {
        await player.stop();
      } catch (_) {}

      if (!_bytesUnsupported) {
        try {
          await player.play(
            BytesSource(bytes, mimeType: _mime[key] ?? 'audio/wav'),
            volume: volume,
          );
          return true;
        } catch (_) {
          // لا يُعاد المحاولة بالبايتات بعد اليوم على هذا الجهاز.
          _bytesUnsupported = true;
        }
      }

      final path = await _fileFor(key, bytes);
      if (path == null) return false;
      await player.play(DeviceFileSource(path), volume: volume);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> playEvent(String event) => play(keyForEvent(event));
}

/// اختصار للاستدعاء من الواجهات.
void playServerSound(String key) => unawaited(ServerSounds.instance.play(key));
