import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/server_sounds.dart';
import '../../../../core/services/snack_sfx.dart';
import 'game_hub.dart' show gameErrorText;

/// تركس سوري — كل شيء يُحسم في الخادم:
/// الخلط والتوزيع، قانونية كل ورقة، الأكلات، الاحتساب، رهان النقاط والتسوية،
/// وحتى لعب الكمبيوتر. هذا الملف عرض فقط (الأيدي الأخرى لا تصل للعميل أبدًا).
SupabaseClient get _tdb => Supabase.instance.client;

const Map<String, String> _contractName = {
  'king': 'الملك ♥',
  'queens': 'البنات',
  'diamonds': 'الديناري ♦',
  'slaps': 'اللطش',
  'trix': 'التركس',
};

const Map<String, String> _contractHint = {
  'king': 'تجنّب أكل شايب الهارت (−75)',
  'queens': 'تجنّب أكل البنات (−25 لكل بنت)',
  'diamonds': 'تجنّب أكل الديناري (−10 لكل ورقة)',
  'slaps': 'تجنّب الأكلات (−15 لكل أكلة)',
  'trix': 'تخلّص من أوراقك أولًا (+200/150/100/50)',
};

const Map<String, String> _suitSym = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'};

String _rankLabel(int r) {
  switch (r) {
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    case 14:
      return 'A';
    default:
      return '$r';
  }
}

int _rankOf(String c) => int.tryParse(c.substring(1)) ?? 0;
String _suitOf(String c) => c.substring(0, 1);

// ───────────────────────── ظهر الورق (خياطة وملابس) ─────────────────────────

Color _hex(String? h, Color fallback) {
  if (h == null || h.length < 7) return fallback;
  final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
  if (v == null) return fallback;
  return Color(0xFF000000 | v);
}

class CardBack extends StatelessWidget {
  final Map<String, dynamic>? params;
  final double width;
  final double height;
  const CardBack(
      {super.key, required this.params, this.width = 46, this.height = 66});

  @override
  Widget build(BuildContext context) {
    final p = params ?? const <String, dynamic>{};
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white, width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(1, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.10),
        child: CustomPaint(
          painter: _BackPainter(
            pattern: (p['pattern'] ?? 'plaid').toString(),
            c1: _hex(p['c1']?.toString(), const Color(0xFF7B1E2B)),
            c2: _hex(p['c2']?.toString(), const Color(0xFFE8C547)),
            c3: _hex(p['c3']?.toString(), Colors.white),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  final String pattern;
  final Color c1, c2, c3;
  _BackPainter(
      {required this.pattern,
      required this.c1,
      required this.c2,
      required this.c3});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(Offset.zero & s, Paint()..color = c1);
    final line = Paint()..style = PaintingStyle.stroke;
    switch (pattern) {
      case 'buttons':
        final r = w * 0.085;
        final fill = Paint()..color = c2;
        final ring = Paint()
          ..color = c3
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        final hole = Paint()..color = c1;
        final stepX = w / 3, stepY = h / 5;
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 5; j++) {
            final o = Offset(stepX * (i + 0.5), stepY * (j + 0.5));
            canvas.drawCircle(o, r, fill);
            canvas.drawCircle(o, r, ring);
            final d = r * 0.35;
            canvas.drawCircle(o + Offset(-d, -d), r * 0.14, hole);
            canvas.drawCircle(o + Offset(d, -d), r * 0.14, hole);
            canvas.drawCircle(o + Offset(-d, d), r * 0.14, hole);
            canvas.drawCircle(o + Offset(d, d), r * 0.14, hole);
          }
        }
        break;
      case 'stitch':
        line
          ..color = c3.withAlpha(60)
          ..strokeWidth = 1;
        for (double x = -h; x < w; x += 4) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), line);
        }
        line
          ..color = c2
          ..strokeWidth = 1.4;
        final inset = w * 0.09;
        _dashRect(canvas, Rect.fromLTWH(inset, inset, w - 2 * inset, h - 2 * inset), line, 4, 3);
        _dashRect(canvas, Rect.fromLTWH(inset * 2, inset * 2, w - 4 * inset, h - 4 * inset),
            line..color = c2.withAlpha(150), 3, 3);
        break;
      case 'scissors':
        final dot = Paint()..color = c3.withAlpha(50);
        for (double x = w * 0.15; x < w; x += w * 0.3) {
          for (double y = h * 0.1; y < h; y += h * 0.2) {
            canvas.drawCircle(Offset(x, y), 1.2, dot);
          }
        }
        _icon(canvas, Icons.content_cut, Offset(w / 2, h / 2), w * 0.62, c2, -0.6);
        _icon(canvas, Icons.content_cut, Offset(w * 0.22, h * 0.14), w * 0.2, c3.withAlpha(180), 0.4);
        _icon(canvas, Icons.content_cut, Offset(w * 0.78, h * 0.86), w * 0.2, c3.withAlpha(180), 3.6);
        break;
      case 'tape':
        line
          ..color = c2
          ..strokeWidth = 1;
        for (var i = 0; i <= 26; i++) {
          final y = h * i / 26;
          final len = i % 5 == 0 ? w * 0.22 : w * 0.11;
          canvas.drawLine(Offset(0, y), Offset(len, y), line);
          canvas.drawLine(Offset(w, y), Offset(w - len, y), line);
        }
        canvas.drawRect(Rect.fromLTWH(w * 0.34, 0, w * 0.32, h),
            Paint()..color = c3.withAlpha(46));
        _icon(canvas, Icons.straighten, Offset(w / 2, h / 2), w * 0.5, c3, 0);
        break;
      case 'zipper':
        final cx = w / 2;
        canvas.drawRect(Rect.fromLTWH(cx - w * 0.2, 0, w * 0.4, h),
            Paint()..color = c3.withAlpha(30));
        final tooth = Paint()..color = c2;
        final th = h / 18;
        for (var i = 0; i < 18; i++) {
          final y = i * th;
          final left = i.isEven;
          final r = RRect.fromRectAndRadius(
              Rect.fromLTWH(left ? cx - w * 0.17 : cx + w * 0.01, y + 1, w * 0.16, th - 2),
              const Radius.circular(2));
          canvas.drawRRect(r, tooth);
        }
        final pull = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, h * 0.2), width: w * 0.3, height: h * 0.14),
            const Radius.circular(5));
        canvas.drawRRect(pull, Paint()..color = c3);
        canvas.drawCircle(Offset(cx, h * 0.2), w * 0.04, Paint()..color = c1);
        break;
      case 'plaid':
      default:
        final band = Paint()..color = c2.withAlpha(120);
        final thin = Paint()..color = c3.withAlpha(190);
        final n = 4;
        for (var i = 0; i < n; i++) {
          final x = w * (i + 0.5) / n;
          canvas.drawRect(Rect.fromLTWH(x - w * 0.055, 0, w * 0.11, h), band);
          canvas.drawRect(Rect.fromLTWH(x - 0.5, 0, 1, h), thin);
        }
        final m = 6;
        for (var j = 0; j < m; j++) {
          final y = h * (j + 0.5) / m;
          canvas.drawRect(Rect.fromLTWH(0, y - h * 0.035, w, h * 0.07), band);
          canvas.drawRect(Rect.fromLTWH(0, y - 0.5, w, 1), thin);
        }
        break;
    }
  }

  void _dashRect(Canvas c, Rect r, Paint p, double dash, double gap) {
    void seg(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      double d = 0;
      while (d < len) {
        final e = math.min(d + dash, len);
        c.drawLine(a + dir * d, a + dir * e, p);
        d = e + gap;
      }
    }

    seg(r.topLeft, r.topRight);
    seg(r.topRight, r.bottomRight);
    seg(r.bottomRight, r.bottomLeft);
    seg(r.bottomLeft, r.topLeft);
  }

  void _icon(Canvas canvas, IconData icon, Offset center, double size, Color color,
      double angle) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackPainter o) =>
      o.pattern != pattern || o.c1 != c1 || o.c2 != c2 || o.c3 != c3;
}

// ───────────────────────── وجه الورقة ─────────────────────────

class PlayingCard extends StatelessWidget {
  final String card;
  final double width;
  final double height;
  final bool dim;
  final bool glow;
  const PlayingCard(
      {super.key,
      required this.card,
      this.width = 50,
      this.height = 72,
      this.dim = false,
      this.glow = false});

  @override
  Widget build(BuildContext context) {
    final suit = _suitOf(card);
    final red = suit == 'H' || suit == 'D';
    final col = red ? const Color(0xFFC62828) : const Color(0xFF212121);
    final label = _rankLabel(_rankOf(card));
    final sym = _suitSym[suit] ?? '';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dim ? const Color(0xFFB8B8B8) : const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
            color: glow ? const Color(0xFFFFC107) : const Color(0xFF9E9E9E),
            width: glow ? 2.2 : 0.8),
        boxShadow: [
          BoxShadow(
              color: glow ? const Color(0x99FFC107) : const Color(0x55000000),
              blurRadius: glow ? 8 : 3,
              offset: const Offset(1, 2))
        ],
      ),
      child: Stack(children: [
        Positioned(
          left: width * 0.07,
          top: height * 0.03,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: col,
                    fontSize: width * 0.30,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
            Text(sym,
                style: TextStyle(color: col, fontSize: width * 0.26, height: 1.0)),
          ]),
        ),
        Center(
          child: Text(sym,
              style: TextStyle(color: col.withAlpha(dim ? 120 : 255), fontSize: width * 0.56)),
        ),
      ]),
    );
  }
}

// ───────────────────────── الدخول والمشغّل ─────────────────────────

final Set<String> _openTrix = <String>{};

Future<void> openTrixGame(BuildContext context, String gameId) async {
  if (!_openTrix.add(gameId)) return;
  playServerSound('game_start');
  try {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TrixScreen(gameId: gameId),
    ));
  } finally {
    _openTrix.remove(gameId);
  }
}

String trixTitle(String type) => type == 'trix_partner'
    ? 'تركس سوري (شراكة)'
    : (type == 'trix_solo' ? 'تركس سوري (فردي)' : 'تركس سوري');

String trixErrorText(Object e) {
  final raw = e.toString();
  if (raw.contains('ALREADY_IN_GAME')) return 'لديك مباراة تركس جارية بالفعل.';
  if (raw.contains('ILLEGAL_MOVE')) return 'هذه الورقة غير مسموحة الآن.';
  if (raw.contains('CONTRACT_USED')) return 'هذا العقد استُخدم سابقًا.';
  if (raw.contains('CARD_NOT_IN_HAND')) return 'الورقة ليست في يدك.';
  if (raw.contains('NOT_PLAYING')) return 'ليس وقت اللعب.';
  if (raw.contains('GAME_NOT_FOUND')) return 'المباراة غير موجودة.';
  return gameErrorText(e);
}

Future<List<Map<String, dynamic>>> _loadBacks() async {
  try {
    final raw = await _tdb.rpc('get_card_backs');
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}

/// مشغّل التركس ضد الكمبيوتر: اختيار النمط والرهان وظهر الورق.
Future<void> showTrixLauncher(BuildContext context, {String? roomId}) async {
  // مباراة جارية؟ استأنفها.
  try {
    final active = await _tdb.rpc('trix_my_active');
    if (active != null && context.mounted) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('لديك مباراة جارية', textDirection: TextDirection.rtl),
          content: const Text('هل تريد العودة إلى مباراة التركس؟',
              textDirection: TextDirection.rtl),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('لاحقًا')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('العودة للمباراة')),
          ],
        ),
      );
      if (resume == true && context.mounted) {
        await openTrixGame(context, active.toString());
      }
      return;
    }
  } catch (_) {}
  if (!context.mounted) return;
  final backs = await _loadBacks();
  String mine = 'plaid';
  try {
    mine = (await _tdb.rpc('get_my_card_back')).toString();
  } catch (_) {}
  if (!context.mounted) return;
  var mode = 'solo';
  var stake = 0;
  var back = mine;
  final started = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setS) {
      return AlertDialog(
        backgroundColor: const Color(0xFF171126),
        title: const Text('تركس سوري ضد الكمبيوتر',
            style: TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('النمط',
                    style: TextStyle(color: Colors.white70),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 6),
                Wrap(spacing: 8, textDirection: TextDirection.rtl, children: [
                  ChoiceChip(
                      label: const Text('فردي (كل لاعب لنفسه)'),
                      selected: mode == 'solo',
                      onSelected: (_) => setS(() => mode = 'solo')),
                  ChoiceChip(
                      label: const Text('شراكة (أنت + شريك آلي)'),
                      selected: mode == 'partner',
                      onSelected: (_) => setS(() => mode = 'partner')),
                ]),
                const SizedBox(height: 12),
                const Text('الرهان (يُحسم في الخادم)',
                    style: TextStyle(color: Colors.white70),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, textDirection: TextDirection.rtl, children: [
                  for (final s in const [0, 10, 50, 100, 500, 1000])
                    ChoiceChip(
                        label: Text(s == 0 ? 'ودّي' : '$s'),
                        selected: stake == s,
                        onSelected: (_) => setS(() => stake = s)),
                ]),
                const SizedBox(height: 4),
                Text(
                    stake == 0
                        ? 'بلا نقاط.'
                        : (mode == 'solo'
                            ? 'يُحجز $stake من رصيدك. المركز 1: +${stake * 2}، 2: 0، 3 و4: −$stake.'
                            : 'يُحجز $stake من رصيدك. فريقك يفوز: +$stake، يخسر: −$stake.'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textDirection: TextDirection.rtl),
                if (backs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('ظهر الورق',
                      style: TextStyle(color: Colors.white70),
                      textDirection: TextDirection.rtl),
                  const SizedBox(height: 6),
                  _BackPicker(
                      backs: backs,
                      selected: back,
                      onPick: (k) => setS(() => back = k)),
                ],
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('ابدأ')),
        ],
      );
    }),
  );
  if (started != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (back != mine) {
      await _tdb.rpc('set_my_card_back', params: {'p_key': back});
    }
    final id = await _tdb.rpc('trix_start_vs_computer',
        params: {'p_mode': mode, 'p_stake': stake, 'p_room_id': roomId});
    if (!context.mounted) return;
    await openTrixGame(context, id.toString());
  } catch (e) {
    messenger.showSnackBarSfx(SnackBar(content: Text(trixErrorText(e))));
  }
}

class _BackPicker extends StatelessWidget {
  final List<Map<String, dynamic>> backs;
  final String selected;
  final ValueChanged<String> onPick;
  const _BackPicker(
      {required this.backs, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, textDirection: TextDirection.rtl, children: [
      for (final b in backs)
        GestureDetector(
          onTap: () => onPick(b['key'].toString()),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected == b['key']
                        ? const Color(0xFFFFC107)
                        : Colors.transparent,
                    width: 2),
              ),
              child: CardBack(
                  params: b['params'] is Map
                      ? Map<String, dynamic>.from(b['params'] as Map)
                      : null,
                  width: 40,
                  height: 58),
            ),
            const SizedBox(height: 2),
            Text(b['name'].toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        ),
    ]);
  }
}

// ───────────────────────── شاشة المباراة ─────────────────────────

class TrixScreen extends StatefulWidget {
  final String gameId;
  const TrixScreen({super.key, required this.gameId});

  @override
  State<TrixScreen> createState() => _TrixScreenState();
}

class _TrixScreenState extends State<TrixScreen> {
  Map<String, dynamic>? _v;
  Timer? _timer;
  bool _busy = false;
  bool _resultShown = false;
  String? _sel;
  String? _error;
  int _lastSeq = -1;
  List<Map<String, dynamic>> _backs = [];
  String _myBack = 'plaid';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
    _tick();
  }

  Future<void> _bootstrap() async {
    _backs = await _loadBacks();
    try {
      _myBack = (await _tdb.rpc('get_my_card_back')).toString();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _backParams {
    for (final b in _backs) {
      if (b['key'].toString() == _myBack && b['params'] is Map) {
        return Map<String, dynamic>.from(b['params'] as Map);
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    try {
      final raw = await _tdb.rpc('trix_my_view', params: {'p_game': widget.gameId});
      if (raw is Map && mounted) {
        final v = Map<String, dynamic>.from(raw);
        final seq = (v['seq'] as num?)?.toInt() ?? 0;
        if (seq != _lastSeq) {
          _lastSeq = seq;
          if (_sel != null && !(v['legal'] is List && (v['legal'] as List).contains(_sel))) {
            _sel = null;
          }
        }
        setState(() {
          _v = v;
          _error = null;
        });
        if (v['status'] == 'finished' && !_resultShown) {
          _resultShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = trixErrorText(e));
    }
  }

  Future<void> _tick() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await _refresh();
      final v = _v;
      if (v != null && v['status'] == 'active') {
        final phase = v['phase']?.toString();
        final turn = (v['turn'] as num?)?.toInt() ?? -1;
        final seats = (v['seats'] as List?) ?? const [];
        final botTurn = turn >= 0 && turn < seats.length && seats[turn] == null;
        if (phase == 'handover' || botTurn) {
          final acted = await _tdb.rpc('trix_bot_step', params: {'p_game': widget.gameId});
          if (acted == true) await _refresh();
        }
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _play(String card) async {
    if (_busy) return;
    _busy = true;
    try {
      playServerSound('disc_drop');
      await _tdb.rpc('trix_play', params: {'p_game': widget.gameId, 'p_card': card});
      _sel = null;
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text(trixErrorText(e))));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _choose(String c) async {
    if (_busy) return;
    _busy = true;
    try {
      await _tdb.rpc('trix_choose_contract',
          params: {'p_game': widget.gameId, 'p_contract': c});
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text(trixErrorText(e))));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _resign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('الانسحاب', textDirection: TextDirection.rtl),
        content: Text(
            ((_v?['stake'] as num?)?.toInt() ?? 0) > 0
                ? 'الانسحاب يعني خسارة الرهان. متأكد؟'
                : 'هل تريد إنهاء المباراة؟',
            textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('انسحاب')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _tdb.rpc('trix_resign', params: {'p_game': widget.gameId});
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text(trixErrorText(e))));
      }
    }
  }

  Future<void> _pickBack() async {
    if (_backs.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171126),
          title: const Text('ظهر الورق',
              style: TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
          content: _BackPicker(
              backs: _backs,
              selected: _myBack,
              onPick: (k) async {
                setS(() => _myBack = k);
                if (mounted) setState(() {});
                try {
                  await _tdb.rpc('set_my_card_back', params: {'p_key': k});
                } catch (_) {}
              }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('تم'))
          ],
        );
      }),
    );
  }

  List<int> get _scores =>
      ((_v?['scores'] as List?) ?? const [0, 0, 0, 0]).map((e) => (e as num).toInt()).toList();

  String _name(int seat) {
    final n = (_v?['names'] as List?) ?? const [];
    return seat >= 0 && seat < n.length ? n[seat].toString() : 'لاعب';
  }

  Future<void> _showResult() async {
    final v = _v;
    if (v == null || !mounted) return;
    final me = (v['me'] as num?)?.toInt() ?? 0;
    final res = v['result'] is Map ? Map<String, dynamic>.from(v['result'] as Map) : <String, dynamic>{};
    final nets = ((res['nets'] as List?) ?? const [0, 0, 0, 0]).map((e) => (e as num).toInt()).toList();
    final net = me < nets.length ? nets[me] : 0;
    final stake = (v['stake'] as num?)?.toInt() ?? 0;
    playServerSound(net > 0 ? 'game_win' : (net < 0 ? 'game_lose' : 'game_draw'));
    final sc = _scores;
    final order = List<int>.generate(4, (i) => i)..sort((a, b) => sc[b].compareTo(sc[a]));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF171126),
        title: Text(
            res['resigned'] != null
                ? 'انتهت المباراة (انسحاب)'
                : (net > 0 ? '🏆 مبروك!' : (net < 0 ? 'حظًا أوفر' : 'تعادل')),
            style: const TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in order)
            ListTile(
              dense: true,
              title: Text(_name(s) + (s == me ? ' (أنت)' : ''),
                  style: TextStyle(
                      color: s == me ? const Color(0xFFFFD54F) : Colors.white),
                  textDirection: TextDirection.rtl),
              trailing: Text('${sc[s]}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          const Divider(color: Colors.white24),
          Text(
              stake == 0
                  ? 'مباراة ودّية.'
                  : (net > 0
                      ? 'ربحت $net نقطة (أُضيفت لرصيدك).'
                      : (net < 0 ? 'خسرت ${-net} نقطة.' : 'استرددت رهانك.')),
              style: const TextStyle(color: Colors.white70),
              textDirection: TextDirection.rtl),
        ]),
        actions: [
          FilledButton(
              onPressed: () {
                Navigator.pop(c);
                if (mounted) Navigator.of(context).maybePop();
              },
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0A18),
      body: SafeArea(
        child: v == null
            ? Center(
                child: _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.white70))
                    : const CircularProgressIndicator())
            : _body(v),
      ),
    );
  }

  Widget _body(Map<String, dynamic> v) {
    final me = (v['me'] as num).toInt();
    final phase = v['phase']?.toString() ?? '';
    final turn = (v['turn'] as num?)?.toInt() ?? -1;
    final contract = v['contract']?.toString();
    final kingdom = (v['kingdom'] as num?)?.toInt() ?? 0;
    final handNo = (v['hand_no'] as num?)?.toInt() ?? 0;
    final stake = (v['stake'] as num?)?.toInt() ?? 0;
    final mode = v['mode']?.toString() ?? 'solo';
    final sc = _scores;
    final myTurn = turn == me;
    final hand = ((v['hand'] as List?) ?? const []).map((e) => e.toString()).toList();
    final legal = ((v['legal'] as List?) ?? const []).map((e) => e.toString()).toSet();
    final sizes = ((v['hand_sizes'] as List?) ?? const [13, 13, 13, 13]).map((e) => (e as num).toInt()).toList();

    String status;
    if (v['status'] == 'finished') {
      status = 'انتهت المباراة';
    } else if (phase == 'choose') {
      status = turn == me ? 'أنت الملك — اختر العقد' : '${_name(turn)} يختار العقد…';
    } else if (phase == 'handover') {
      status = 'انتهت اليد — التالية بعد لحظات…';
    } else {
      status = myTurn ? 'دورك — العب ورقة' : 'دور ${_name(turn)}';
    }

    return Column(children: [
      // الشريط العلوي
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Row(children: [
          IconButton(
              onPressed: _resign,
              tooltip: 'انسحاب',
              icon: const Icon(Icons.flag_rounded, color: Colors.white54)),
          Expanded(
            child: Column(children: [
              Text(
                  '${mode == 'partner' ? 'شراكة' : 'فردي'} • الملك: ${_name(kingdom)} (${kingdom + 1}/4) • يد ${math.min(handNo + 1, 5)}/5'
                  '${stake > 0 ? ' • رهان $stake' : ''}',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              if (contract != null && phase != 'choose')
                Text('${_contractName[contract]} — ${_contractHint[contract]}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          IconButton(
              onPressed: _pickBack,
              tooltip: 'ظهر الورق',
              icon: const Icon(Icons.style_rounded, color: Colors.white54)),
          IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white54)),
        ]),
      ),
      // النتائج
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(children: [
          for (var s = 0; s < 4; s++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: turn == s ? const Color(0x44FFC107) : const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: s == me ? const Color(0xFFFFD54F) : Colors.transparent, width: 1),
                ),
                child: Column(children: [
                  Text(_name(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text('${sc[s]}',
                      style: TextStyle(
                          color: sc[s] < 0 ? const Color(0xFFFF8A80) : const Color(0xFFA5D6A7),
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                ]),
              ),
            ),
        ]),
      ),
      // الطاولة
      Expanded(child: _table(v, me, sizes, phase)),
      // الحالة
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: myTurn ? const Color(0x33FFC107) : Colors.transparent,
        child: Text(status,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                color: myTurn ? const Color(0xFFFFD54F) : Colors.white60,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ),
      if (phase == 'choose' && turn == me) _contractPicker(v),
      // يدي
      SizedBox(height: 92, child: _handFan(hand, legal, myTurn && phase == 'play')),
      const SizedBox(height: 4),
    ]);
  }

  Widget _contractPicker(Map<String, dynamic> v) {
    final rem = ((v['remaining'] as List?) ?? const []).map((e) => e.toString()).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final c in rem)
            FilledButton.tonal(
              onPressed: () => _choose(c),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_contractName[c] ?? c,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(_contractHint[c] ?? '',
                    style: const TextStyle(fontSize: 9),
                    textDirection: TextDirection.rtl),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _handFan(List<String> hand, Set<String> legal, bool canPlay) {
    return LayoutBuilder(builder: (context, box) {
      const cw = 52.0, ch = 76.0;
      final n = hand.length;
      if (n == 0) return const SizedBox.shrink();
      final avail = box.maxWidth - cw - 8;
      final step = n <= 1 ? 0.0 : math.min(cw * 0.8, avail / (n - 1));
      final total = step * (n - 1) + cw;
      final start = (box.maxWidth - total) / 2;
      return Stack(children: [
        for (var i = 0; i < n; i++)
          Positioned(
            left: start + step * i,
            bottom: _sel == hand[i] ? 10 : 2,
            child: GestureDetector(
              onTap: () {
                if (!canPlay) return;
                final c = hand[i];
                if (!legal.contains(c)) {
                  ScaffoldMessenger.of(context).showSnackBarSfx(
                      const SnackBar(content: Text('هذه الورقة غير مسموحة الآن.')));
                  return;
                }
                if (_sel == c) {
                  _play(c);
                } else {
                  setState(() => _sel = c);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                child: PlayingCard(
                  card: hand[i],
                  width: cw,
                  height: ch,
                  dim: canPlay && !legal.contains(hand[i]),
                  glow: canPlay && legal.contains(hand[i]) && _sel == hand[i],
                ),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _opponent(int seat, List<int> sizes, {required bool vertical}) {
    final n = sizes[seat];
    final shown = math.min(n, 7);
    final bp = _backParams;
    final cards = <Widget>[
      for (var i = 0; i < shown; i++)
        Positioned(
          left: vertical ? 0 : i * 9.0,
          top: vertical ? i * 9.0 : 0,
          child: CardBack(params: bp, width: 30, height: 43),
        ),
    ];
    final w = vertical ? 30.0 : 30.0 + math.max(0, shown - 1) * 9.0;
    final h = vertical ? 43.0 + math.max(0, shown - 1) * 9.0 : 43.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${_name(seat)} • $n',
          style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 2),
      SizedBox(width: w, height: h, child: Stack(children: cards)),
    ]);
  }

  Widget _table(Map<String, dynamic> v, int me, List<int> sizes, String phase) {
    final contract = v['contract']?.toString();
    final trick = ((v['trick'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final last = v['last_trick'] is Map ? Map<String, dynamic>.from(v['last_trick'] as Map) : null;
    final right = (me + 1) % 4, top = (me + 2) % 4, left = (me + 3) % 4;

    Widget center;
    if (contract == 'trix' && phase != 'choose') {
      center = _trixLayout(v);
    } else {
      List<Map<String, dynamic>> cards = trick;
      int? winner;
      var ghost = false;
      if (cards.isEmpty && last != null) {
        cards = ((last['cards'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        winner = (last['winner'] as num?)?.toInt();
        ghost = true;
      }
      center = SizedBox(
        width: 190,
        height: 170,
        child: Stack(children: [
          for (final c in cards)
            _trickCard(me, (c['s'] as num).toInt(), c['c'].toString(),
                ghost: ghost, win: ghost && winner == (c['s'] as num).toInt()),
          if (ghost && cards.isNotEmpty)
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                child: Text('أكلها ${_name(winner ?? 0)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 9)),
              ),
            ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..rotateX(0.16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const RadialGradient(
              colors: [Color(0xFF2E7D4F), Color(0xFF14522F)],
              radius: 0.95,
            ),
            border: Border.all(color: const Color(0xFF5D4037), width: 6),
            boxShadow: const [
              BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 8))
            ],
          ),
          child: Stack(children: [
            Align(alignment: Alignment.topCenter, child: Padding(
                padding: const EdgeInsets.only(top: 6), child: _opponent(top, sizes, vertical: false))),
            Align(alignment: Alignment.centerLeft, child: Padding(
                padding: const EdgeInsets.only(left: 6), child: _opponent(left, sizes, vertical: true))),
            Align(alignment: Alignment.centerRight, child: Padding(
                padding: const EdgeInsets.only(right: 6), child: _opponent(right, sizes, vertical: true))),
            Center(child: center),
            if (phase == 'handover') Center(child: _handoverCard(v)),
          ]),
        ),
      ),
    );
  }

  Widget _trickCard(int me, int seat, String card, {bool ghost = false, bool win = false}) {
    final rel = (seat - me + 4) % 4; // 0 أنا، 1 يمين، 2 أعلى، 3 يسار
    const w = 42.0, h = 60.0;
    Alignment al;
    switch (rel) {
      case 0:
        al = const Alignment(0, 0.95);
        break;
      case 1:
        al = const Alignment(0.7, 0.05);
        break;
      case 2:
        al = const Alignment(0, -0.95);
        break;
      default:
        al = const Alignment(-0.7, 0.05);
    }
    return Align(
      alignment: al,
      child: Opacity(
        opacity: ghost ? 0.75 : 1,
        child: PlayingCard(card: card, width: w, height: h, glow: win),
      ),
    );
  }

  Widget _trixLayout(Map<String, dynamic> v) {
    final layout = v['layout'] is Map ? Map<String, dynamic>.from(v['layout'] as Map) : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 34, vertical: 52),
      child: LayoutBuilder(builder: (context, box) {
        final cw = math.min(26.0, box.maxWidth / 13);
        final ch = cw * 1.38;
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final s in const ['S', 'H', 'D', 'C'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var r = 2; r <= 14; r++)
                  Builder(builder: (_) {
                    final lay = layout[s];
                    final has = lay is Map &&
                        r >= (lay['lo'] as num).toInt() &&
                        r <= (lay['hi'] as num).toInt();
                    return SizedBox(
                      width: cw,
                      height: ch,
                      child: has
                          ? FittedBox(
                              child: PlayingCard(card: '$s$r', width: 50, height: 69))
                          : Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                  color: const Color(0x14FFFFFF),
                                  borderRadius: BorderRadius.circular(3)),
                            ),
                    );
                  }),
              ]),
            ),
        ]);
      }),
    );
  }

  Widget _handoverCard(Map<String, dynamic> v) {
    final d = ((v['hand_delta'] as List?) ?? const [0, 0, 0, 0]).map((e) => (e as num).toInt()).toList();
    final contract = v['contract']?.toString();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xEE171126),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x66FFC107))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('نتيجة ${_contractName[contract] ?? ''}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        for (var s = 0; s < 4; s++)
          Text('${_name(s)}: ${d[s] > 0 ? '+' : ''}${d[s]}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  color: d[s] < 0
                      ? const Color(0xFFFF8A80)
                      : (d[s] > 0 ? const Color(0xFFA5D6A7) : Colors.white60),
                  fontSize: 12)),
      ]),
    );
  }
}
