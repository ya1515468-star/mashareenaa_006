import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/snack_sfx.dart';
import 'game_hub.dart' show gameErrorText, gameTitle, sendGameChallengeFlow;

/// نظام الدعوات: ادعُ أي عضو لأي لعبة (الخادم يتحقق من الحظر والرصيد والحد
/// الأقصى 5 دعوات معلّقة ومهلة 10 دقائق)، وأدر دعواتك الواردة والصادرة.
SupabaseClient get _idb => Supabase.instance.client;

const List<String> _inviteGames = [
  'connect4',
  'rps',
  'coin',
  'dice',
  'trix_solo',
  'trix_partner',
];

String _emoji(String t) {
  switch (t) {
    case 'connect4':
      return '🔴';
    case 'rps':
      return '✊';
    case 'coin':
      return '🪙';
    case 'dice':
      return '🎲';
    default:
      return '🧵';
  }
}

Future<void> showGameInvites(BuildContext context,
    {String? roomId,
    Future<void> Function(Map<String, dynamic>)? onIncoming}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF171126),
    showDragHandle: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    builder: (sheet) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [
            Tab(text: 'دعوة جديدة'),
            Tab(text: 'دعواتي'),
          ]),
          Expanded(
            child: TabBarView(children: [
              _NewInviteTab(roomId: roomId),
              _MyInvitesTab(
                  sheetContext: sheet, onIncoming: onIncoming),
            ]),
          ),
        ]),
      ),
    ),
  );
}

class _NewInviteTab extends StatefulWidget {
  final String? roomId;
  const _NewInviteTab({this.roomId});
  @override
  State<_NewInviteTab> createState() => _NewInviteTabState();
}

class _NewInviteTabState extends State<_NewInviteTab> {
  String _game = 'connect4';
  final _q = TextEditingController();
  Timer? _deb;
  List<Map<String, dynamic>> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    try {
      final raw =
          await _idb.rpc('search_game_players', params: {'p_query': _q.text});
      if (raw is List && mounted) {
        setState(() {
          _players =
              raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              for (final g in _inviteGames)
                ChoiceChip(
                  label: Text('${_emoji(g)} ${gameTitle(g)}'),
                  selected: _game == g,
                  onSelected: (_) => setState(() => _game = g),
                ),
            ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: _q,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'ابحث عن لاعب بالاسم…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true),
          onChanged: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 350), _search);
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _players.isEmpty
                ? const Center(
                    child: Text('لا يوجد لاعبون مطابقون',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _players.length,
                    itemBuilder: (c, i) {
                      final p = _players[i];
                      final online = p['online'] == true;
                      final url = p['avatar_url']?.toString();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: (url != null && url.isNotEmpty)
                              ? NetworkImage(url)
                              : null,
                          child: (url == null || url.isEmpty)
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        title: Text(p['name'].toString(),
                            style: const TextStyle(color: Colors.white),
                            textDirection: TextDirection.rtl),
                        subtitle: Text(online ? 'متصل الآن' : 'غير متصل',
                            style: TextStyle(
                                color: online
                                    ? const Color(0xFFA5D6A7)
                                    : Colors.white38,
                                fontSize: 11),
                            textDirection: TextDirection.rtl),
                        trailing: const Icon(Icons.send_rounded,
                            color: Color(0xFFFFD54F), size: 18),
                        onTap: () => sendGameChallengeFlow(context,
                            toUid: p['id'].toString(),
                            gameType: _game,
                            roomId: widget.roomId),
                      );
                    },
                  ),
      ),
    ]);
  }
}

class _MyInvitesTab extends StatefulWidget {
  final BuildContext sheetContext;
  final Future<void> Function(Map<String, dynamic>)? onIncoming;
  const _MyInvitesTab({required this.sheetContext, this.onIncoming});
  @override
  State<_MyInvitesTab> createState() => _MyInvitesTabState();
}

class _MyInvitesTabState extends State<_MyInvitesTab> {
  List<Map<String, dynamic>> _rows = [];
  Timer? _t;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _idb.rpc('my_game_invites');
      if (raw is List && mounted) {
        setState(() {
          _rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() f) async {
    final m = ScaffoldMessenger.of(context);
    try {
      await f();
      await _load();
    } catch (e) {
      m.showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) {
      return const Center(
          child: Text('لا توجد دعوات معلّقة',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (c, i) {
        final r = _rows[i];
        final incoming = r['direction'] == 'in';
        final type = r['game_type'].toString();
        final stake = (r['stake'] as num?)?.toInt() ?? 0;
        return ListTile(
          dense: true,
          leading: Text(_emoji(type), style: const TextStyle(fontSize: 24)),
          title: Text(
              '${incoming ? 'من' : 'إلى'} ${r['other_name']} — ${gameTitle(type)}',
              style: const TextStyle(color: Colors.white),
              textDirection: TextDirection.rtl),
          subtitle: Text(stake > 0 ? 'رهان $stake نقطة' : 'ودّي',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textDirection: TextDirection.rtl),
          trailing: incoming
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'رفض',
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    onPressed: () => _act(() async {
                      await _idb.rpc(
                          type == 'dice'
                              ? 'decline_dice_challenge'
                              : 'decline_game_request',
                          params: {'p_request_id': r['id']});
                    }),
                  ),
                  IconButton(
                    tooltip: 'قبول',
                    icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
                    onPressed: () async {
                      final cb = widget.onIncoming;
                      Navigator.of(widget.sheetContext).pop();
                      if (cb != null) {
                        await cb({
                          'id': r['id'],
                          'game_type': type,
                          'stake_points': stake,
                          'from_uid': r['other_uid'],
                          'status': 'pending',
                        });
                      }
                    },
                  ),
                ])
              : TextButton(
                  onPressed: () => _act(() async {
                    await _idb.rpc('cancel_game_request',
                        params: {'p_request_id': r['id']});
                  }),
                  child: const Text('إلغاء')),
        );
      },
    );
  }
}
