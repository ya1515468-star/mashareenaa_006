import 'dart:async';
import '../../../../core/services/snack_sfx.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/server_sounds.dart';
import 'game_invites.dart';
import 'trix_game.dart';

/// مركز الألعاب: أربعة في صف، حجر ورقة مقص، العملة — كلها ثلاثية الأبعاد.
/// - ضد الكمبيوتر: تدريب محلي بلا نقاط (لا رهان أمام آلة).
/// - ضد لاعب حقيقي: طلب ← قبول/رفض ← يدخل الطرفان اللعبة. كل حركة وكل
///   نتيجة وكل خصم/ربح نقاط تُحسم في الخادم حصرًا (game_matches).
SupabaseClient get _db => Supabase.instance.client;

const Color _bg = Color(0xFF120C20);

String gameTitle(String type) {
  switch (type) {
    case 'connect4':
      return 'أربعة في صف';
    case 'rps':
      return 'حجر ورقة مقص';
    case 'coin':
      return 'العملة';
    case 'dice':
      return 'النرد';
    case 'trix_solo':
    case 'trix_partner':
      return trixTitle(type);
    default:
      return 'لعبة';
  }
}

String gameErrorText(Object e) {
  final raw = e.toString();
  if (raw.contains('CHALLENGER_INSUFFICIENT_POINTS')) {
    return 'رصيد المتحدّي لا يكفي لهذا الرهان.';
  }
  if (raw.contains('INSUFFICIENT_POINTS')) return 'رصيدك من النقاط لا يكفي.';
  if (raw.contains('REQUEST_ALREADY_PENDING')) {
    return 'لديك طلب معلّق لهذا العضو بالفعل.';
  }
  if (raw.contains('REQUEST_EXPIRED')) return 'انتهت صلاحية الطلب.';
  if (raw.contains('REQUEST_NOT_PENDING')) return 'الطلب لم يعد متاحًا.';
  if (raw.contains('ALREADY_IN_GAME')) return 'لديك مباراة تركس جارية بالفعل.';
  if (raw.contains('TOO_MANY_INVITES')) {
    return 'لديك 5 دعوات معلّقة؛ انتظر الرد أو ألغِ بعضها.';
  }
  if (raw.contains('BLOCKED')) return 'غير ممكن بسبب الحظر.';
  if (raw.contains('NOT_YOUR_TURN')) return 'ليس دورك الآن.';
  if (raw.contains('COLUMN_FULL')) return 'هذا العمود ممتلئ.';
  if (raw.contains('MATCH_FINISHED')) return 'انتهت المباراة.';
  if (raw.contains('ALREADY_PICKED')) return 'اخترت بالفعل في هذه الجولة.';
  return 'تعذّر تنفيذ العملية.';
}

// ───────────────────────── الطلبات ─────────────────────────

Future<int?> pickGameStake(BuildContext context, String gameType) {
  const stakes = [0, 10, 50, 100, 500, 1000];
  return showDialog<int>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text('${gameTitle(gameType)} — اختر الرهان',
          textDirection: TextDirection.rtl),
      children: [
        for (final s in stakes)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, s),
            child: Text(
              s == 0
                  ? 'ودّي (بلا نقاط)'
                  : '$s نقطة — الفائز يربح $s من الخاسر',
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    ),
  );
}

/// اختيار وجه العملة (صورة/كتابة) قبل إرسال التحدي.
Future<String?> pickCoinSide(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('اختر وجهك', textDirection: TextDirection.rtl),
      children: [
        SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'heads'),
            child: const Text('👑 صورة', textDirection: TextDirection.rtl)),
        SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'tails'),
            child: const Text('✦ كتابة', textDirection: TextDirection.rtl)),
      ],
    ),
  );
}

/// يرسل تحدّي لعبة بعد اختيار الرهان. يعيد true عند الإرسال.
Future<bool> sendGameChallengeFlow(
  BuildContext context, {
  required String toUid,
  required String gameType,
  String? roomId,
}) async {
  final stake = await pickGameStake(context, gameType);
  if (stake == null || !context.mounted) return false;
  String? side;
  if (gameType == 'coin') {
    side = await pickCoinSide(context);
    if (side == null || !context.mounted) return false;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    await _db.rpc('send_game_invite', params: {
      'p_to_uid': toUid,
      'p_game_type': gameType,
      'p_stake': stake,
      'p_room_id': roomId,
      'p_side': side,
    });
    messenger.showSnackBarSfx(SnackBar(
        content: Text(stake > 0
            ? 'تم إرسال تحدي ${gameTitle(gameType)} على $stake نقطة ✓'
            : 'تم إرسال تحدي ${gameTitle(gameType)} ✓')));
    return true;
  } catch (e) {
    messenger.showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    return false;
  }
}

final Set<String> _promptedRequests = <String>{};

/// يسمح بعرض نافذة القبول لطلب سبق عرضه (من قائمة دعواتي).
void forgetPromptedGameRequest(String? id) {
  if (id != null) _promptedRequests.remove(id);
}

/// نافذة قبول/رفض لطلب لعبة وارد (أربعة في صف / مقص / عملة).
Future<void> promptGameRequest(
    BuildContext context, Map<String, dynamic> req) async {
  final type = req['game_type']?.toString() ?? '';
  if (!const ['connect4', 'rps', 'coin', 'trix_solo', 'trix_partner']
      .contains(type)) {
    return;
  }
  if (req['status']?.toString() != 'pending') return;
  final reqId = req['id']?.toString();
  if (reqId == null || !_promptedRequests.add(reqId)) return;
  final stake = (req['stake_points'] as num?)?.toInt() ?? 0;
  var fromName = 'عضو';
  try {
    final row = await _db
        .from('profiles')
        .select('display_name,username')
        .eq('id', req['from_uid'].toString())
        .maybeSingle();
    final n = (row?['display_name'] ?? row?['username'])?.toString().trim();
    if (n != null && n.isNotEmpty) fromName = n;
  } catch (_) {}
  if (!context.mounted) return;
  playServerSound('game_request');
  final accept = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text('طلب لعبة — ${gameTitle(type)}',
          textDirection: TextDirection.rtl),
      content: Text(
        stake > 0
            ? '$fromName يتحداك في ${gameTitle(type)} على $stake نقطة.\nالفائز يربح $stake من الخاسر، والتعادل بلا تغيير.'
            : '$fromName يدعوك للعب ${gameTitle(type)} (ودّي بلا نقاط).',
        textDirection: TextDirection.rtl,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('رفض')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('قبول والدخول')),
      ],
    ),
  );
  if (accept == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (!accept) {
      await _db.rpc('decline_game_request', params: {'p_request_id': reqId});
      return;
    }
    final matchId =
        await _db.rpc('accept_game_request', params: {'p_request_id': reqId});
    if (!context.mounted) return;
    if (type.startsWith('trix_')) {
      await openTrixGame(context, matchId.toString());
    } else {
      await openGameMatch(context, matchId.toString());
    }
  } catch (e) {
    messenger.showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
  }
}

final Set<String> _openMatches = <String>{};

Future<void> openGameMatch(BuildContext context, String matchId) async {
  if (!_openMatches.add(matchId)) return;
  playServerSound('game_start');
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => GameMatchDialog(matchId: matchId),
    );
  } finally {
    _openMatches.remove(matchId);
  }
}

// ───────────────────────── الألعاب ضد الكمبيوتر ─────────────────────────

Future<void> showGameHub(BuildContext context,
    {String? roomId,
    Future<void> Function(Map<String, dynamic>)? onIncoming}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF171126),
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ألعاب ثلاثية الأبعاد',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'ضد الكمبيوتر هنا (تدريب بلا نقاط). للعب ضد لاعب حقيقي برهان نقاط: اضغط صورته ← طلب لعبة.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            leading: const Text('♠♥♦♣', style: TextStyle(fontSize: 15, letterSpacing: 0)),
            title: const Text('تركس سوري',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(sheetContext);
              showTrixLauncher(context);
            },
          ),
          ListTile(
            dense: true,
            leading: const Text('📨', style: TextStyle(fontSize: 26)),
            title: const Text('دعوة لاعب / دعواتي',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(sheetContext);
              showGameInvites(context, roomId: roomId, onIncoming: onIncoming);
            },
          ),
          for (final t in const ['connect4', 'rps', 'coin'])
            ListTile(
              dense: true,
              leading: Text(
                  t == 'connect4' ? '🔴' : (t == 'rps' ? '✊' : '🪙'),
                  style: const TextStyle(fontSize: 26)),
              title: Text(gameTitle(t),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                openPractice(context, t);
              },
            ),
        ]),
      ),
    ),
  );
}

Future<void> openPractice(BuildContext context, String type) {
  Widget body;
  if (type == 'connect4') {
    body = const _Connect4Practice();
  } else if (type == 'rps') {
    body = const _RpsPractice();
  } else {
    body = const _CoinPractice();
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _GameShell(
      title: '${gameTitle(type)} — ضد الكمبيوتر',
      child: body,
    ),
  );
}

class _GameShell extends StatelessWidget {
  final String title;
  final Widget child;
  final String? chip;
  final Widget? trailing;
  const _GameShell(
      {required this.title, required this.child, this.chip, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x66FFC107))),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70)),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 48),
            ]),
            if (chip != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0x33FFC107),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(chip!,
                    style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            Flexible(child: SingleChildScrollView(child: child)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── أربعة في صف ─────────────────────────

const int _cols = 7;
const int _rows = 6;

List<int>? _c4Drop(List<int> b, int col, int p) {
  for (var r = _rows - 1; r >= 0; r--) {
    if (b[r * _cols + col] == 0) {
      final nb = List<int>.from(b);
      nb[r * _cols + col] = p;
      return nb;
    }
  }
  return null;
}

/// يعيد خلايا الرباعي الفائز (أول خلية تحدد اللاعب) أو null.
List<int>? _c4WinCells(List<int> b) {
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1]
  ];
  for (var r = 0; r < _rows; r++) {
    for (var c = 0; c < _cols; c++) {
      final p = b[r * _cols + c];
      if (p == 0) continue;
      for (final d in dirs) {
        final cells = <int>[r * _cols + c];
        for (var k = 1; k < 4; k++) {
          final nr = r + d[0] * k;
          final nc = c + d[1] * k;
          if (nr < 0 || nr >= _rows || nc < 0 || nc >= _cols) break;
          if (b[nr * _cols + nc] != p) break;
          cells.add(nr * _cols + nc);
        }
        if (cells.length == 4) return cells;
      }
    }
  }
  return null;
}

int _c4Eval(List<int> b, int p) {
  final o = 3 - p;
  var s = 0;
  for (var r = 0; r < _rows; r++) {
    final v = b[r * _cols + 3];
    if (v == p) s += 3;
    if (v == o) s -= 3;
  }
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1]
  ];
  for (var r = 0; r < _rows; r++) {
    for (var c = 0; c < _cols; c++) {
      for (final d in dirs) {
        final er = r + d[0] * 3;
        final ec = c + d[1] * 3;
        if (er < 0 || er >= _rows || ec < 0 || ec >= _cols) continue;
        var mine = 0, theirs = 0, empty = 0;
        for (var k = 0; k < 4; k++) {
          final v = b[(r + d[0] * k) * _cols + c + d[1] * k];
          if (v == p) {
            mine++;
          } else if (v == o) {
            theirs++;
          } else {
            empty++;
          }
        }
        if (mine == 3 && empty == 1) s += 6;
        if (mine == 2 && empty == 2) s += 2;
        if (theirs == 3 && empty == 1) s -= 5;
      }
    }
  }
  return s;
}

int _c4Negamax(List<int> b, int depth, int alpha, int beta, int p) {
  final w = _c4WinCells(b);
  if (w != null) return b[w.first] == p ? 100000 + depth : -(100000 + depth);
  if (!b.contains(0)) return 0;
  if (depth == 0) return _c4Eval(b, p);
  var best = -1000000000;
  for (final col in const [3, 2, 4, 1, 5, 0, 6]) {
    final nb = _c4Drop(b, col, p);
    if (nb == null) continue;
    final v = -_c4Negamax(nb, depth - 1, -beta, -alpha, 3 - p);
    if (v > best) best = v;
    if (v > alpha) alpha = v;
    if (alpha >= beta) break;
  }
  return best;
}

int _c4ComputerMove(List<int> b, int p) {
  var bestCol = 3;
  var bestVal = -1000000000;
  for (final col in const [3, 2, 4, 1, 5, 0, 6]) {
    final nb = _c4Drop(b, col, p);
    if (nb == null) continue;
    final v = -_c4Negamax(nb, 4, -1000000000, 1000000000, 3 - p);
    if (v > bestVal) {
      bestVal = v;
      bestCol = col;
    }
  }
  return bestCol;
}

class Connect4BoardView extends StatelessWidget {
  final List<int> board;
  final List<int> winCells;
  final int? lastIdx;
  final bool enabled;
  final void Function(int col)? onColumn;
  const Connect4BoardView({
    super.key,
    required this.board,
    this.winCells = const [],
    this.lastIdx,
    this.enabled = false,
    this.onColumn,
  });

  static const _red = [Color(0xFFFF8A80), Color(0xFFE53935), Color(0xFF8E0000)];
  static const _yellow = [
    Color(0xFFFFF59D),
    Color(0xFFFFC107),
    Color(0xFF9A6A00)
  ];

  Widget _disc(int v, double size, bool win) {
    final cols = v == 1 ? _red : _yellow;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: cols,
        ),
        border: win ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: [
          BoxShadow(
              color: win ? Colors.white54 : Colors.black45,
              blurRadius: win ? 10 : 5,
              offset: const Offset(0, 3)),
        ],
      ),
    );
  }

  Widget _cell(int idx, double cell) {
    final v = board[idx];
    final inner = cell - 8;
    final hole = Container(
      width: inner,
      height: inner,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050A1F), Color(0xFF1B2A63)],
        ),
      ),
    );
    Widget content = hole;
    if (v != 0) {
      Widget disc = _disc(v, inner, winCells.contains(idx));
      if (idx == lastIdx) {
        final row = idx ~/ _cols;
        disc = TweenAnimationBuilder<double>(
          key: ValueKey('drop-$idx-$v'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 560),
          curve: Curves.bounceOut,
          onEnd: () => playServerSound('disc_drop'),
          builder: (_, t, child) => Transform.translate(
              offset: Offset(0, -(1 - t) * (row + 1.6) * cell), child: child),
          child: disc,
        );
      }
      content = Stack(alignment: Alignment.center, children: [hole, disc]);
    }
    return SizedBox(
        width: cell, height: cell, child: Center(child: content));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final avail = cons.maxWidth.isFinite ? cons.maxWidth : 360.0;
      final cell = math.min((avail - 36) / _cols, 52.0);
      final w = cell * _cols + 24;
      final h = cell * _rows + 24;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateX(-0.38),
            child: SizedBox(
              width: w,
              height: h + 16,
              child: Stack(clipBehavior: Clip.none, children: [
                // سماكة اللوحة (الجانب السفلي)
                Positioned(
                  left: 0,
                  top: 16,
                  child: Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1450),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black87,
                            blurRadius: 18,
                            offset: Offset(0, 14)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: w + 2,
                    height: h + 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3F5FD6), Color(0xFF1E3A9E)],
                      ),
                      border: Border.all(color: const Color(0xFF7E96F0)),
                    ),
                    child: Row(children: [
                      for (var c = 0; c < _cols; c++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: enabled && onColumn != null
                              ? () => onColumn!(c)
                              : null,
                          child: Column(children: [
                            for (var r = 0; r < _rows; r++)
                              _cell(r * _cols + c, cell),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _Connect4Practice extends StatefulWidget {
  const _Connect4Practice();
  @override
  State<_Connect4Practice> createState() => _Connect4PracticeState();
}

class _Connect4PracticeState extends State<_Connect4Practice> {
  List<int> board = List<int>.filled(_rows * _cols, 0);
  int? last;
  bool playerTurn = true;
  String status = 'دورك — أنت الأحمر';
  List<int> win = const [];
  bool over = false;

  void _afterMove(List<int> nb, int idx, int p) {
    final w = _c4WinCells(nb);
    setState(() {
      board = nb;
      last = idx;
      if (w != null) {
        win = w;
        over = true;
        status = p == 1 ? '🎉 فزت!' : '😅 فاز الكمبيوتر';
        Future.delayed(const Duration(milliseconds: 700),
            () => playServerSound(p == 1 ? 'game_win' : 'game_lose'));
      } else if (!nb.contains(0)) {
        over = true;
        status = 'تعادل';
        Future.delayed(const Duration(milliseconds: 700),
            () => playServerSound('game_draw'));
      }
    });
  }

  int _landingIndex(List<int> before, List<int> after) {
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) return i;
    }
    return 0;
  }

  void _tap(int col) {
    if (!playerTurn || over) return;
    final nb = _c4Drop(board, col, 1);
    if (nb == null) return;
    final idx = _landingIndex(board, nb);
    playerTurn = false;
    _afterMove(nb, idx, 1);
    if (over) return;
    setState(() => status = 'الكمبيوتر يفكر…');
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final col2 = _c4ComputerMove(board, 2);
      final nb2 = _c4Drop(board, col2, 2);
      if (nb2 == null) return;
      final idx2 = _landingIndex(board, nb2);
      _afterMove(nb2, idx2, 2);
      if (!over) {
        setState(() {
          playerTurn = true;
          status = 'دورك — أنت الأحمر';
        });
      }
    });
  }

  void _reset() => setState(() {
        board = List<int>.filled(_rows * _cols, 0);
        last = null;
        win = const [];
        over = false;
        playerTurn = true;
        status = 'دورك — أنت الأحمر';
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(status,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      Connect4BoardView(
          board: board,
          winCells: win,
          lastIdx: last,
          enabled: playerTurn && !over,
          onColumn: _tap),
      if (over)
        FilledButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('جولة جديدة')),
    ]);
  }
}

// ───────────────────────── حجر ورقة مقص ─────────────────────────

const Map<String, String> _rpsEmoji = {
  'rock': '✊',
  'paper': '✋',
  'scissors': '✌️',
};
const Map<String, String> _rpsName = {
  'rock': 'حجر',
  'paper': 'ورقة',
  'scissors': 'مقص',
};

class RpsArena extends StatefulWidget {
  final String myName;
  final String oppName;
  final int myScore;
  final int oppScore;
  final int round;
  final String? myLast;
  final String? oppLast;
  final String banner;
  final bool canPick;
  final void Function(String choice) onPick;
  const RpsArena({
    super.key,
    required this.myName,
    required this.oppName,
    required this.myScore,
    required this.oppScore,
    required this.round,
    required this.myLast,
    required this.oppLast,
    required this.banner,
    required this.canPick,
    required this.onPick,
  });

  @override
  State<RpsArena> createState() => _RpsArenaState();
}

class _RpsArenaState extends State<RpsArena>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  Widget _hand(String? pick, String keyId, {bool sound = false}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('hand-$keyId-$pick'),
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      onEnd: () {
        if (sound && pick != null) playServerSound('rps_reveal');
      },
      builder: (_, t, __) {
        final angle = t * math.pi;
        final showFace = angle < math.pi / 2 && pick != null;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(angle),
          child: Container(
            width: 84,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B2A6B), Color(0xFF1B1238)]),
              border: Border.all(color: const Color(0x88FFC107)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 10, offset: Offset(0, 6))
              ],
            ),
            child: Text(showFace ? _rpsEmoji[pick] ?? '❔' : '❔',
                style: const TextStyle(fontSize: 44)),
          ),
        );
      },
    );
  }

  Widget _pickButton(String choice, int i) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (_, __) {
        final phase = _idle.value * 2 - 1;
        return GestureDetector(
          onTap: widget.canPick ? () => widget.onPick(choice) : null,
          child: Opacity(
            opacity: widget.canPick ? 1 : 0.4,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(phase * 0.45 * (i.isEven ? 1 : -1))
                ..rotateX(-0.25),
              child: Container(
                width: 82,
                height: 98,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8E6BFF), Color(0xFF4B2BB0)]),
                  border: Border.all(color: Colors.white38),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 8))
                  ],
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_rpsEmoji[choice]!,
                          style: const TextStyle(fontSize: 38)),
                      const SizedBox(height: 4),
                      Text(_rpsName[choice]!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ]),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [
          Text(widget.myName,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${widget.myScore}',
              style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
        ]),
        Text('الجولة ${widget.round}',
            style: const TextStyle(color: Colors.white54)),
        Column(children: [
          Text(widget.oppName,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${widget.oppScore}',
              style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
        ]),
      ]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _hand(widget.myLast, 'me${widget.round}'),
        const Text('VS',
            style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        _hand(widget.oppLast, 'op${widget.round}', sound: true),
      ]),
      const SizedBox(height: 12),
      Text(widget.banner,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _pickButton('rock', 0),
        _pickButton('paper', 1),
        _pickButton('scissors', 2),
      ]),
      const SizedBox(height: 10),
    ]);
  }
}

int _rpsResult(String a, String b) {
  if (a == b) return 0;
  if ((a == 'rock' && b == 'scissors') ||
      (a == 'paper' && b == 'rock') ||
      (a == 'scissors' && b == 'paper')) {
    return 1;
  }
  return 2;
}

class _RpsPractice extends StatefulWidget {
  const _RpsPractice();
  @override
  State<_RpsPractice> createState() => _RpsPracticeState();
}

class _RpsPracticeState extends State<_RpsPractice> {
  int me = 0, cpu = 0, round = 1;
  String? myLast, cpuLast;
  String banner = 'اختر: حجر أم ورقة أم مقص؟ (الأول إلى فوزين)';
  bool over = false;
  final _rnd = math.Random();

  void _pick(String c) {
    if (over) return;
    final o = const ['rock', 'paper', 'scissors'][_rnd.nextInt(3)];
    final r = _rpsResult(c, o);
    setState(() {
      myLast = c;
      cpuLast = o;
      if (r == 1) me++;
      if (r == 2) cpu++;
      if (me >= 2 || cpu >= 2) {
        over = true;
        banner = me >= 2 ? '🎉 فزت بالمباراة!' : '😅 فاز الكمبيوتر بالمباراة';
        Future.delayed(const Duration(milliseconds: 800),
            () => playServerSound(me >= 2 ? 'game_win' : 'game_lose'));
      } else {
        banner = r == 0
            ? 'تعادل — أعد الجولة'
            : (r == 1 ? 'ربحت هذه الجولة ✓' : 'خسرت هذه الجولة');
        round++;
      }
    });
  }

  void _reset() => setState(() {
        me = 0;
        cpu = 0;
        round = 1;
        myLast = null;
        cpuLast = null;
        over = false;
        banner = 'اختر: حجر أم ورقة أم مقص؟ (الأول إلى فوزين)';
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RpsArena(
        myName: 'أنت',
        oppName: 'الكمبيوتر',
        myScore: me,
        oppScore: cpu,
        round: round,
        myLast: myLast,
        oppLast: cpuLast,
        banner: banner,
        canPick: !over,
        onPick: _pick,
      ),
      if (over)
        FilledButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('مباراة جديدة')),
    ]);
  }
}

// ───────────────────────── العملة ─────────────────────────

class Coin3D extends StatelessWidget {
  /// زاوية الدوران حول المحور الأفقي بالراديان؛ 0 = صورة، π = كتابة.
  final double angle;
  final double size;
  const Coin3D({super.key, required this.angle, this.size = 130});

  Widget _disc({required bool face, required bool heads}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.0,
          colors: face
              ? const [Color(0xFFFFF3B0), Color(0xFFFFC107), Color(0xFFB77900)]
              : const [Color(0xFFB77900), Color(0xFF8A5A00), Color(0xFF5E3C00)],
        ),
        border: Border.all(color: const Color(0xFF8A5A00), width: 3),
      ),
      child: face
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Text(heads ? '👑' : '✦',
                  style: TextStyle(fontSize: size * 0.34)),
              Text(heads ? 'صورة' : 'كتابة',
                  style: TextStyle(
                      color: const Color(0xFF6B4500),
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.14)),
            ])
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(0.3)
      ..rotateX(angle);
    final c = math.cos(angle);
    final layers = <Widget>[];
    for (var i = -4; i <= 4; i++) {
      layers.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)..translate(0.0, 0.0, i * 1.5),
        child: _disc(face: false, heads: true),
      ));
    }
    if (c > 0.04) {
      layers.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)..translate(0.0, 0.0, 7.0),
        child: _disc(face: true, heads: true),
      ));
    } else if (c < -0.04) {
      layers.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)
          ..rotateX(math.pi)
          ..translate(0.0, 0.0, 7.0),
        child: _disc(face: true, heads: false),
      ));
    }
    final lift = math.sin((angle / (math.pi * 10)).clamp(0.0, 1.0) * math.pi) *
        size *
        0.9;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.9,
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          bottom: size * 0.1,
          child: Container(
            width: size * 0.8 * (1 - lift / (size * 2)),
            height: size * 0.12,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.black38,
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)]),
          ),
        ),
        Transform.translate(offset: Offset(0, -lift * 0.5), child: Stack(alignment: Alignment.center, children: layers)),
      ]),
    );
  }
}

class _CoinFlipper extends StatefulWidget {
  /// 'heads' أو 'tails' — النتيجة المحسومة مسبقًا (من الخادم أو محليًا للتدريب).
  final String resultSide;
  final VoidCallback? onDone;
  const _CoinFlipper({required this.resultSide, this.onDone, super.key});
  @override
  State<_CoinFlipper> createState() => _CoinFlipperState();
}

class _CoinFlipperState extends State<_CoinFlipper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        playServerSound('coin_land');
        widget.onDone?.call();
      }
    })
    ..forward();

  @override
  void initState() {
    super.initState();
    playServerSound('coin_flip');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = math.pi * 10 + (widget.resultSide == 'tails' ? math.pi : 0);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Coin3D(
          angle: Curves.easeOutCubic.transform(_c.value) * end, size: 120),
    );
  }
}

class _CoinPractice extends StatefulWidget {
  const _CoinPractice();
  @override
  State<_CoinPractice> createState() => _CoinPracticeState();
}

class _CoinPracticeState extends State<_CoinPractice> {
  String? mine;
  String? result;
  bool done = false;
  int run = 0;

  void _flip(String pick) {
    setState(() {
      mine = pick;
      result = math.Random().nextBool() ? 'heads' : 'tails';
      done = false;
      run++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (result == null)
        const SizedBox(
            height: 220,
            child: Center(
                child: Text('اختر وجه العملة ثم ستُرمى',
                    style: TextStyle(color: Colors.white70))))
      else
        _CoinFlipper(
            key: ValueKey(run),
            resultSide: result!,
            onDone: () {
              setState(() => done = true);
              Future.delayed(const Duration(milliseconds: 500),
                  () => playServerSound(result == mine ? 'game_win' : 'game_lose'));
            }),
      if (done)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              result == mine ? '🎉 كسبت! خرجت ${result == 'heads' ? 'صورة' : 'كتابة'}' : '😅 خسرت — خرجت ${result == 'heads' ? 'صورة' : 'كتابة'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton(
            onPressed: result != null && !done ? null : () => _flip('heads'),
            child: const Text('👑 صورة')),
        const SizedBox(width: 12),
        FilledButton(
            onPressed: result != null && !done ? null : () => _flip('tails'),
            child: const Text('✦ كتابة')),
      ]),
    ]);
  }
}

// ───────────────────────── مباراة حقيقية (خادم) ─────────────────────────

class GameMatchDialog extends StatefulWidget {
  final String matchId;
  const GameMatchDialog({super.key, required this.matchId});
  @override
  State<GameMatchDialog> createState() => _GameMatchDialogState();
}

class _GameMatchDialogState extends State<GameMatchDialog> {
  final Map<String, String> _names = {};
  bool _namesLoaded = false;
  bool _coinDone = false;
  bool _resultSoundPlayed = false;

  void _playResultSound(Map<String, dynamic> row, {int delayMs = 700}) {
    if (_resultSoundPlayed) return;
    _resultSoundPlayed = true;
    final winner = row['winner']?.toString();
    final key = (winner == null || winner == 'null')
        ? 'game_draw'
        : (winner == _me ? 'game_win' : 'game_lose');
    Future.delayed(Duration(milliseconds: delayMs), () => playServerSound(key));
  }

  String get _me => _db.auth.currentUser?.id ?? '';

  late final Stream<List<Map<String, dynamic>>> _matchStream = _db
      .from('game_matches')
      .stream(primaryKey: ['id']).eq('id', widget.matchId);

  Future<void> _loadNames(Map<String, dynamic> row) async {
    if (_namesLoaded) return;
    _namesLoaded = true;
    try {
      final ids = [row['p1'].toString(), row['p2'].toString()];
      final rows = await _db
          .from('profiles')
          .select('id,display_name,username')
          .inFilter('id', ids);
      for (final r in rows) {
        final n = (r['display_name'] ?? r['username'])?.toString().trim();
        _names[r['id'].toString()] = (n == null || n.isEmpty) ? 'لاعب' : n;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      await _db.rpc(fn, params: params);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    }
  }

  String _resultLine(Map<String, dynamic> row) {
    final stake = (row['stake_points'] as num?)?.toInt() ?? 0;
    final winner = row['winner']?.toString();
    final resigned = (row['state'] is Map) && row['state']['resigned'] == true;
    if (winner == null || winner == 'null') {
      return 'تعادل — لا تغيير في النقاط';
    }
    final won = winner == _me;
    final tail = resigned ? (won ? ' (استسلم الخصم)' : ' (استسلمت)') : '';
    if (won) return '🎉 فزت${stake > 0 ? ' وربحت $stake نقطة' : ''}$tail';
    return '😅 خسرت${stake > 0 ? ' وخسرت $stake نقطة' : ''}$tail';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _matchStream,
      builder: (context, snap) {
        final rows = snap.data;
        if (rows == null || rows.isEmpty) {
          return const _GameShell(
              title: 'جارٍ التحميل…',
              child: SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator())));
        }
        final row = rows.first;
        unawaited(_loadNames(row));
        final type = row['game_type'].toString();
        final p1 = row['p1'].toString();
        final isP1 = p1 == _me;
        final oppId = isP1 ? row['p2'].toString() : p1;
        final myName = _names[_me] ?? 'أنت';
        final oppName = _names[oppId] ?? 'الخصم';
        final status = row['status'].toString();
        final stake = (row['stake_points'] as num?)?.toInt() ?? 0;
        if (status == 'finished' && type != 'coin') _playResultSound(row);
        final state = row['state'] is Map
            ? Map<String, dynamic>.from(row['state'] as Map)
            : <String, dynamic>{};
        Widget body;
        if (type == 'connect4') {
          final board = ((state['board'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList();
          final win = ((state['win_cells'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList();
          final last = (state['last'] as num?)?.toInt();
          final myTurn = status == 'active' && row['turn']?.toString() == _me;
          final line = status == 'active'
              ? (myTurn
                  ? 'دورك — أنت ${isP1 ? 'الأحمر' : 'الأصفر'}'
                  : 'دور $oppName…')
              : _resultLine(row);
          body = Column(children: [
            Text(line,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            if (board.length == _rows * _cols)
              Connect4BoardView(
                board: board,
                winCells: win,
                lastIdx: last,
                enabled: myTurn,
                onColumn: (c) => _rpc(
                    'play_connect4', {'p_match_id': row['id'], 'p_col': c}),
              ),
          ]);
        } else if (type == 'rps') {
          final scores = ((state['scores'] as List?) ?? const [0, 0])
              .map((e) => (e as num).toInt())
              .toList();
          final picked = (state['picked'] as List?) ?? const [false, false];
          final last = state['last'] is Map
              ? Map<String, dynamic>.from(state['last'] as Map)
              : null;
          final myPicked = picked[isP1 ? 0 : 1] == true;
          final myLast = last == null ? null : last[isP1 ? 'p1' : 'p2']?.toString();
          final oppLast = last == null ? null : last[isP1 ? 'p2' : 'p1']?.toString();
          String banner;
          if (status != 'active') {
            banner = _resultLine(row);
          } else if (myPicked) {
            banner = 'بانتظار اختيار $oppName…';
          } else if (last != null) {
            final res = (last['res'] as num).toInt();
            banner = res == 0
                ? 'تعادل — أعد الجولة'
                : ((res == 1) == isP1 ? 'ربحت الجولة السابقة ✓' : 'خسرت الجولة السابقة');
          } else {
            banner = 'اختر: حجر أم ورقة أم مقص؟ (الأول إلى فوزين)';
          }
          body = RpsArena(
            myName: myName,
            oppName: oppName,
            myScore: scores[isP1 ? 0 : 1],
            oppScore: scores[isP1 ? 1 : 0],
            round: (state['round'] as num?)?.toInt() ?? 1,
            myLast: myLast,
            oppLast: oppLast,
            banner: banner,
            canPick: status == 'active' && !myPicked,
            onPick: (c) =>
                _rpc('play_rps', {'p_match_id': row['id'], 'p_choice': c}),
          );
        } else {
          final side = state['side']?.toString() ?? 'heads';
          final mySide = (isP1 ? state['p1_side'] : state['p2_side'])?.toString() ??
              (isP1 ? 'heads' : 'tails');
          body = Column(children: [
            Text('أنت: ${mySide == 'heads' ? 'صورة 👑' : 'كتابة ✦'}   •   $oppName: ${mySide == 'heads' ? 'كتابة ✦' : 'صورة 👑'}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            _CoinFlipper(
                key: ValueKey('coin-${row['id']}'),
                resultSide: side,
                onDone: () {
                  if (mounted) setState(() => _coinDone = true);
                  _playResultSound(row, delayMs: 500);
                }),
            AnimatedOpacity(
              opacity: _coinDone ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text(_resultLine(row),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ),
            const SizedBox(height: 8),
          ]);
        }
        return _GameShell(
          title: '${gameTitle(type)} — $myName ضد $oppName',
          chip: stake > 0 ? 'الرهان: $stake نقطة' : 'لعب ودّي',
          trailing: status == 'active' && type != 'coin'
              ? TextButton(
                  onPressed: () =>
                      _rpc('resign_game_match', {'p_match_id': row['id']}),
                  child: const Text('استسلام',
                      style: TextStyle(color: Colors.redAccent)))
              : null,
          child: body,
        );
      },
    );
  }
}
