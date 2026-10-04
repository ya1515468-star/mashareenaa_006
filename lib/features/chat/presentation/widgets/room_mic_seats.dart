import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';
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
  bool _isOwner = false;

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
    _db.rpc('is_my_platform_owner').then((v) {
      if (mounted) setState(() => _isOwner = v == true);
    }).catchError((_) {});
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
      }
      // سجّل معرّف Agora الحالي على الخادم حتى لو بدأ المستخدم بالفعل
      // كمتحدّث عند أول تحميل الشاشة؛ من دون ذلك يبقى agora_uid فارغًا
      // ولا يستطيع مؤشر "يتحدث الآن" مطابقة متحدثي Agora بالكرسي.
      if (_voice.publisher && _voice.uid != null && mine != null) {
        unawaited(_db.rpc('set_my_mic_agora_uid',
            params: {'p_room': widget.roomId, 'p_agora_uid': _voice.uid}));
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
    if (t.contains('INSUFFICIENT_GEMS')) return 'رصيدك من الجواهر لا يكفي للصعود.';
    if (t.contains('INSUFFICIENT_POINTS')) return 'رصيدك من النقاط لا يكفي للصعود.';
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
    // السعر يُفرض ويُحصَّل خادميًا في take_mic_seat؛ هذا عرض واضح قبل الضغط
    // فقط. لا يُسأل من كان جالسًا أصلًا (النقل مجاني) ولا المالك.
    if (_mySeat == null && !_isOwner) {
      try {
        final price = await _db.from('mic_seat_pricing').select().maybeSingle();
        if (price != null && price['is_enabled'] == true) {
          final gems = (price['gems_cost'] as num?)?.toInt() ?? 0;
          final points = (price['points_cost'] as num?)?.toInt() ?? 0;
          if (!mounted) return;
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('الصعود إلى المايك'),
              content: Text(gems > 0
                  ? 'سيُخصم $gems جوهرة من رصيدك عند كل صعود.'
                  : 'سيُخصم $points نقطة من رصيدك عند كل صعود.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('ادفع واصعد')),
              ],
            ),
          );
          if (ok != true) return;
        }
      } catch (_) {}
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

  /// سعر الصعود للمايك (المالك فقط): بالجواهر أو النقاط، بلا مدة زمنية،
  /// ودائم حتى يغيّره المالك. يُحصَّل خادميًا داخل take_mic_seat.
  Future<void> _editPrice() async {
    Map<String, dynamic>? cur;
    try {
      cur = await _db.from('mic_seat_pricing').select().maybeSingle();
    } catch (_) {}
    final gems = TextEditingController(text: '${cur?['gems_cost'] ?? 0}');
    final points = TextEditingController(text: '${cur?['points_cost'] ?? 0}');
    var enabled = cur?['is_enabled'] == true;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: const Text('سعر الصعود إلى المايك'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل الدفع عند كل صعود'),
              value: enabled,
              onChanged: (v) => setLocal(() => enabled = v),
            ),
            TextField(controller: gems, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'جواهر 💎')),
            TextField(controller: points, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'نقاط ⭐ (تُستعمل إن كانت الجواهر 0)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _rpc('owner_set_mic_seat_pricing', {
        'p_enabled': enabled,
        'p_points_cost': int.tryParse(points.text.trim()) ?? 0,
        'p_gems_cost': int.tryParse(gems.text.trim()) ?? 0,
      });
    }
    gems.dispose();
    points.dispose();
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
            if (_isOwner)
              TextButton(
                onPressed: () => Navigator.pop(c, 'price'),
                child: const Text('سعر الصعود'),
              ),
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
    if (r == 'price') {
      await _editPrice();
      return;
    }
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
        (agoraUid != null && speaking.contains(agoraUid));
    final avatar = s['avatar']?.toString() ?? '';

    return GestureDetector(
      onTap: _busy ? null : () => _onSeatTap(s),
      child: SizedBox(
        width: 58,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            // البند ٦: كانت الصورة هنا دائرة عادية بلا أي إطار ملوّن، رغم
            // أن نفس العضو يظهر بإطاره في كل مكان آخر بالغرفة. مؤشر
            // "يتحدث الآن" الأخضر يبقى طبقة خارجية مستقلة حول الإطار.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: talking ? const Color(0xFF22C55E) : Colors.transparent,
                    width: talking ? 3 : 0),
                boxShadow: talking
                    ? const [BoxShadow(color: Color(0x8822C55E), blurRadius: 12, spreadRadius: 2)]
                    : null,
              ),
              child: occupant != null
                  ? DynamicAvatarFrame(
                      frameKey: s['avatar_frame_key']?.toString(),
                      userId: occupant,
                      radius: 24,
                      child: avatar.isNotEmpty
                          ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatar))
                          : const CircleAvatar(radius: 24, child: Icon(Icons.person, color: Colors.white60)),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .10),
                      ),
                      child: Icon(
                          locked ? Icons.lock_rounded : Icons.add_rounded,
                          color: Colors.white60,
                          size: 22),
                    ),
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
            if (isMe)
              Positioned(
                top: -4,
                right: -4,
                child: _SeatQuickButton(
                  icon: s['muted'] == true
                      ? Icons.volume_off_rounded
                      : (s['self_muted'] == true ? Icons.mic_off_rounded : Icons.mic_rounded),
                  color: s['muted'] == true
                      ? const Color(0xFFE11D48)
                      : (s['self_muted'] == true ? const Color(0xFFE11D48) : const Color(0xFF16A34A)),
                  onTap: _busy || s['muted'] == true
                      ? null
                      : () => _rpc('set_my_mic_muted', {
                            'p_room': widget.roomId,
                            'p_muted': s['self_muted'] != true,
                          }),
                ),
              )
            else if (control && occupant != null)
              Positioned(
                top: -4,
                right: -4,
                child: _SeatQuickButton(
                  icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: muted ? const Color(0xFFE11D48) : const Color(0xFF7C3AED),
                  onTap: _busy ? null : () => _rpc('room_mic_admin', {
                    'p_room': widget.roomId,
                    'p_action': muted ? 'unmute' : 'mute',
                    'p_seat': (s['index'] as num).toInt(),
                  }),
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


class _SeatQuickButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _SeatQuickButton({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 22, height: 22, child: Icon(icon, color: Colors.white, size: 12)),
        ),
      );
}
