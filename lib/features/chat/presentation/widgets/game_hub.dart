import 'dart:async';
import '../../../../core/services/snack_sfx.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/server_sounds.dart';
import 'animated_dice_roller.dart' show Dice3D;
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
              'ضد الكمبيوتر هنا: اللعب يُحسم في الخادم وللفائز جائزة نقاط. ضد لاعب حقيقي (رهان + جائزة نقاط وجواهر): اضغط صورته ← طلب لعبة.',
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
          for (final t in const ['connect4', 'rps', 'coin', 'dice'])
            ListTile(
              dense: true,
              leading: Text(
                  t == 'connect4' ? '🔴' : (t == 'rps' ? '✊' : (t == 'coin' ? '🪙' : '🎲')),
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
    body = const _Connect4Bot();
  } else if (type == 'rps') {
    body = const _RpsBot();
  } else if (type == 'dice') {
    body = const _DiceBot();
  } else {
    body = const _CoinBot();
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

// ───────────────────────── ضد الكمبيوتر (من الخادم) ─────────────────────────

Map<String, dynamic>? _asRow(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : null;
Map<String, dynamic> _stateOf(Map<String, dynamic>? r) =>
    r?['state'] is Map ? Map<String, dynamic>.from(r!['state'] as Map) : <String, dynamic>{};
Map<String, dynamic>? _prizeOf(Map<String, dynamic>? r) =>
    r?['prize'] is Map ? Map<String, dynamic>.from(r!['prize'] as Map) : null;

/// شارة النتيجة: النص + جائزة الخادم الفعلية (نقاط/جواهر) + احتفال عند الفوز.
class GameResultBurst extends StatefulWidget {
  final String result; // win | lose | draw
  final String text;
  final Map<String, dynamic>? prize;
  final bool sound;
  const GameResultBurst(
      {super.key, required this.result, required this.text, this.prize, this.sound = true});

  @override
  State<GameResultBurst> createState() => _GameResultBurstState();
}

class _GameResultBurstState extends State<GameResultBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  final List<List<double>> _bits = [];

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    for (var i = 0; i < 22; i++) {
      _bits.add([r.nextDouble() * math.pi * 2, 40 + r.nextDouble() * 110, (r.nextDouble() - 0.5) * 8, i.toDouble()]);
    }
    if (widget.sound) {
      Future.delayed(const Duration(milliseconds: 250), () {
        playServerSound(widget.result == 'win' ? 'game_win' : (widget.result == 'lose' ? 'game_lose' : 'game_draw'));
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.result == 'win';
    final pts = (widget.prize?['points'] as num?)?.toInt() ?? 0;
    final gems = (widget.prize?['gems'] as num?)?.toInt() ?? 0;
    final color = win ? const Color(0xFFFFD54F) : (widget.result == 'lose' ? const Color(0xFFFF8A80) : Colors.white);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final pop = Curves.elasticOut.transform((t / 0.55).clamp(0.0, 1.0));
        return SizedBox(
          width: double.infinity,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            if (win)
              for (final b in _bits)
                Transform.translate(
                  offset: Offset(math.cos(b[0]) * b[1] * Curves.easeOut.transform(t),
                      math.sin(b[0]) * b[1] * Curves.easeOut.transform(t) + 60 * t * t),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: b[2] * t,
                      child: Text(const ['🎉', '✨', '🏆', '💎', '⭐'][b[3].toInt() % 5],
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: 0.3 + 0.7 * pop,
                  child: Text(widget.text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        shadows: [Shadow(color: color.withAlpha(150), blurRadius: 12)],
                      )),
                ),
                const SizedBox(height: 6),
                if (pts > 0 || gems > 0)
                  Opacity(
                    opacity: ((t - 0.25) / 0.2).clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX((1 - Curves.easeOutBack.transform(((t - 0.25) / 0.35).clamp(0.0, 1.0))) * math.pi / 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Color(0x88FFB300), blurRadius: 14)],
                        ),
                        child: Text(
                          '🎁 جائزة الخادم: ${pts > 0 ? '+$pts نقطة' : ''}${gems > 0 ? '  +$gems 💎' : ''}',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: Color(0xFF3E2700), fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  )
                else if (win)
                  const Text('لم تُمنح جائزة (الحد اليومي أو شروط الأهلية).',
                      textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

/// أربعة في صف ضد الكمبيوتر: حركتك وحركة الكمبيوتر والفوز والجائزة من الخادم.
class _Connect4Bot extends StatefulWidget {
  const _Connect4Bot();
  @override
  State<_Connect4Bot> createState() => _Connect4BotState();
}

class _Connect4BotState extends State<_Connect4Bot> {
  Map<String, dynamic>? _row;
  List<int> _board = List<int>.filled(_rows * _cols, 0);
  int? _last;
  List<int> _win = const [];
  bool _busy = false;
  String? _err;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  List<int> _boardOf(Map<String, dynamic>? r) {
    final b = ((_stateOf(r)['board'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    return b.length == _rows * _cols ? b : List<int>.filled(_rows * _cols, 0);
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = _asRow(await _db.rpc('game_bot_start', params: {'p_game': 'connect4'}));
      if (!mounted || r == null) return;
      playServerSound('game_start');
      setState(() {
        _row = r;
        _board = _boardOf(r);
        _last = null;
        _win = const [];
        _round++;
      });
    } catch (e) {
      if (mounted) setState(() => _err = gameErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tap(int col) async {
    final r = _row;
    if (r == null || _busy || r['status'] != 'active') return;
    final nb = _c4Drop(_board, col, 1);
    if (nb == null) return;
    var idx = 0;
    for (var i = 0; i < nb.length; i++) {
      if (nb[i] != _board[i]) {
        idx = i;
        break;
      }
    }
    setState(() {
      _busy = true;
      _board = nb;
      _last = idx;
    });
    try {
      final res = _asRow(await _db.rpc('game_bot_c4', params: {'p_match': r['id'], 'p_col': col}));
      if (!mounted || res == null) return;
      final st = _stateOf(res);
      final botLast = (st['bot_last'] as num?)?.toInt();
      final win = ((st['win_cells'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
      if (botLast != null) {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
      }
      setState(() {
        _row = res;
        _board = _boardOf(res);
        _last = botLast ?? idx;
        _win = win;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _board = _boardOf(r));
        ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    final finished = r?['status'] == 'finished';
    final result = r?['result']?.toString() ?? 'draw';
    String line;
    if (_err != null) {
      line = _err!;
    } else if (r == null) {
      line = 'جارٍ تجهيز اللوحة من الخادم…';
    } else if (finished) {
      line = result == 'win' ? 'فزت!' : (result == 'lose' ? 'فاز الكمبيوتر' : 'تعادل');
    } else {
      line = _busy ? '🤖 الكمبيوتر يفكّر…' : 'دورك — أنت الأحمر 🔴';
    }
    return Column(children: [
      Text(line,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      Connect4BoardView(
          board: _board,
          winCells: _win,
          lastIdx: _last,
          enabled: r != null && !finished && !_busy,
          onColumn: _tap),
      if (finished)
        GameResultBurst(
          key: ValueKey('c4res$_round'),
          result: result,
          prize: _prizeOf(r),
          text: result == 'win' ? '🎉 فزت على الكمبيوتر!' : (result == 'lose' ? '😅 فاز الكمبيوتر' : '🤝 تعادل'),
        ),
      if (finished || _err != null)
        FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('جولة جديدة')),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('🎁 الفوز على الكمبيوتر: جائزة نقاط من الخادم (حسب الأهلية والحد اليومي).',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      ),
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
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutBack,
      onEnd: () {
        if (sound && pick != null) playServerSound('rps_reveal');
      },
      builder: (_, t, __) {
        final angle = t * math.pi;
        final showFace = angle < math.pi / 2 && pick != null;
        // «حجر… ورقة… مقص!»: قفزات ثلاث متزامنة قبل كشف اليد ثلاثي الأبعاد.
        final hop = pick == null ? 0.0 : -(math.sin((1 - t).clamp(0.0, 1.0) * math.pi * 3).abs()) * 16 * t;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform(
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
      TweenAnimationBuilder<double>(
        key: ValueKey('banner-${widget.round}-${widget.banner}'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
        child: Text(widget.banner,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
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

/// حجر ورقة مقص ضد الكمبيوتر: اختيار الكمبيوتر بعشوائية الخادم بعد اختيارك.
class _RpsBot extends StatefulWidget {
  const _RpsBot();
  @override
  State<_RpsBot> createState() => _RpsBotState();
}

class _RpsBotState extends State<_RpsBot> {
  Map<String, dynamic>? _row;
  bool _busy = false;
  String? _err;
  int _game = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = _asRow(await _db.rpc('game_bot_start', params: {'p_game': 'rps'}));
      if (mounted && r != null) {
        setState(() {
          _row = r;
          _game++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = gameErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String c) async {
    final r = _row;
    if (r == null || _busy || r['status'] != 'active') return;
    setState(() => _busy = true);
    try {
      final res = _asRow(await _db.rpc('game_bot_rps', params: {'p_match': r['id'], 'p_choice': c}));
      if (mounted && res != null) setState(() => _row = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    final st = _stateOf(r);
    final sc = ((st['scores'] as List?) ?? const [0, 0]).map((e) => (e as num).toInt()).toList();
    final last = st['last'] is Map ? Map<String, dynamic>.from(st['last'] as Map) : null;
    final finished = r?['status'] == 'finished';
    final result = r?['result']?.toString() ?? 'draw';
    String banner;
    if (_err != null) {
      banner = _err!;
    } else if (r == null) {
      banner = 'جارٍ التجهيز…';
    } else if (finished) {
      banner = result == 'win' ? 'فزت بالمباراة!' : 'فاز الكمبيوتر بالمباراة';
    } else if (last != null) {
      final res = (last['res'] as num?)?.toInt() ?? 0;
      banner = res == 0 ? 'تعادل — أعد الجولة' : (res == 1 ? 'ربحت الجولة ✓' : 'خسرت الجولة ✗');
    } else {
      banner = 'اختر: حجر أم ورقة أم مقص؟ (الأول إلى فوزين)';
    }
    return Column(children: [
      RpsArena(
        myName: 'أنت',
        oppName: 'الكمبيوتر 🤖',
        myScore: sc.isNotEmpty ? sc[0] : 0,
        oppScore: sc.length > 1 ? sc[1] : 0,
        round: (st['round'] as num?)?.toInt() ?? 1,
        myLast: last?['me']?.toString(),
        oppLast: last?['bot']?.toString(),
        banner: banner,
        canPick: r != null && !finished && !_busy,
        onPick: _pick,
      ),
      if (finished)
        GameResultBurst(
          key: ValueKey('rpsres$_game'),
          result: result,
          prize: _prizeOf(r),
          text: result == 'win' ? '🎉 فزت بالمباراة!' : '😅 فاز الكمبيوتر',
        ),
      if (finished || _err != null)
        FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('مباراة جديدة')),
    ]);
  }
}

/// العملة ضد الكمبيوتر: الوجه الخارج يُحسم في الخادم قبل الرمي.
class _CoinBot extends StatefulWidget {
  const _CoinBot();
  @override
  State<_CoinBot> createState() => _CoinBotState();
}

class _CoinBotState extends State<_CoinBot> {
  Map<String, dynamic>? _row;
  bool _busy = false;
  bool _done = false;
  int _run = 0;

  Future<void> _flip(String pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = _asRow(await _db.rpc('game_bot_start', params: {'p_game': 'coin', 'p_pick': pick}));
      if (mounted && r != null) {
        setState(() {
          _row = r;
          _done = false;
          _run++;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    final st = _stateOf(r);
    final side = st['side']?.toString() ?? 'heads';
    final result = r?['result']?.toString() ?? 'lose';
    final flipping = r != null && !_done;
    final sideName = side == 'heads' ? 'صورة' : 'كتابة';
    return Column(children: [
      if (r == null)
        const SizedBox(
            height: 220,
            child: Center(child: Text('اختر وجه العملة ثم ستُرمى', style: TextStyle(color: Colors.white70))))
      else
        _CoinFlipper(
            key: ValueKey(_run),
            resultSide: side,
            onDone: () {
              if (mounted) setState(() => _done = true);
            }),
      if (r != null && _done)
        GameResultBurst(
          key: ValueKey('coinres$_run'),
          result: result,
          prize: _prizeOf(r),
          text: result == 'win' ? '🎉 كسبت! خرجت $sideName' : '😅 خسرت — خرجت $sideName',
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton(onPressed: flipping || _busy ? null : () => _flip('heads'), child: const Text('👑 صورة')),
        const SizedBox(width: 12),
        FilledButton(onPressed: flipping || _busy ? null : () => _flip('tails'), child: const Text('✦ كتابة')),
      ]),
    ]);
  }
}

/// النرد ضد الكمبيوتر: نردان لكل طرف من الخادم، الأعلى مجموعًا يفوز.
class _DiceBot extends StatefulWidget {
  const _DiceBot();
  @override
  State<_DiceBot> createState() => _DiceBotState();
}

class _DiceBotState extends State<_DiceBot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Map<String, dynamic>? _row;
  bool _busy = false;
  bool _done = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        playServerSound('dice_land');
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = _asRow(await _db.rpc('game_bot_start', params: {'p_game': 'dice'}));
      if (mounted && r != null) {
        setState(() {
          _row = r;
          _done = false;
          _run++;
        });
        playServerSound('dice_roll');
        _c.forward(from: 0);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(gameErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _side(String label, List<int> d, int seed) {
    final sum = d.fold<int>(0, (a, b) => a + b);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < d.length; i++)
            Dice3D(value: d[i], progress: _row == null ? 1 : _c.value, size: 58, seed: seed + i),
        ]),
      ),
      AnimatedOpacity(
        opacity: _done ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Text('$sum',
            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 26)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    final st = _stateOf(r);
    List<int> dice(String k) =>
        ((st[k] as List?) ?? const [1, 1]).map((e) => (e as num).toInt()).toList();
    final result = r?['result']?.toString() ?? 'draw';
    final rolling = r != null && !_done;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _side('أنت', dice('me'), _run * 4),
        const Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 18)),
        _side('الكمبيوتر 🤖', dice('bot'), _run * 4 + 2),
      ]),
      if (r != null && _done)
        GameResultBurst(
          key: ValueKey('diceres$_run'),
          result: result,
          prize: _prizeOf(r),
          text: result == 'win' ? '🎉 مجموعك أعلى — فزت!' : (result == 'lose' ? '😅 الكمبيوتر أعلى' : '🤝 تعادل'),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: rolling || _busy ? null : _roll,
        icon: const Text('🎲', style: TextStyle(fontSize: 18)),
        label: Text(r == null ? 'ارمِ النرد' : 'ارمِ مجددًا'),
      ),
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
        final prize = state['prize'] is Map ? Map<String, dynamic>.from(state['prize'] as Map) : null;
        if (status == 'finished' && (type != 'coin' || _coinDone)) {
          final winner = row['winner']?.toString();
          final res = (winner == null || winner == 'null') ? 'draw' : (winner == _me ? 'win' : 'lose');
          body = Column(mainAxisSize: MainAxisSize.min, children: [
            body,
            GameResultBurst(
              key: ValueKey('match-res-${row['id']}'),
              result: res,
              sound: false,
              prize: prize != null && prize['uid']?.toString() == _me ? prize : null,
              text: res == 'win' ? '🏆 فزت!' : (res == 'lose' ? 'حظًا أوفر' : '🤝 تعادل'),
            ),
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
