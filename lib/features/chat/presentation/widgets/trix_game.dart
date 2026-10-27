import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/realtime_tuning.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/server_sounds.dart';
import '../../../../core/services/snack_sfx.dart';
import 'game_hub.dart' show gameErrorText;

part 'trix_window.dart';
part 'trix_screen.dart';

/// تركس سوري — كل شيء يُحسم في الخادم:
/// الخلط والتوزيع، قانونية كل ورقة، الأكلات، الاحتساب، رهان النقاط والتسوية،
/// وحتى لعب الكمبيوتر. هذا الملف عرض فقط (الأيدي الأخرى لا تصل للعميل أبدًا).
SupabaseClient get _tdb => Supabase.instance.client;

const Map<String, String> _contractName = {
  'king': 'الشايب ♥',
  'queens': 'البنات',
  'diamonds': 'الديناري ♦',
  'slaps': 'اللطش',
  'trix': 'التركس',
  'complex': 'كومبلكس',
};

const Map<String, String> _contractHint = {
  'king': 'تجنّب أكل شايب الكبّة (−75، مدبول −150)',
  'queens': 'تجنّب أكل البنات (−25، المدبولة −50)',
  'diamonds': 'تجنّب أكل الديناري (−10 لكل ورقة)',
  'slaps': 'تجنّب الأكلات (−15 لكل أكلة)',
  'trix': 'تخلّص من أوراقك أولًا (+200/150/100/50)',
  'complex': 'كل العقوبات معًا: شايب، بنات، ديناري، لطش',
};

/// هوية كل عقد بصريًا (لون، رمز) — للإعلان والتأثيرات.
const Map<String, Color> _contractColor = {
  'king': Color(0xFFE53935),
  'queens': Color(0xFFD81B60),
  'diamonds': Color(0xFF29B6F6),
  'slaps': Color(0xFFFF9800),
  'trix': Color(0xFF43A047),
  'complex': Color(0xFF8E24AA),
};
const Map<String, String> _contractIcon = {
  'king': '👑',
  'queens': '👸',
  'diamonds': '💎',
  'slaps': '✋',
  'trix': '🃏',
  'complex': '🌀',
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


// ───────────────────────── تفضيلات الورق (وجه + ظهر) ─────────────────────────

/// وجه الورقة وظهرها المختاران — من الخادم (user_card_face / user_card_back)،
/// مشتركان بين كل الشاشات فيتغيّر الشكل فورًا في المباراة الجارية.
class TrixPrefs {
  TrixPrefs._();
  static final ValueNotifier<String> face = ValueNotifier<String>('classic');
  static final ValueNotifier<String> back = ValueNotifier<String>('plaid');
  static List<Map<String, dynamic>> backs = const [];
  static List<Map<String, dynamic>> faces = const [
    {'key': 'classic', 'name': 'كلاسيكي'},
    {'key': 'jumbo', 'name': 'أرقام كبيرة'},
    {'key': 'four_color', 'name': 'أربعة ألوان'},
    {'key': 'royal_gold', 'name': 'ذهبي ملكي'},
    {'key': 'neon', 'name': 'نيون ليلي'},
  ];
  static bool _loaded = false;

  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final raw = await _tdb.rpc('get_card_backs');
      if (raw is List) {
        backs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    try {
      final f = await _tdb.rpc('get_card_faces');
      if (f is List && f.isNotEmpty) {
        faces = f.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    try {
      back.value = (await _tdb.rpc('get_my_card_back')).toString();
    } catch (_) {}
    try {
      face.value = (await _tdb.rpc('get_my_card_face')).toString();
    } catch (_) {}
    _loaded = true;
  }

  static Map<String, dynamic>? get backParams {
    for (final b in backs) {
      if (b['key'].toString() == back.value && b['params'] is Map) {
        return Map<String, dynamic>.from(b['params'] as Map);
      }
    }
    return null;
  }

  static Future<void> setFace(String k) async {
    face.value = k;
    try {
      await _tdb.rpc('set_my_card_face', params: {'p_key': k});
    } catch (_) {}
  }

  static Future<void> setBack(String k) async {
    back.value = k;
    try {
      await _tdb.rpc('set_my_card_back', params: {'p_key': k});
    } catch (_) {}
  }
}

// ───────────────────────── وجه الورقة (5 تصاميم) ─────────────────────────

Color _suitColor(String suit, String face) {
  if (face == 'neon') {
    switch (suit) {
      case 'H':
        return const Color(0xFFFF4FD8);
      case 'D':
        return const Color(0xFFFFE14D);
      case 'C':
        return const Color(0xFF39FF88);
      default:
        return const Color(0xFF4FE3FF);
    }
  }
  if (face == 'four_color') {
    switch (suit) {
      case 'H':
        return const Color(0xFFC62828);
      case 'D':
        return const Color(0xFF1565C0);
      case 'C':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF212121);
    }
  }
  return (suit == 'H' || suit == 'D') ? const Color(0xFFC62828) : const Color(0xFF212121);
}

String _courtGlyph(int r) => r == 13 ? '♚' : (r == 12 ? '♛' : (r == 11 ? '♝' : ''));

class PlayingCard extends StatelessWidget {
  final String card;
  final double width;
  final double height;
  final bool dim;
  final bool glow;
  final Color? glowColor;

  /// null = تصميم المستخدم الحالي (TrixPrefs.face).
  final String? face;
  const PlayingCard(
      {super.key,
      required this.card,
      this.width = 50,
      this.height = 72,
      this.dim = false,
      this.glow = false,
      this.glowColor,
      this.face});

  @override
  Widget build(BuildContext context) {
    final f = face ?? TrixPrefs.face.value;
    final suit = _suitOf(card);
    final rank = _rankOf(card);
    final col = _suitColor(suit, f);
    final label = _rankLabel(rank);
    final sym = _suitSym[suit] ?? '';
    final gc = glowColor ?? const Color(0xFFFFC107);

    BoxDecoration deco;
    switch (f) {
      case 'royal_gold':
        deco = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dim
                ? const [Color(0xFFB8B0A0), Color(0xFF9C9070)]
                : const [Color(0xFFFFF6D6), Color(0xFFE8C66A)],
          ),
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: glow ? gc : const Color(0xFFB8860B), width: glow ? 2.4 : 1.6),
          boxShadow: [
            BoxShadow(color: glow ? gc.withAlpha(160) : const Color(0x66000000), blurRadius: glow ? 9 : 3, offset: const Offset(1, 2))
          ],
        );
        break;
      case 'neon':
        deco = BoxDecoration(
          color: dim ? const Color(0xFF2A2338) : const Color(0xFF120A22),
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: glow ? gc : col.withAlpha(220), width: glow ? 2.4 : 1.4),
          boxShadow: [
            BoxShadow(color: (glow ? gc : col).withAlpha(dim ? 40 : 150), blurRadius: glow ? 12 : 7),
          ],
        );
        break;
      default:
        deco = BoxDecoration(
          color: dim ? const Color(0xFFB8B8B8) : const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: glow ? gc : const Color(0xFF9E9E9E), width: glow ? 2.2 : 0.8),
          boxShadow: [
            BoxShadow(color: glow ? gc.withAlpha(150) : const Color(0x55000000), blurRadius: glow ? 8 : 3, offset: const Offset(1, 2))
          ],
        );
    }

    final court = _courtGlyph(rank);
    Widget center;
    if (f == 'jumbo') {
      center = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(color: col, fontSize: width * 0.52, fontWeight: FontWeight.w900, height: 1.0)),
          Text(sym, style: TextStyle(color: col, fontSize: width * 0.34, height: 1.0)),
        ]),
      );
    } else {
      final glyph = (f == 'royal_gold' || f == 'neon') && court.isNotEmpty ? court : sym;
      center = Center(
        child: Text(glyph,
            style: TextStyle(
                color: col.withAlpha(dim ? 120 : 255),
                fontSize: width * (glyph == sym ? 0.56 : 0.62),
                shadows: f == 'neon' ? [Shadow(color: col, blurRadius: 8)] : null)),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: deco,
      child: Stack(children: [
        if (f != 'jumbo')
          Positioned(
            left: width * 0.07,
            top: height * 0.03,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(color: col, fontSize: width * 0.30, fontWeight: FontWeight.w900, height: 1.0)),
              Text(sym, style: TextStyle(color: col, fontSize: width * 0.26, height: 1.0)),
            ]),
          ),
        center,
      ]),
    );
  }
}

// ───────────────────────── الدخول ─────────────────────────

/// يفتح المباراة في نافذة اللعب العائمة (فوق التطبيق كله، تُكبَّر لملء الشاشة
/// أو تُصغَّر لنافذة أو أيقونة) بدل صفحة تحجب الشات.
Future<void> openTrixGame(BuildContext context, String gameId) async {
  playServerSound('game_start');
  TrixWindow.instance.openGame(gameId);
}

String trixTitle(String type) => type == 'trix_partner'
    ? 'تركس (شراكة)'
    : (type == 'trix_solo' ? 'تركس (فردي)' : 'تركس');

String trixErrorText(Object e) {
  final raw = e.toString();
  if (raw.contains('ALREADY_IN_GAME')) return 'لديك مباراة أو طاولة تركس جارية بالفعل.';
  if (raw.contains('ILLEGAL_MOVE')) return 'هذه الورقة غير مسموحة الآن.';
  if (raw.contains('CONTRACT_USED')) return 'هذا العقد استُخدم سابقًا.';
  if (raw.contains('CARD_NOT_IN_HAND')) return 'الورقة ليست في يدك.';
  if (raw.contains('NOT_PLAYING')) return 'ليس وقت اللعب.';
  if (raw.contains('DOUBLING_IN_PROGRESS')) return 'انتظر انتهاء وقت الدبل.';
  if (raw.contains('NOT_DOUBLING')) return 'انتهى وقت الدبل.';
  if (raw.contains('CANNOT_DOUBLE')) return 'لا يمكن دبل هذه الورقة.';
  if (raw.contains('GAME_NOT_FOUND')) return 'المباراة غير موجودة.';
  if (raw.contains('SEAT_TAKEN')) return 'المقعد محجوز.';
  if (raw.contains('TABLE_NOT_OPEN')) return 'الطاولة لم تعد مفتوحة.';
  if (raw.contains('TABLE_EXPIRED')) return 'انتهت مهلة الطاولة.';
  if (raw.contains('NOT_HOST')) return 'هذا للمضيف فقط.';
  if (raw.contains('ALREADY_SEATED')) return 'أنت جالس على الطاولة بالفعل.';
  if (raw.contains('INVALID_RECIPIENT')) return 'لا يمكن دعوة نفسك.';
  return gameErrorText(e);
}

const Map<String, String> trixVariantName = {
  'classic': 'كلاسيك (5 عقود)',
  'complex': 'كومبلكس (تركس + كومبلكس)',
};

/// مركز التركس: ضد الكمبيوتر، طاولة لاعبين حقيقيين 2×2، الطاولات المفتوحة،
/// الدعوات، وتصميم الورق.
Future<void> showTrixLauncher(BuildContext context, {String? roomId}) async {
  try {
    final active = await _tdb.rpc('trix_my_active');
    if (active != null && context.mounted) {
      TrixWindow.instance.openGame(active.toString());
      return;
    }
  } catch (_) {}
  unawaited(TrixPrefs.load());
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF171126),
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => _TrixLobby(roomId: roomId),
  );
}

class _TrixLobby extends StatefulWidget {
  final String? roomId;
  const _TrixLobby({this.roomId});
  @override
  State<_TrixLobby> createState() => _TrixLobbyState();
}

class _TrixLobbyState extends State<_TrixLobby> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  String _mode = 'partner';
  String _variant = 'classic';
  int _stake = 0;
  bool _busy = false;
  String? _tableId;
  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _open = const [];
  List<Map<String, dynamic>> _invites = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadMyTable();
    _loadOpen();
    _loadInvites();
    _poll = Timer.periodic(RealtimeTuning.idle, (_) => _pollTick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _snack(Object msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(msg is String ? msg : trixErrorText(msg))));
  }

  Future<void> _pollTick() async {
    if (_tableId != null) await _loadTable();
    if (_tabs.index == 2) await _loadOpen();
    if (_tabs.index == 3) await _loadInvites();
  }

  Future<void> _loadMyTable() async {
    try {
      final id = await _tdb.rpc('trix_my_table');
      if (id != null) {
        _tableId = id.toString();
        await _loadTable();
        if (mounted) _tabs.animateTo(1);
      }
    } catch (_) {}
  }

  Future<void> _loadTable() async {
    final id = _tableId;
    if (id == null) return;
    try {
      final raw = await _tdb.rpc('trix_table_view', params: {'p_table': id});
      if (raw is! Map || !mounted) return;
      final t = Map<String, dynamic>.from(raw);
      if (t['status'] == 'started' && t['game_id'] != null) {
        Navigator.of(context).maybePop();
        TrixWindow.instance.openGame(t['game_id'].toString());
        return;
      }
      if (t['status'] == 'cancelled') {
        setState(() {
          _tableId = null;
          _table = null;
        });
        _snack('أُلغيت الطاولة.');
        return;
      }
      setState(() => _table = t);
    } catch (_) {}
  }

  Future<void> _loadOpen() async {
    try {
      final raw = await _tdb.rpc('trix_open_tables', params: {'p_room_id': widget.roomId});
      if (raw is List && mounted) {
        setState(() => _open = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadInvites() async {
    try {
      final raw = await _tdb.rpc('trix_my_table_invites');
      if (raw is List && mounted) {
        setState(() => _invites = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───── أدوات اختيار مشتركة ─────
  Widget _chips<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onPick) {
    return Wrap(spacing: 6, runSpacing: 4, textDirection: TextDirection.rtl, children: [
      for (final v in values)
        ChoiceChip(label: Text(label(v)), selected: v == selected, onSelected: (_) => setState(() => onPick(v))),
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), textDirection: TextDirection.rtl),
      );

  Widget _setupForm({required bool vsComputer}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _label('النمط'),
      _chips<String>(const ['partner', 'solo'], _mode,
          (m) => m == 'partner' ? (vsComputer ? 'شراكة 2×2 (شريكك كمبيوتر)' : 'شراكة 2×2') : 'فردي (كل لاعب لنفسه)', (m) => _mode = m),
      _label('نوع اللعبة'),
      _chips<String>(const ['classic', 'complex'], _variant, (v) => trixVariantName[v]!, (v) => _variant = v),
      _label('الرهان (يُحسم في الخادم)'),
      _chips<int>(const [0, 10, 50, 100, 500, 1000], _stake, (s) => s == 0 ? 'ودّي' : '$s', (s) => _stake = s),
      const SizedBox(height: 8),
      Text(
        vsComputer
            ? '🏆 الفوز ضد الكمبيوتر: جائزة 50 نقطة من الخادم (حسب الأهلية والحد اليومي).'
            : '🏆 مباراة بأربعة لاعبين حقيقيين: جائزة الفائز 200 نقطة + 2 💎 من الخادم. المقاعد الفارغة عند البدء يلعبها الكمبيوتر (جائزتها 50).',
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12),
      ),
      const SizedBox(height: 4),
      const Text('🔥 الدبل: من يملك شايب الكبّة أو بنتًا يستطيع دبلها؛ آكلها يخسر الضعف وصاحب الدبل يكسب قيمتها.',
          textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white54, fontSize: 11.5)),
    ]);
  }

  // ───── التبويبات ─────
  Widget _vsComputerTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _setupForm(vsComputer: true),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  final id = await _tdb.rpc('trix_start_game', params: {
                    'p_mode': _mode,
                    'p_variant': _variant,
                    'p_stake': _stake,
                    'p_room_id': widget.roomId,
                  });
                  if (!mounted) return;
                  Navigator.of(context).maybePop();
                  playServerSound('game_start');
                  TrixWindow.instance.openGame(id.toString());
                }),
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text('ابدأ ضد الكمبيوتر'),
      ),
    ]);
  }

  Widget _tableTab() {
    final t = _table;
    if (_tableId == null || t == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _setupForm(vsComputer: false),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final id = await _tdb.rpc('trix_table_create', params: {
                      'p_mode': _mode,
                      'p_variant': _variant,
                      'p_stake': _stake,
                      'p_room_id': widget.roomId,
                    });
                    _tableId = id.toString();
                    await _loadTable();
                  }),
          icon: const Icon(Icons.table_restaurant_rounded),
          label: const Text('أنشئ طاولة وادعُ اللاعبين'),
        ),
      ]);
    }
    final seats = (t['seats'] as List?) ?? const [null, null, null, null];
    final names = (t['names'] as List?) ?? const [null, null, null, null];
    final invites = ((t['invites'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final isHost = t['is_host'] == true;
    final partner = t['mode'] == 'partner';
    final mySeat = (t['my_seat'] as num?)?.toInt() ?? 0;

    Widget seatTile(int s) {
      final occupied = s < seats.length && seats[s] != null;
      final inv = invites.where((x) => (x['seat'] as num?)?.toInt() == s).toList();
      final role = s == mySeat
          ? 'أنت'
          : (partner ? ((s - mySeat) % 2 == 0 ? 'شريك' : 'خصم') : 'لاعب');
      return Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: occupied ? const Color(0x3343A047) : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: s == mySeat ? const Color(0xFFFFD54F) : Colors.white24),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('مقعد ${s + 1} • $role', style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
          const SizedBox(height: 4),
          Text(
            occupied ? (names[s]?.toString() ?? 'لاعب') : (inv.isNotEmpty ? '⏳ ${inv.first['name']}' : 'فارغ (كمبيوتر)'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: occupied ? Colors.white : Colors.white60, fontWeight: FontWeight.w800),
          ),
          if (!occupied && isHost)
            TextButton(
              onPressed: _busy ? null : () => _invitePicker(s),
              child: Text(inv.isNotEmpty ? 'تغيير الدعوة' : 'دعوة لاعب'),
            ),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(
        '${partner ? 'شراكة 2×2' : 'فردي'} • ${trixVariantName[t['variant']] ?? ''}${((t['stake'] as num?) ?? 0) > 0 ? ' • رهان ${t['stake']}' : ''}',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      // ترتيب الطاولة كما في اللعب: الشريك مقابلك، والخصمان يمينًا ويسارًا.
      Center(child: seatTile((mySeat + 2) % 4)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        seatTile((mySeat + 3) % 4),
        const Text('🃏', style: TextStyle(fontSize: 34)),
        seatTile((mySeat + 1) % 4),
      ]),
      const SizedBox(height: 8),
      Center(child: seatTile(mySeat)),
      const SizedBox(height: 14),
      if (isHost)
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final gid = await _tdb.rpc('trix_table_start', params: {'p_table': _tableId});
                    if (!mounted) return;
                    Navigator.of(context).maybePop();
                    playServerSound('game_start');
                    TrixWindow.instance.openGame(gid.toString());
                  }),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ابدأ المباراة (الفارغ يلعبه الكمبيوتر)'),
        )
      else
        const Text('بانتظار المضيف ليبدأ المباراة…', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  await _tdb.rpc('trix_table_leave', params: {'p_table': _tableId});
                  setState(() {
                    _tableId = null;
                    _table = null;
                  });
                }),
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: Text(isHost ? 'إلغاء الطاولة' : 'مغادرة الطاولة', style: const TextStyle(color: Colors.redAccent)),
      ),
    ]);
  }

  Future<void> _invitePicker(int seat) async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PlayerSearchDialog(),
    );
    if (picked == null || !mounted) return;
    await _run(() async {
      await _tdb.rpc('trix_table_invite', params: {'p_table': _tableId, 'p_to': picked['id'], 'p_seat': seat});
      _snack('تم إرسال الدعوة إلى ${picked['name']} ✓');
      await _loadTable();
    });
  }

  Widget _openTab() {
    if (_open.isEmpty) {
      return const Center(child: Text('لا توجد طاولات مفتوحة الآن.', style: TextStyle(color: Colors.white60)));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final t in _open)
        Card(
          color: const Color(0xFF221A33),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${t['mode'] == 'partner' ? 'شراكة 2×2' : 'فردي'} • ${trixVariantName[t['variant']] ?? ''} • المضيف: ${((t['names'] as List?) ?? const [])[0] ?? ''}',
                  textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, textDirection: TextDirection.rtl, children: [
                for (var s = 1; s < 4; s++)
                  if (((t['seats'] as List?) ?? const [])[s] == null)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await _tdb.rpc('trix_table_join', params: {'p_table': t['id'], 'p_seat': s});
                                _tableId = t['id'].toString();
                                await _loadTable();
                                _tabs.animateTo(1);
                              }),
                      child: Text('اجلس بمقعد ${s + 1}${t['mode'] == 'partner' && s == 2 ? ' (شريك المضيف)' : ''}'),
                    ),
              ]),
            ]),
          ),
        ),
    ]);
  }

  Widget _invitesTab() {
    if (_invites.isEmpty) {
      return const Center(child: Text('لا توجد دعوات تركس.', style: TextStyle(color: Colors.white60)));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final x in _invites)
        Card(
          color: const Color(0xFF221A33),
          child: ListTile(
            title: Text('${x['from_name']} يدعوك', textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
                '${x['mode'] == 'partner' ? (x['seat'] == 2 ? 'شريكًا له' : 'خصمًا') : 'فردي'} • ${trixVariantName[x['variant']] ?? ''}${((x['stake'] as num?) ?? 0) > 0 ? ' • ${x['stake']} نقطة' : ''}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white60)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await _tdb.rpc('trix_table_respond', params: {'p_invite': x['id'], 'p_accept': false});
                          await _loadInvites();
                        }),
              ),
              IconButton(
                icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final tid = await _tdb.rpc('trix_table_respond', params: {'p_invite': x['id'], 'p_accept': true});
                          _tableId = tid?.toString();
                          await _loadTable();
                          _tabs.animateTo(1);
                        }),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _designTab() => const TrixDesignPicker();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        const Text('🃏 تركس', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            const Tab(text: 'ضد الكمبيوتر'),
            Tab(text: _tableId != null ? 'طاولتي ●' : 'طاولة لاعبين'),
            const Tab(text: 'طاولات مفتوحة'),
            Tab(text: _invites.isNotEmpty ? 'دعواتي (${_invites.length})' : 'دعواتي'),
            const Tab(text: 'تصميم الورق'),
          ],
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _vsComputerTab(),
            _tableTab(),
            _openTab(),
            _invitesTab(),
            _designTab(),
          ]),
        ),
      ]),
    );
  }
}

class _PlayerSearchDialog extends StatefulWidget {
  const _PlayerSearchDialog();
  @override
  State<_PlayerSearchDialog> createState() => _PlayerSearchDialogState();
}

class _PlayerSearchDialogState extends State<_PlayerSearchDialog> {
  final _q = TextEditingController();
  Timer? _deb;
  List<Map<String, dynamic>> _players = const [];

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
      final raw = await _tdb.rpc('search_game_players', params: {'p_query': _q.text});
      if (raw is List && mounted) {
        setState(() => _players = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF171126),
      title: const Text('دعوة لاعب', style: TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
      content: SizedBox(
        width: 340,
        height: 420,
        child: Column(children: [
          TextField(
            controller: _q,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'ابحث بالاسم…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), _search);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (final p in _players)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 10, color: p['online'] == true ? Colors.greenAccent : Colors.white24),
                  title: Text(p['name']?.toString() ?? 'عضو', textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// اختيار تصميم وجه الورق وظهره — يُحفظ في الخادم ويُطبَّق فورًا.
class TrixDesignPicker extends StatefulWidget {
  const TrixDesignPicker({super.key});
  @override
  State<TrixDesignPicker> createState() => _TrixDesignPickerState();
}

class _TrixDesignPickerState extends State<TrixDesignPicker> {
  @override
  void initState() {
    super.initState();
    TrixPrefs.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      const Text('وجه الورق', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), textDirection: TextDirection.rtl),
      const SizedBox(height: 8),
      ValueListenableBuilder<String>(
        valueListenable: TrixPrefs.face,
        builder: (_, sel, __) => Wrap(spacing: 10, runSpacing: 10, textDirection: TextDirection.rtl, children: [
          for (final f in TrixPrefs.faces)
            GestureDetector(
              onTap: () => TrixPrefs.setFace(f['key'].toString()),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: sel == f['key'] ? const Color(0xFFFFC107) : Colors.transparent, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PlayingCard(card: 'H13', width: 38, height: 54, face: f['key'].toString()),
                    const SizedBox(width: 2),
                    PlayingCard(card: 'D12', width: 38, height: 54, face: f['key'].toString()),
                  ]),
                ),
                const SizedBox(height: 3),
                Text(f['name'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      const Text('ظهر الورق', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), textDirection: TextDirection.rtl),
      const SizedBox(height: 8),
      ValueListenableBuilder<String>(
        valueListenable: TrixPrefs.back,
        builder: (_, sel, __) => Wrap(spacing: 10, runSpacing: 10, textDirection: TextDirection.rtl, children: [
          for (final b in TrixPrefs.backs)
            GestureDetector(
              onTap: () => TrixPrefs.setBack(b['key'].toString()),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel == b['key'] ? const Color(0xFFFFC107) : Colors.transparent, width: 2),
                  ),
                  child: CardBack(params: b['params'] is Map ? Map<String, dynamic>.from(b['params'] as Map) : null, width: 40, height: 58),
                ),
                const SizedBox(height: 2),
                Text(b['name'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
