import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// كراسي المايك في الغرفة (نمط تيك توك).
///
/// الحالة كلها خادمية (room_mic_settings / room_mic_seats). صلاحية التحدّث
/// يقررها الخادم: agora-room-token يمنح رمز "متحدّث" فقط لمن يجلس على كرسي
/// غير مكتوم، والباقون مستمعون. المالك ومن يدير الغرفة يتحكمون بعدد الكراسي،
/// وتشغيل المايك وإيقافه، وقفل الكراسي، والكتم، والإنزال.
class RoomMicSeats extends StatefulWidget {
  final String roomId;
  const RoomMicSeats({super.key, required this.roomId});

  @override
  State<RoomMicSeats> createState() => _RoomMicSeatsState();
}

class _RoomMicSeatsState extends State<RoomMicSeats> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _state;
  RealtimeChannel? _channel;
  final _voice = _RoomVoice();
  bool _busy = false;

  String? get _me => _db.auth.currentUser?.id;

  List<Map<String, dynamic>> get _seats =>
      ((_state?['seats'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Map<String, dynamic>? get _mySeat =>
      _seats.where((s) => s['user_id']?.toString() == _me).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _db.channel('room_mic:${widget.roomId}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_mic_seats',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'room_id', value: widget.roomId),
          callback: (_) => _load())
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_mic_settings',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'room_id', value: widget.roomId),
          callback: (_) => _load())
      ..subscribe();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) unawaited(_db.removeChannel(ch));
    unawaited(_voice.leave());
    _voice.speaking.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _db.rpc('get_room_mic', params: {'p_room': widget.roomId});
      if (!mounted || r is! Map) return;
      final prevMine = _mySeat;
      setState(() => _state = Map<String, dynamic>.from(r));
      await _syncVoice(prevMine);
    } catch (_) {}
  }

  /// يوائم حالة الصوت مع الخادم: الانضمام كمستمع، الترقية لمتحدّث عند الجلوس،
  /// والعودة لمستمع عند النزول أو الكتم الإداري.
  Future<void> _syncVoice(Map<String, dynamic>? prevMine) async {
    // على الويب يحتاج Agora سكربت iris-web غير المضاف للمشروع؛ الكراسي تبقى
    // ظاهرة وقابلة للإدارة، والصوت يعمل على تطبيق الهاتف.
    if (kIsWeb) return;
    if (_state?['enabled'] != true) {
      await _voice.leave();
      return;
    }
    final mine = _mySeat;
    final shouldSpeak = mine != null && mine['muted'] != true;
    try {
      if (!_voice.joined) {
        await _voice.join(widget.roomId);
      }
      if (shouldSpeak != _voice.publisher) {
        await _voice.refreshRole(widget.roomId);
        if (_voice.publisher && _voice.uid != null) {
          unawaited(_db.rpc('set_my_mic_agora_uid',
              params: {'p_room': widget.roomId, 'p_agora_uid': _voice.uid}));
        }
      }
      if (mine != null) {
        await _voice.setMuted(mine['self_muted'] == true || mine['muted'] == true);
      }
    } catch (e) {
      _toast('تعذّر الاتصال الصوتي: $e');
    }
  }

  void _toast(String t) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t)));

  String _err(Object e) {
    final t = e.toString();
    if (t.contains('MIC_RESTRICTED')) return 'لا يمكنك الصعود للمايك وأنت مقيّد في هذه الغرفة.';
    if (t.contains('SEAT_UNAVAILABLE')) return 'هذا الكرسي غير متاح.';
    if (t.contains('NO_FREE_SEAT')) return 'لا يوجد كرسي فارغ.';
    if (t.contains('MIC_DISABLED')) return 'المايك متوقف في هذه الغرفة.';
    if (t.contains('TARGET_ROLE_TOO_HIGH') || t.contains('FORBIDDEN')) return 'لا تملك صلاحية هذا الإجراء.';
    return 'تعذّر التنفيذ: $t';
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params) async {
    setState(() => _busy = true);
    try {
      await _db.rpc(fn, params: params);
      await _load();
    } catch (e) {
      _toast(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _admin(String action, {int? seat, int? value}) => _rpc('room_mic_admin', {
        'p_room': widget.roomId,
        'p_action': action,
        'p_seat': seat,
        'p_value': value,
      });

  Future<void> _take(int seat) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _toast('اسمح بالوصول إلى الميكروفون للصعود للمايك.');
      return;
    }
    await _rpc('take_mic_seat', {'p_room': widget.roomId, 'p_seat': seat});
  }

  Future<void> _onSeatTap(Map<String, dynamic> s) async {
    final idx = (s['index'] as num).toInt();
    final occupant = s['user_id']?.toString();
    final control = _state?['can_control'] == true;
    final mine = occupant != null && occupant == _me;
    final locked = s['locked'] == true;

    final actions = <(String, IconData, Future<void> Function())>[];
    if (occupant == null && !locked) actions.add(('اصعد إلى المايك', Icons.mic, () => _take(idx)));
    if (mine) {
      final selfMuted = s['self_muted'] == true;
      actions.add((selfMuted ? 'تشغيل مايكي' : 'كتم مايكي', selfMuted ? Icons.mic : Icons.mic_off,
          () => _rpc('set_my_mic_muted', {'p_room': widget.roomId, 'p_muted': !selfMuted})));
      actions.add(('النزول من المايك', Icons.logout, () => _rpc('leave_mic_seat', {'p_room': widget.roomId})));
    }
    if (control) {
      if (occupant != null && !mine) {
        final muted = s['muted'] == true;
        actions.add((muted ? 'إلغاء كتم العضو' : 'كتم العضو', muted ? Icons.mic : Icons.mic_off,
            () => _admin(muted ? 'unmute' : 'mute', seat: idx)));
        actions.add(('إنزال من المايك', Icons.person_remove, () => _admin('kick', seat: idx)));
      }
      actions.add((locked ? 'فتح الكرسي' : 'قفل الكرسي', locked ? Icons.lock_open : Icons.lock,
          () => _admin(locked ? 'unlock' : 'lock', seat: idx)));
    }
    if (actions.isEmpty) {
      if (locked) _toast('هذا الكرسي مقفل.');
      return;
    }
    if (actions.length == 1 && occupant == null && !control) {
      await actions.first.$3();
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s['name'] != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          for (var i = 0; i < actions.length; i++)
            ListTile(
              leading: Icon(actions[i].$2),
              title: Text(actions[i].$1),
              onTap: () => Navigator.pop(c, i),
            ),
        ]),
      ),
    );
    if (chosen != null) await actions[chosen].$3();
  }

  Future<void> _settings() async {
    final count = (_state?['seat_count'] as num?)?.toInt() ?? 8;
    final enabled = _state?['enabled'] == true;
    var newCount = count;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إعدادات المايك'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(child: Text('عدد الكراسي')),
              IconButton(
                  onPressed: newCount > 1 ? () => set(() => newCount--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$newCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              IconButton(
                  onPressed: newCount < 16 ? () => set(() => newCount++) : null,
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, enabled ? 'disable' : 'enable'),
              child: Text(enabled ? 'إيقاف المايك' : 'تشغيل المايك',
                  style: TextStyle(color: enabled ? Colors.redAccent : Colors.green)),
            ),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (r == 'save' && newCount != count) await _admin('set_count', value: newCount);
    if (r == 'enable' || r == 'disable') await _admin(r!);
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    if (st == null) return const SizedBox(height: 20);
    final control = st['can_control'] == true;
    if (st['enabled'] != true && !control) return const SizedBox(height: 20);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (control)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'إعدادات المايك',
              icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
              onPressed: _busy ? null : _settings,
            ),
          ),
        if (st['enabled'] != true)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('المايك متوقف', style: TextStyle(color: Colors.white54)),
          )
        else
          ValueListenableBuilder<Set<int>>(
            valueListenable: _voice.speaking,
            builder: (_, speaking, __) => Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [for (final s in _seats) _seat(s, speaking)],
            ),
          ),
      ]),
    );
  }

  Widget _seat(Map<String, dynamic> s, Set<int> speaking) {
    final occupant = s['user_id']?.toString();
    final locked = s['locked'] == true;
    final muted = s['muted'] == true || s['self_muted'] == true;
    final agoraUid = (s['agora_uid'] as num?)?.toInt();
    final isMe = occupant != null && occupant == _me;
    final talking = occupant != null && !muted &&
        ((isMe && speaking.contains(0)) || (agoraUid != null && speaking.contains(agoraUid)));
    final avatar = s['avatar']?.toString() ?? '';

    return GestureDetector(
      onTap: _busy ? null : () => _onSeatTap(s),
      child: SizedBox(
        width: 58,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .10),
                border: Border.all(
                    color: talking ? const Color(0xFF22C55E) : Colors.white24,
                    width: talking ? 3 : 1.2),
                boxShadow: talking
                    ? const [BoxShadow(color: Color(0x8822C55E), blurRadius: 12, spreadRadius: 2)]
                    : null,
                image: occupant != null && avatar.isNotEmpty
                    ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                    : null,
              ),
              child: occupant != null && avatar.isNotEmpty
                  ? null
                  : Icon(
                      locked ? Icons.lock_rounded : (occupant == null ? Icons.add_rounded : Icons.person),
                      color: Colors.white60,
                      size: 22),
            ),
            if (occupant != null && muted)
              const Positioned(
                bottom: -2,
                left: -2,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Color(0xFFEF4444),
                  child: Icon(Icons.mic_off, size: 11, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text(
            occupant != null ? (s['name']?.toString() ?? '') : '${(s['index'] as num).toInt() + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ]),
      ),
    );
  }
}

/// اتصال Agora للغرفة: مستمع افتراضيًا، ومتحدّث فقط حين يمنحه الخادم ذلك.
class _RoomVoice {
  RtcEngine? _engine;
  bool joined = false;
  bool publisher = false;
  int? uid;
  String? _roomId;
  final speaking = ValueNotifier<Set<int>>(<int>{});

  Future<Map<String, dynamic>> _token(String roomId) async {
    final res = await Supabase.instance.client.functions
        .invoke('agora-room-token', body: {'roomId': roomId});
    final data = res.data;
    if (data is! Map) throw StateError('ROOM_TOKEN_INVALID');
    if (data['error'] != null) throw StateError(data['error'].toString());
    return Map<String, dynamic>.from(data);
  }

  Future<void> join(String roomId) async {
    if (joined) return;
    _roomId = roomId;
    final t = await _token(roomId);
    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(
      appId: t['appId'].toString(),
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    engine.registerEventHandler(RtcEngineEventHandler(
      onTokenPrivilegeWillExpire: (_, __) async {
        final id = _roomId;
        if (id == null) return;
        try {
          final fresh = await _token(id);
          await engine.renewToken(fresh['token'].toString());
        } catch (_) {}
      },
      onAudioVolumeIndication: (_, speakers, __, ___) {
        speaking.value = {
          for (final s in speakers)
            if ((s.volume ?? 0) > 12 && s.uid != null) s.uid!,
        };
      },
    ));
    await engine.enableAudio();
    try {
      await engine.enableAudioVolumeIndication(interval: 400, smooth: 3, reportVad: true);
    } catch (_) {}
    publisher = t['publisher'] == true;
    uid = (t['uid'] as num?)?.toInt();
    await engine.joinChannel(
      token: t['token'].toString(),
      channelId: t['channel'].toString(),
      uid: uid ?? 0,
      options: ChannelMediaOptions(
        clientRoleType:
            publisher ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: publisher,
        autoSubscribeAudio: true,
      ),
    );
    joined = true;
  }

  /// يطلب رمزًا جديدًا يعكس الدور الحالي على الخادم، ثم يحدّث الدور محليًا.
  Future<void> refreshRole(String roomId) async {
    final engine = _engine;
    if (engine == null) return;
    final t = await _token(roomId);
    await engine.renewToken(t['token'].toString());
    publisher = t['publisher'] == true;
    await engine.updateChannelMediaOptions(ChannelMediaOptions(
      clientRoleType:
          publisher ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      publishMicrophoneTrack: publisher,
    ));
  }

  Future<void> setMuted(bool muted) async {
    try {
      await _engine?.muteLocalAudioStream(muted);
    } catch (_) {}
  }

  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    joined = false;
    publisher = false;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {}
  }
}
