part of 'trix_game.dart';

// ───────────────────────── أدوات قراءة عرض الخادم ─────────────────────────

int _ti(Object? x, [int d = 0]) {
  if (x is num) return x.toInt();
  return int.tryParse('${x ?? ''}') ?? d;
}

List<int> _tints(Object? x, int n, [int d = 0]) {
  final l = x is List ? x : const <Object?>[];
  return List<int>.generate(n, (i) => i < l.length ? _ti(l[i], d) : d);
}

List<String> _tstrs(Object? x) => x is List ? x.map((e) => '$e').toList() : <String>[];

Map<String, dynamic> _tmap(Object? x) => x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};

List<Map<String, dynamic>> _tmaps(Object? x) => x is List
    ? x.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// مواقع نسبية على الطاولة: 0 أنا (أسفل)، 1 يمين، 2 أعلى (الشريك)، 3 يسار.
const List<Alignment> _kEdge = [
  Alignment(0, 1.3),
  Alignment(1.3, -0.05),
  Alignment(0, -1.3),
  Alignment(-1.3, -0.05),
];
const List<Alignment> _kSlot = [
  Alignment(0, 0.36),
  Alignment(0.36, -0.04),
  Alignment(0, -0.40),
  Alignment(-0.36, -0.04),
];
const List<Alignment> _kSeat = [
  Alignment(0, 1.0),
  Alignment(1.0, -0.08),
  Alignment(0, -1.0),
  Alignment(-1.0, -0.08),
];
const List<double> _kTilt = [-0.04, 0.10, 0.03, -0.09];

// ───────────────────────── محرّك الحركة العام ─────────────────────────

/// حركة لمرة واحدة: تبدأ عند التركيب (بعد تأخير اختياري) وتستدعي onDone عند
/// انتهائها. المفتاح يضمن أن الورقة لا تُعاد حركتها عند كل تحديث.
class _Anim extends StatefulWidget {
  final Duration duration;
  final Duration delay;
  final Widget Function(BuildContext context, double t) builder;
  final VoidCallback? onDone;
  const _Anim({
    super.key,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.onDone,
  });

  @override
  State<_Anim> createState() => _AnimState();
}

class _AnimState extends State<_Anim> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _wait;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
    if (widget.delay <= Duration.zero) {
      _started = true;
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (!mounted) return;
        setState(() => _started = true);
        _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return AnimatedBuilder(animation: _c, builder: (ctx, _) => widget.builder(ctx, _c.value));
  }
}

/// أنواع حركة السمايلات على الطاولة.
class _RxStyle {
  const _RxStyle._();
  static const int wobble = 0;  // 😂
  static const int pop = 1;     // 😮
  static const int flicker = 2; // 🔥
  static const int pulse = 3;   // 👏
  static const int droop = 4;   // 😭
  static const int punch = 5;   // 💪
  static const int burst = 6;   // 🤯
  static const int float = 7;   // 🧠
  static const int slide = 8;   // 😎
  static const int shrink = 9;  // 🙈
}

/// سمايل + مفتاح نغمته في الخادم + نوع حركته.
class _Reaction {
  final String e;
  final String sound;
  final int style;
  const _Reaction(this.e, this.sound, this.style);
}

/// ناتج دالة الحركة لإطار واحد.
class _RxMotion {
  final double dx;
  final double dy;
  final double rise;
  final double scale;
  final double angle;
  final double alpha;
  const _RxMotion({
    this.dx = 0,
    this.dy = 0,
    this.rise = 0,
    this.scale = 1,
    this.angle = 0,
    this.alpha = 1,
  });
}

class _Fx {
  final int id;
  final Widget child;
  _Fx(this.id, this.child);
}

class _Particle {
  final double angle;
  final double dist;
  final double spin;
  final double size;
  final String e;
  _Particle(math.Random r, this.e)
      : angle = r.nextDouble() * math.pi * 2,
        dist = 0.45 + r.nextDouble() * 0.7,
        spin = (r.nextDouble() - 0.5) * 7,
        size = 15 + r.nextDouble() * 15;
}

/// ورقة تنقلب ثلاثي الأبعاد من الظهر إلى الوجه (t: 0 ظهر → 1 وجه).
Widget _flipCard(String card, double t,
    {required bool flip, double w = 46, double h = 66, bool glow = false, Color? glowColor}) {
  final face = PlayingCard(card: card, width: w, height: h, glow: glow, glowColor: glowColor);
  if (!flip || t >= 1) return face;
  final ang = (1 - t) * math.pi;
  final back = ang > math.pi / 2;
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateY(ang),
    child: back
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: CardBack(params: TrixPrefs.backParams, width: w, height: h),
          )
        : face,
  );
}

Widget _particleAt(_Particle p, double t, {Alignment origin = const Alignment(0, -0.1)}) {
  final k = ((t - 0.05) / 0.72).clamp(0.0, 1.0);
  if (k <= 0 || k >= 1) return const SizedBox.shrink();
  final e = Curves.easeOutCubic.transform(k);
  final x = origin.x + math.cos(p.angle) * p.dist * e;
  final y = origin.y + math.sin(p.angle) * p.dist * e + 0.35 * k * k;
  return Positioned.fill(
    child: Align(
      alignment: Alignment(x, y),
      child: Opacity(
        opacity: (1 - k).clamp(0.0, 1.0),
        child: Transform.rotate(angle: p.spin * k, child: Text(p.e, style: TextStyle(fontSize: p.size))),
      ),
    ),
  );
}

Widget _fxLabel(String title, String sub, Color color, double glow) {
  return Container(
    constraints: const BoxConstraints(maxWidth: 300),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xE6140E22),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color, width: 2),
      boxShadow: [BoxShadow(color: color.withAlpha((80 + 120 * glow).round().clamp(0, 255)), blurRadius: 10 + 10 * glow)],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
      if (sub.isNotEmpty)
        Text(sub,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 16)),
    ]),
  );
}

// ───────────────────────── شاشة المباراة ─────────────────────────

/// شاشة التركس: عرض فقط — كل حركة تُرسل للخادم وكل حالة تأتي منه.
/// المزامنة: Realtime على صف المباراة + استطلاع احتياطي كل 1.5 ثانية.
/// التأثيرات تُشتق من الفرق بين عرضين متتاليين من الخادم، فتظهر على كل
/// الأجهزة بالشكل نفسه (رمي، جمع، أكل الشايب/البنات/الديناري، لطش، دبل...).
class TrixScreen extends StatefulWidget {
  final String gameId;
  final TrixWindowMode mode;
  const TrixScreen({super.key, required this.gameId, this.mode = TrixWindowMode.full});

  @override
  State<TrixScreen> createState() => _TrixScreenState();
}

class _TrixTableSurfacePainter extends CustomPainter {
  final Animation<double> animation;
  final Color accent;

  _TrixTableSurfacePainter({
    required this.animation,
    required this.accent,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = animation.value;
    final bounds = Offset.zero & size;
    final radius = Radius.circular(math.min(size.width, size.height) * 0.14);
    final outer = RRect.fromRectAndRadius(bounds.deflate(3), radius);

    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0x66F8DFA1),
    );

    final ring = Rect.fromLTWH(
      size.width * 0.105,
      size.height * 0.12,
      size.width * 0.79,
      size.height * 0.76,
    );
    final ringAlpha = (34 + 24 * (0.5 + 0.5 * math.sin(t * math.pi * 2))).round().clamp(0, 255).toInt();
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFFFD166).withAlpha(ringAlpha),
    );
    canvas.drawOval(
      ring.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withAlpha(15),
    );

    void drawSuit(String suit, double x, double y, Color color) {
      final painter = TextPainter(
        text: TextSpan(
          text: suit,
          style: TextStyle(
            color: color,
            fontSize: math.min(size.width, size.height) * 0.065,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(size.width * x, size.height * y));
    }

    drawSuit('♠', 0.19, 0.25, Colors.white.withAlpha(22));
    drawSuit('♥', 0.76, 0.25, const Color(0x33FFD166));
    drawSuit('♣', 0.19, 0.67, Colors.white.withAlpha(22));
    drawSuit('♦', 0.76, 0.67, const Color(0x33FFD166));

    // A soft moving light gives the felt depth without covering cards or seats.
    final bandWidth = math.max(42.0, size.width * 0.22);
    final shine = Rect.fromLTWH(
      -bandWidth + t * (size.width + bandWidth),
      0,
      bandWidth,
      size.height,
    );
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRect(
      shine,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x00000000),
            Color(0x15FFFFFF),
            Color(0x00000000),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(shine),
    );
    canvas.restore();

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.3, size.height * 0.32, size.width * 0.4, size.height * 0.36),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accent.withAlpha((18 + 20 * (0.5 + 0.5 * math.sin(t * math.pi * 2))).round().clamp(0, 255).toInt()),
    );

    // ── حركة محيطة دائمة على سطح الطاولة ──────────────────────────────
    // كل ما يلي داخل clip الطاولة ورسمه خفيف (لا صور ولا ظلال)، ويتحرّك
    // مع المتحكّم نفسه فلا يضيف أي مؤقّت. الشفافيات منخفضة عن قصد كي لا
    // تزاحم الأوراق أو أسماء اللاعبين.
    canvas.save();
    canvas.clipRRect(outer);

    // 1) ذرّات رموز الكوتشينة تطفو ببطء وتلتفّ — عمق بصري بلا تشتيت.
    const motes = 14;
    const syms = ['♠', '♥', '♦', '♣'];
    for (var i = 0; i < motes; i++) {
      final seed = i / motes;
      // مسار ليساجو: حركة ناعمة غير دورية ظاهريًا بلا عشوائية لكل إطار.
      final ph = t * math.pi * 2 + seed * math.pi * 2;
      final x = size.width * (0.5 + 0.40 * math.sin(ph * 0.7 + seed * 5.1));
      final y = size.height * (0.5 + 0.34 * math.cos(ph * 0.5 + seed * 3.3));
      final tw = 0.5 + 0.5 * math.sin(ph * 1.7);
      final tp = TextPainter(
        text: TextSpan(
          text: syms[i % syms.length],
          style: TextStyle(
            fontSize: math.min(size.width, size.height) * (0.028 + 0.012 * tw),
            color: (i.isEven ? Colors.white : const Color(0xFFFFD166))
                .withAlpha((12 + 16 * tw).round().clamp(0, 255)),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(ph * 0.9 + seed) * 0.5);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // 2) وميض دوّار بلون العقد حول مركز الطاولة.
    final sweepCenter = Offset(size.width / 2, size.height * 0.5);
    final sweepR = math.max(size.width, size.height) * 0.62;
    canvas.drawCircle(
      sweepCenter,
      sweepR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: GradientRotation(t * math.pi * 2),
          colors: [
            const Color(0x00000000),
            accent.withAlpha(16),
            const Color(0x00000000),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.12, 0.3, 1.0],
        ).createShader(Rect.fromCircle(center: sweepCenter, radius: sweepR)),
    );

    // 3) تعتيم حواف (vignette) يرفع تباين الأوراق في الوسط.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: const [Color(0x00000000), Color(0x00000000), Color(0x4D000000)],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(bounds),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrixTableSurfacePainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.accent != accent;
}

class _TrixScreenState extends State<TrixScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _v;
  String? _error;
  String _sig = '';
  bool _fetching = false;
  bool _again = false;
  bool _acting = false;
  Timer? _poll;
  Duration? _pollEvery;
  Timer? _drive;
  Timer? _clock;
  RealtimeChannel? _ch;
  Duration _skew = Duration.zero;
  DateTime _animUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_Fx> _fx = <_Fx>[];
  int _fxSeq = 0;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  late final AnimationController _tableGlow =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));
  double _shakeAmp = 0;
  String? _pending;
  Set<String> _shownTrick = <String>{};
  String _contractKey = '';
  String? _toast;
  Timer? _toastTimer;
  bool _askResign = false;
  bool _showDesign = false;
  bool _showResult = false;
  final Set<String> _dblSel = <String>{};
  bool _wasMyTurn = false;

  @override
  void initState() {
    super.initState();
    _tableGlow.repeat();
    TrixPrefs.face.addListener(_prefsChanged);
    TrixPrefs.back.addListener(_prefsChanged);
    unawaited(TrixPrefs.load().then((_) => _prefsChanged()));
    _bind();
    _drive = Timer.periodic(RealtimeTuning.active, (_) => _driveTick());
    _clock = Timer.periodic(RealtimeTuning.uiClock, (_) {
      if (mounted && _v?['status'] == 'active') setState(() {});
    });
  }

  void _prefsChanged() {
    if (mounted) setState(() {});
  }

  /// إعادة بناء قناة اللعبة وحدها عند انقطاعها.
  ///
  /// لا تُستدعى _bind لأنّها تُصفّر حالة اللعبة كاملةً (_v والتأثيرات
  /// والاختيارات) — فانقطاع شبكة لحظي كان سيُفرغ الطاولة أمام اللاعب
  /// في منتصف يده.
  void _rebindChannel() {
    if (!mounted) return;
    final gid = widget.gameId;
    final dead = _ch;
    _ch = null;
    if (dead != null) unawaited(_tdb.removeChannel(dead));
    try {
      _ch = _tdb.channel('trix_game_${gid}_${DateTime.now().millisecondsSinceEpoch}')
        ..onBroadcast(event: 'trix_react', callback: _onReactBroadcast)
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trix_games',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: gid),
          callback: (_) => _refresh(),
        )
        ..subscribe(retryOnChannelError(_rebindChannel, isAlive: () => mounted));
    } catch (_) {}
    unawaited(_refresh());
  }

  void _bind() {
    _unbind();
    final gid = widget.gameId;
    _v = null;
    _sig = '';
    _error = null;
    _fx.clear();
    _pending = null;
    _shownTrick = <String>{};
    _contractKey = '';
    _showResult = false;
    _askResign = false;
    _showDesign = false;
    _dblSel.clear();
    _wasMyTurn = false;
    try {
      _ch = _tdb.channel('trix_game_$gid')
        ..onBroadcast(event: 'trix_react', callback: _onReactBroadcast)
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trix_games',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: gid),
          callback: (_) => _refresh(),
        )
        // بلا معالج كان RealtimeSubscribeException يهرب إلى المنطقة
        // فيُسجَّل خطأً قاتلًا — أكثر خطأ تكرارًا في سجلّ المراقبة.
        ..subscribe(retryOnChannelError(
          _rebindChannel,
          isAlive: () => mounted,
        ));
    } catch (_) {}
    _repoll(RealtimeTuning.active);
    unawaited(_refresh());
  }

  /// يعيد ضبط نبضة الاستطلاع إذا تغيّر المدى المطلوب فقط (لا يعيد إنشاء
  /// المؤقّت كل تحديث). الحارس `_fetching` في `_refresh` يمنع تراكم الطلبات:
  /// إن تأخّر الخادم فالنبضة التالية تُعلَّم `_again` ولا تفتح طلبًا ثانيًا،
  /// فالتسريع إلى 120ms لا يقدر على إغراق الخادم.
  void _repoll(Duration d) {
    final want = RealtimeTuning.clamp(d);
    if (_poll != null && _pollEvery == want) return;
    _pollEvery = want;
    _poll?.cancel();
    _poll = Timer.periodic(want, (_) => _refresh());
  }

  void _unbind() {
    _poll?.cancel();
    _poll = null;
    _pollEvery = null;
    final ch = _ch;
    _ch = null;
    if (ch != null) unawaited(_tdb.removeChannel(ch));
  }

  @override
  void didUpdateWidget(covariant TrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) _bind();
  }

  @override
  void dispose() {
    _unbind();
    _drive?.cancel();
    _clock?.cancel();
    _toastTimer?.cancel();
    TrixPrefs.face.removeListener(_prefsChanged);
    TrixPrefs.back.removeListener(_prefsChanged);
    _tableGlow.dispose();
    _shake.dispose();
    super.dispose();
  }

  // ───── الوقت ─────
  DateTime get _serverNow => DateTime.now().toUtc().add(_skew);
  DateTime? _ts(Object? x) => DateTime.tryParse('${x ?? ''}')?.toUtc();

  String _name(int seat) {
    final n = _tstrs(_v?['names']);
    return seat >= 0 && seat < n.length ? n[seat] : 'لاعب';
  }

  String _who(int seat) => seat == _ti(_v?['me']) ? 'أنت' : _name(seat);

  void _say(String msg) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ───── المزامنة ─────
  Future<void> _refresh() async {
    if (!mounted) return;
    if (_fetching) {
      _again = true;
      return;
    }
    _fetching = true;
    final gid = widget.gameId;
    try {
      final raw = await _tdb.rpc('trix_my_view', params: {'p_game': gid});
      if (!mounted || gid != widget.gameId || raw is! Map) return;
      final v = Map<String, dynamic>.from(raw);
      final sn = _ts(v['server_now']);
      if (sn != null) _skew = sn.difference(DateTime.now().toUtc());
      final sig = '${v['seq']}|${v['updated_at']}|${v['status']}';
      if (sig == _sig && _v != null) return;
      _sig = sig;
      final prev = _v;
      final shownBefore = <String>{..._shownTrick, if (_pending != null) _pending!};
      final hand = _tstrs(v['hand']);
      setState(() {
        _v = v;
        _error = null;
        if (_pending != null && !hand.contains(_pending)) _pending = null;
      });
      _onDiff(prev, v, shownBefore);
    } catch (e) {
      if (mounted && _v == null) setState(() => _error = trixErrorText(e));
    } finally {
      _fetching = false;
      if (_again && mounted) {
        _again = false;
        unawaited(_refresh());
      }
    }
  }

  /// يحرّك الكمبيوتر/التسليم/انتهاء مهلة الدبل/اللاعب الغائب — الخادم يتحقق
  /// من كل شرط ويرفض المبكر، والعميل فقط يختار التوقيت كي لا يُغرق الخادم.
  Future<void> _driveTick() async {
    final v = _v;
    if (v == null || !mounted || _acting || v['status'] != 'active') return;
    final now = DateTime.now();
    if (now.isBefore(_animUntil)) return;
    final sNow = _serverNow;
    final upd = _ts(v['updated_at']);
    if (upd == null) return;
    final since = sNow.difference(upd).inMilliseconds;
    final phase = '${v['phase']}';
    final turn = _ti(v['turn'], -1);
    final seats = (v['seats'] as List?) ?? const [];
    final me = _ti(v['me']);
    final pend = _tstrs(v['double_pending']);
    var need = false;
    if (phase == 'handover') {
      need = since >= 2050;
    } else if (phase == 'play' && pend.isNotEmpty) {
      final dl = _ts(v['phase_deadline']);
      need = dl != null && sNow.isAfter(dl.add(const Duration(milliseconds: 150)));
    } else if (turn >= 0 && turn < seats.length) {
      if (seats[turn] == null) {
        final trickEmpty = _tmaps(v['trick']).isEmpty;
        final lt = v['last_trick'];
        final gap = (phase == 'play' && trickEmpty && lt is Map && lt['n'] != null) ? 1150 : 480;
        need = since >= gap;
      } else if (turn != me) {
        need = since >= 30500;
      }
    }
    if (!need) return;
    _acting = true;
    try {
      final r = await _tdb.rpc('trix_bot_step', params: {'p_game': widget.gameId});
      if (r == true) await _refresh();
    } catch (_) {
    } finally {
      _acting = false;
    }
  }

  // ───── الفرق بين عرضين → تأثيرات وأصوات ─────
  void _onDiff(Map<String, dynamic>? p, Map<String, dynamic> v, Set<String> shownBefore) {
    final me = _ti(v['me']);
    final phase = '${v['phase']}';
    final status = '${v['status']}';
    final contract = v['contract']?.toString();
    final trickNow = _tmaps(v['trick']);
    _shownTrick = trickNow.map((e) => '${e['c']}').toSet();
    final key = '${v['kingdom']}-${v['hand_no']}-$contract';

    if (p == null) {
      _contractKey = key;
      _updateTurn(v, sound: false);
      if (status == 'finished') setState(() => _showResult = true);
      // أول عرض لهذه الشاشة. نوزّع الأوراق فقط إن كانت اليد في بدايتها
      // تمامًا: 13 ورقة لكل مقعد، ولا أوراق على الطاولة، وطور اختيار
      // العقد. بهذا يظهر التوزيع في أول يد من المباراة، ولا يُعاد
      // تشغيله عند إعادة فتح النافذة في منتصف اللعب.
      final sizes = _tints(v['hand_sizes'], 4, 0);
      if (status == 'active' &&
          phase == 'choose' &&
          _tmaps(v['trick']).isEmpty &&
          sizes.every((n) => n == 13)) {
        _dealFx();
      }
      return;
    }

    var after = 0;
    // ① إعلان العقد
    if (contract != null && (phase == 'play' || phase == 'handover') && key != _contractKey) {
      _contractKey = key;
      _revealContract(contract, _ti(v['owner']));
      after = 1500;
    } else if (phase == 'choose') {
      _contractKey = key;
    }

    final sameHand = p['kingdom'] == v['kingdom'] && p['hand_no'] == v['hand_no'];

    // يد جديدة ⇒ توزيع الأوراق. يُشتق من تغيّر (المملكة، رقم اللعبة) الآتي
    // من الخادم، فيظهر التوزيع على كل الأجهزة في اللحظة نفسها.
    if (!sameHand && status == 'active') {
      _dealFx();
      after = math.max(after, 900);
    }

    // ② الدبل
    if (phase == 'play' || phase == 'handover') {
      final pd = sameHand ? _tmap(p['doubles']) : <String, dynamic>{};
      var k = 0;
      for (final e in _tmap(v['doubles']).entries) {
        if (pd.containsKey(e.key)) continue;
        _doubleFx(e.key, _ti(e.value), delayMs: after + 380 * k);
        k++;
      }
    }

    // ③ اكتمال أكلة / وضع ورقة في التركس
    final lt = v['last_trick'] is Map ? _tmap(v['last_trick']) : null;
    final plt = p['last_trick'] is Map ? _tmap(p['last_trick']) : null;
    var collected = false;
    if (lt != null && lt.toString() != plt?.toString()) {
      if (lt['trix'] == true) {
        playServerSound('trix_place');
      } else if (lt['n'] != null) {
        collected = true;
        _trickDone(v, lt, shownBefore, contract);
      }
    }
    if (!collected) {
      final pTrick = _tmaps(p['trick']).map((e) => '${e['c']}').toSet();
      final fresh = trickNow.where((e) => _ti(e['s']) != me && !pTrick.contains('${e['c']}'));
      if (fresh.isNotEmpty) playServerSound('card_throw');
    }

    // ④ ميداليات التركس (من أنهى أوراقه)
    if (contract == 'trix' && sameHand) {
      final pf = _tstrs(p['finish_order']);
      final vf = _tstrs(v['finish_order']);
      final sizes = _tints(v['hand_sizes'], 4, 13);
      for (var i = pf.length; i < vf.length && i < 4; i++) {
        final s = _ti(vf[i]);
        if (s >= 0 && s < 4 && sizes[s] == 0) _medalFx(s, i);
      }
    }

    // ⑤ نافذة الدبل لي
    final myDbl = _tstrs(v['my_doublable']);
    if (myDbl.isNotEmpty && _tstrs(p['my_doublable']).isEmpty) {
      _dblSel.clear();
      playServerSound('my_turn');
    }

    // ⑥ دوري
    _updateTurn(v, sound: true);

    // ⑦ النهاية
    if (status == 'finished' && p['status'] != 'finished') {
      Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        final r = _outcome(v);
        playServerSound(r > 0 ? 'game_win' : (r < 0 ? 'game_lose' : 'game_draw'));
        setState(() => _showResult = true);
      });
    }
  }

  void _updateTurn(Map<String, dynamic> v, {required bool sound}) {
    final me = _ti(v['me']);
    final ph = '${v['phase']}';
    final mine = v['status'] == 'active' &&
        _ti(v['turn'], -1) == me &&
        (ph == 'play' || ph == 'choose') &&
        _tstrs(v['double_pending']).isEmpty;
    if (mine && !_wasMyTurn && sound) {
      playServerSound('my_turn');
      // اهتزاز خفيف مع نغمة الدور: ينبّه اللاعب حتى لو كان الصوت مكتومًا.
      unawaited(HapticFeedback.selectionClick());
    }
    _wasMyTurn = mine;
    TrixWindow.instance.myTurn.value = mine;
    // سرعة المزامنة تتبع الحالة: 120ms وقت دوري أو أثناء حركة جارية،
    // 220ms داخل مباراة، 400ms إن انتهت. كلها داخل المدى 100–400ms.
    if (v['status'] != 'active') {
      _repoll(RealtimeTuning.idle);
    } else {
      _repoll(RealtimeTuning.pick(
        myTurn: mine,
        animating: DateTime.now().isBefore(_animUntil) || _fx.isNotEmpty,
      ));
    }
  }

  /// 1 فوز، 0 تعادل، −1 خسارة.
  int _outcome(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final res = _tmap(v['result']);
    final sc = _tints(v['scores'], 4);
    final partner = v['mode'] == 'partner';
    if (res['resigned'] != null) {
      final r = _ti(res['resigned']);
      final lost = r == me || (partner && r % 2 == me % 2);
      return lost ? -1 : 1;
    }
    if (partner) {
      final mine = sc[me] + sc[(me + 2) % 4];
      final opp = sc[(me + 1) % 4] + sc[(me + 3) % 4];
      return mine == opp ? 0 : (mine > opp ? 1 : -1);
    }
    final best = sc.reduce(math.max);
    return sc[me] == best ? 1 : -1;
  }

  // ───── تفاعلات السمايلات الحيّة ─────

  /// السمايلات المتاحة على الطاولة. تُبثّ لحظيًا لكل اللاعبين عبر نفس قناة
  /// Realtime الخاصة بالمباراة (بثّ فقط — لا يُكتب شيء في قاعدة البيانات،
  /// فلا تكلفة تخزين ولا أثر على منطق اللعبة).
  ///
  /// لكل سمايل نغمته الخاصة المخزَّنة في **الخادم** (جدول app_sounds)،
  /// تُنزَّل عند أول استخدام وتُخزَّن في الذاكرة. لا ملف صوت واحد داخل
  /// المشروع: لتغيير أي نغمة يكفي تحديث صفّها في الخادم بلا تحديث للتطبيق.
  static const List<_Reaction> kReactions = <_Reaction>[
    _Reaction('😂', 'react_laugh', _RxStyle.wobble),
    _Reaction('😮', 'react_wow', _RxStyle.pop),
    _Reaction('🔥', 'react_fire', _RxStyle.flicker),
    _Reaction('👏', 'react_clap', _RxStyle.pulse),
    _Reaction('😭', 'react_cry', _RxStyle.droop),
    _Reaction('💪', 'react_strong', _RxStyle.punch),
    _Reaction('🤯', 'react_mind', _RxStyle.burst),
    _Reaction('🧠', 'react_think', _RxStyle.float),
    _Reaction('😎', 'react_cool', _RxStyle.slide),
    _Reaction('🙈', 'react_shy', _RxStyle.shrink),
  ];

  static _Reaction? _reactionFor(String e) {
    for (final r in kReactions) {
      if (r.e == e) return r;
    }
    return null;
  }

  bool _reactOpen = false;
  DateTime _lastReactSent = DateTime.fromMillisecondsSinceEpoch(0);

  void _onReactBroadcast(Map<String, dynamic> payload) {
    if (!mounted) return;
    final seat = _ti(payload['seat'], -1);
    final e = '${payload['e'] ?? ''}';
    final rx = _reactionFor(e);
    // لا نعيد عرض سمايلتنا (عُرضت محليًا فورًا)، ولا نقبل رمزًا خارج القائمة
    // كي لا يتمكّن أحد من بثّ نصّ طويل أو محتوى غير متوقّع على طاولتك.
    if (seat < 0 || seat > 3 || seat == _ti(_v?['me']) || rx == null) return;
    _reactFx(seat, rx);
  }

  Future<void> _sendReact(_Reaction rx) async {
    final now = DateTime.now();
    // خانق محلي: سمايلة كل 700ms كحدّ أقصى (منع إغراق الطاولة).
    if (now.difference(_lastReactSent).inMilliseconds < 700) return;
    _lastReactSent = now;
    final me = _ti(_v?['me']);
    _reactFx(me, rx); // عرض وصوت فوريان عندي بلا انتظار الشبكة
    try {
      await _ch?.sendBroadcastMessage(
        event: 'trix_react',
        payload: <String, dynamic>{'seat': me, 'e': rx.e},
      );
    } catch (_) {
      // البثّ أثر تجميلي؛ فشله لا يُظهر خطأ للمستخدم.
    }
  }

  /// سمايلة تنبثق فوق مقعد اللاعب بحركة خاصة بنوعها، مع نغمتها من الخادم.
  void _reactFx(int seat, _Reaction rx) {
    playServerSound(rx.sound);
    final me = _ti(_v?['me']);
    final rel = (((seat - me) % 4) + 4) % 4;
    final from = _kSeat[rel];
    // المقعد العلوي ينزل قليلًا، والبقية تصعد — كي لا تخرج خارج الطاولة.
    final dir = rel == 2 ? 0.42 : -0.5;
    _addFx((done) => _Anim(
          duration: const Duration(milliseconds: 1600),
          onDone: done,
          builder: (ctx, t) {
            final m = _rxMotion(rx.style, t);
            final fade = t < 0.70 ? 1.0 : 1 - ((t - 0.70) / 0.30);
            return IgnorePointer(
              child: Align(
                alignment: Alignment(
                  (from.x + m.dx).clamp(-1.0, 1.0),
                  (from.y + dir * m.rise + m.dy).clamp(-1.25, 1.25),
                ),
                child: Opacity(
                  opacity: (fade * m.alpha).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: m.angle,
                    child: Transform.scale(
                      scale: m.scale,
                      child: Text(
                        rx.e,
                        style: const TextStyle(
                          fontSize: 34,
                          shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ));
  }

  /// حركة كل نوع. t من 0 إلى 1.
  static _RxMotion _rxMotion(int style, double t) {
    final rise = Curves.easeOutCubic.transform(t);
    final pop = t < 0.2 ? Curves.easeOutBack.transform(t / 0.2) : 1.0;
    final base = 0.55 + 0.85 * pop;
    switch (style) {
      case _RxStyle.wobble: // 😂 يهتزّ يمينًا ويسارًا وهو يصعد
        return _RxMotion(
          dx: math.sin(t * math.pi * 7) * 0.07 * (1 - t),
          rise: rise,
          scale: base * (1 + 0.10 * math.sin(t * math.pi * 7)),
          angle: math.sin(t * math.pi * 7) * 0.28,
        );
      case _RxStyle.pop: // 😮 قفزة حجم سريعة ثم صعود هادئ
        return _RxMotion(rise: rise, scale: base * (1 + 0.35 * math.exp(-10 * t)));
      case _RxStyle.flicker: // 🔥 ترجرج ناري
        return _RxMotion(
          dx: math.sin(t * math.pi * 5) * 0.045,
          rise: rise,
          scale: base * (1 + 0.14 * math.sin(t * math.pi * 13)),
          angle: math.sin(t * math.pi * 5) * 0.14,
        );
      case _RxStyle.pulse: // 👏 ثلاث نبضات مع التصفيق
        return _RxMotion(
          rise: rise * 0.75,
          scale: base * (1 + 0.28 * math.max(0.0, math.sin(t * math.pi * 6)) * (1 - t)),
        );
      case _RxStyle.droop: // 😭 ينزل قليلًا أولًا ثم يصعد منكسرًا
        return _RxMotion(
          dy: 0.10 * math.sin(t * math.pi) * 0.6,
          rise: rise * 0.8,
          scale: base * (1 - 0.12 * t),
          angle: 0.22 * math.sin(t * math.pi * 2),
        );
      case _RxStyle.punch: // 💪 ضربة حجم قوية ثم ثبات
        return _RxMotion(
          rise: rise * 0.6,
          scale: base * (1 + 0.55 * math.exp(-14 * t)),
          dx: math.sin(t * math.pi * 11) * 0.05 * math.exp(-6 * t),
        );
      case _RxStyle.burst: // 🤯 اهتزاز عنيف ثم تمدّد
        return _RxMotion(
          dx: math.sin(t * math.pi * 17) * 0.06 * math.exp(-4 * t),
          dy: math.cos(t * math.pi * 15) * 0.03 * math.exp(-4 * t),
          rise: rise * 0.9,
          scale: base * (1 + 0.45 * Curves.easeOut.transform(t.clamp(0.0, 1.0))),
          angle: math.sin(t * math.pi * 17) * 0.2 * math.exp(-4 * t),
        );
      case _RxStyle.float: // 🧠 طفو بطيء مع دوران لطيف
        return _RxMotion(
          dx: math.sin(t * math.pi * 2) * 0.05,
          rise: rise * 0.7,
          scale: base,
          angle: math.sin(t * math.pi * 2) * 0.18,
        );
      case _RxStyle.slide: // 😎 ينزلق من الجانب بثبات
        return _RxMotion(
          dx: -0.22 * (1 - Curves.easeOutCubic.transform(t)),
          rise: rise * 0.65,
          scale: base,
          angle: -0.18 * (1 - t),
        );
      case _RxStyle.shrink: // 🙈 ينكمش ويختبئ
        return _RxMotion(
          rise: rise * 0.5,
          scale: base * (1 - 0.35 * Curves.easeInCubic.transform(t)),
          angle: 0.3 * t,
        );
      default:
        return _RxMotion(rise: rise, scale: base);
    }
  }

  // ───── توزيع الأوراق في بداية كل يد ─────

  /// 13 ورقة × 4 مقاعد تنطلق من وسط الطاولة إلى المقاعد بتتابع، مع دوران
  /// وتقلّص. تأثير عرض فقط — الأوراق الحقيقية تأتي من الخادم، وهذا لا
  /// يؤثّر على أي منطق.
  void _dealFx() {
    playServerSound('card_throw');
    const perCard = 26; // ms بين ورقة وأخرى
    const flight = 420; // ms زمن طيران الورقة الواحدة
    const total = perCard * 52 + flight;
    final until = DateTime.now().add(Duration(milliseconds: total));
    if (until.isAfter(_animUntil)) _animUntil = until;
    // طقطقات متتابعة بدل 52 نداءً (الخانق في ServerSounds يبتلع المتزاحم).
    for (var k = 1; k <= 6; k++) {
      _later(k * 190, () => playServerSound('card_throw'));
    }
    final bp = TrixPrefs.backParams;
    _addFx((done) => _Anim(
          duration: Duration(milliseconds: total),
          onDone: done,
          builder: (ctx, t) {
            final elapsed = t * total;
            final cards = <Widget>[];
            for (var i = 0; i < 52; i++) {
              final start = i * perCard.toDouble();
              final k = ((elapsed - start) / flight).clamp(0.0, 1.0);
              if (k <= 0) continue;
              if (k >= 1) continue; // وصلت ⇒ لا تُرسم (اليد الحقيقية تظهر)
              final rel = i % 4;
              final seat = _kSeat[rel];
              final e = Curves.easeOutCubic.transform(k);
              final x = 0.0 + (seat.x * 0.92) * e;
              final y = -0.08 + (seat.y * 0.92 + 0.08) * e;
              cards.add(Align(
                alignment: Alignment(x.clamp(-1.3, 1.3), y.clamp(-1.3, 1.3)),
                child: Transform.rotate(
                  angle: (1 - e) * (rel.isEven ? 2.2 : -2.2),
                  child: Opacity(
                    opacity: (1 - k * 0.25).clamp(0.0, 1.0),
                    child: CardBack(
                      params: bp,
                      width: 26 - 6 * e,
                      height: 37 - 9 * e,
                    ),
                  ),
                ),
              ));
            }
            return IgnorePointer(child: Stack(children: cards));
          },
        ));
  }

  // ───── التأثيرات ─────
  void _addFx(Widget Function(VoidCallback done) make) {
    if (!mounted) return;
    final id = ++_fxSeq;
    void done() {
      if (mounted) setState(() => _fx.removeWhere((f) => f.id == id));
    }

    setState(() {
      _fx.add(_Fx(id, make(done)));
      while (_fx.length > 16) {
        _fx.removeAt(0);
      }
    });
  }

  void _doShake(double amp) {
    _shakeAmp = amp;
    _shake.forward(from: 0);
  }

  void _later(int ms, VoidCallback f) {
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    });
  }

  void _revealContract(String contract, int owner) {
    playServerSound('contract_reveal');
    final until = DateTime.now().add(const Duration(milliseconds: 1500));
    if (until.isAfter(_animUntil)) _animUntil = until;
    final color = _contractColor[contract] ?? const Color(0xFFFFC107);
    final icon = _contractIcon[contract] ?? '🃏';
    final rnd = math.Random(_fxSeq * 31 + contract.hashCode);
    final parts = List<_Particle>.generate(14, (i) => _Particle(rnd, i.isEven ? icon : '✨'));
    final ownerName = _who(owner);
    _addFx((done) => _Anim(
          duration: const Duration(milliseconds: 1900),
          onDone: done,
          builder: (ctx, t) {
            final inn = Curves.easeOutBack.transform((t / 0.24).clamp(0.0, 1.0));
            final out = Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0));
            final ang = (1 - inn) * (math.pi / 2) - out * (math.pi / 2);
            final dim = (110 * (1 - out) * math.min(1.0, t * 6)).round().clamp(0, 255);
            return IgnorePointer(
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: Colors.black.withAlpha(dim))),
                for (final p in parts) _particleAt(p, t),
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, -0.1),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(ang),
                      child: Container(
                        width: 236,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color, Color.lerp(color, Colors.black, 0.5)!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: color.withAlpha(170), blurRadius: 26, spreadRadius: 2)],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(icon, style: const TextStyle(fontSize: 44)),
                          Text(_contractName[contract] ?? contract,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(_contractHint[contract] ?? '',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                          const SizedBox(height: 6),
                          Text('اختاره: $ownerName',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ));
  }

  void _doubleFx(String card, int seat, {int delayMs = 0}) {
    final me = _ti(_v?['me']);
    final rel = (seat - me + 4) % 4;
    final who = _who(seat);
    _later(delayMs, () => playServerSound('trix_double'));
    final al = Alignment.lerp(_kSeat[rel], Alignment.center, 0.42)!;
    _addFx((done) => _Anim(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 1600),
          onDone: done,
          builder: (ctx, t) {
            final pop = Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
            final fade = t > 0.8 ? ((1 - t) / 0.2).clamp(0.0, 1.0) : 1.0;
            final wob = math.sin(t * math.pi * 5) * 0.35 * (1 - t);
            return IgnorePointer(
              child: Stack(children: [
                Positioned.fill(
                  child: Align(
                    alignment: al,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: 0.2 + 0.8 * pop,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🔥 دبل!',
                              style: TextStyle(
                                color: Color(0xFFFF6D00),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(color: Color(0xFFFFD180), blurRadius: 12)],
                              )),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(wob),
                            child: PlayingCard(card: card, width: 42, height: 60, glow: true, glowColor: const Color(0xFFFF6D00)),
                          ),
                          const SizedBox(height: 2),
                          Text(who,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ));
  }

  void _trickDone(Map<String, dynamic> v, Map<String, dynamic> lt, Set<String> shown, String? contract) {
    final me = _ti(v['me']);
    final cards = _tmaps(lt['cards']);
    if (cards.length < 4) return;
    final w = _ti(lt['winner']);
    final wr = (w - me + 4) % 4;
    final unseen = cards.any((e) => !shown.contains('${e['c']}'));
    if (unseen) playServerSound('card_throw');
    final until = DateTime.now().add(const Duration(milliseconds: 1250));
    if (until.isAfter(_animUntil)) _animUntil = until;
    _later(780, () => playServerSound('card_collect'));
    _addFx((done) => _Anim(
          duration: const Duration(milliseconds: 1250),
          onDone: done,
          builder: (ctx, t) {
            final ms = t * 1250;
            final k = Curves.easeInCubic.transform(((ms - 780) / 470).clamp(0.0, 1.0));
            final children = <Widget>[];
            for (final c in cards) {
              final s = _ti(c['s']);
              final rel = (s - me + 4) % 4;
              final card = '${c['c']}';
              final isWin = s == w;
              Alignment al;
              var ft = 1.0;
              if (!shown.contains(card) && ms < 300) {
                final f = Curves.easeOutCubic.transform(ms / 300);
                al = Alignment.lerp(_kEdge[rel], _kSlot[rel], f)!;
                ft = rel == 0 ? 1.0 : f;
              } else {
                al = Alignment.lerp(_kSlot[rel], _kEdge[wr], k)!;
              }
              final pulse = (isWin && ms > 300 && ms < 780) ? 1.0 + 0.1 * math.sin((ms - 300) / 480 * math.pi) : 1.0;
              children.add(Positioned.fill(
                child: Align(
                  alignment: al,
                  child: Opacity(
                    opacity: (1 - 0.8 * k).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: (1 - 0.5 * k) * pulse,
                      child: Transform.rotate(
                        angle: _kTilt[rel] * (1 - k) + k * (rel.isEven ? 1.4 : -1.4),
                        child: _flipCard(card, ft,
                            flip: ft < 1, glow: isWin && ms > 300, glowColor: const Color(0xFFFFC107)),
                      ),
                    ),
                  ),
                ),
              ));
            }
            return IgnorePointer(child: Stack(clipBehavior: Clip.none, children: children));
          },
        ));
    _specials(v, cards.map((e) => '${e['c']}').toList(), w, contract);
  }

  void _specials(Map<String, dynamic> v, List<String> cards, int w, String? contract) {
    final me = _ti(v['me']);
    final dbl = _tmap(v['doubles']);
    final rel = (w - me + 4) % 4;
    final who = _who(w);
    final all = contract == 'complex';
    var delay = 820;

    if ((contract == 'king' || all) && cards.contains('H13')) {
      final d = dbl['H13'];
      final ds = d == null ? null : _ti(d);
      final val = ds != null ? -150 : -75;
      var sub = '$val';
      if (ds != null && ds != w) sub += '   •   +75 لـ${_who(ds)}';
      _bigCard(['H13'], const Color(0xFFE53935), const ['👑', '💥', '♥️'],
          ds != null ? '$who أكل الشايب المدبول!' : '$who أكل الشايب!', sub, rel, delay, 'king_taken',
          shake: 10);
      delay += 1900;
    }

    final queens = cards.where((c) => _rankOf(c) == 12).toList();
    if ((contract == 'queens' || all) && queens.isNotEmpty) {
      var total = 0;
      final bonus = <String>[];
      for (final q in queens) {
        final d = dbl[q];
        if (d != null) {
          total -= 50;
          if (_ti(d) != w) bonus.add('+25 لـ${_who(_ti(d))}');
        } else {
          total -= 25;
        }
      }
      _bigCard(queens, const Color(0xFFD81B60), const ['👸', '💖', '✨'],
          queens.length > 1 ? '$who أكل ${queens.length} بنات!' : '$who أكل البنت!',
          '$total${bonus.isEmpty ? '' : '   •   ${bonus.join('  ')}'}', rel, delay, 'queen_taken',
          shake: 4);
      delay += 1900;
    }

    final dia = cards.where((c) => _suitOf(c) == 'D').length;
    if ((contract == 'diamonds' || all) && dia > 0) {
      _diamondRain(dia, '$who أكل $dia ديناري', '${-10 * dia}', delay);
      delay += 1500;
    }

    if (contract == 'slaps') {
      _slap(rel, '$who: لطشة −15', 700);
    } else if (all) {
      _floatText(rel, 'لطشة −15', const Color(0xFFFF9800), 900);
    }
  }

  void _bigCard(List<String> cards, Color color, List<String> emojis, String title, String sub, int rel,
      int delayMs, String sound,
      {double shake = 0}) {
    _later(delayMs, () {
      playServerSound(sound);
      if (shake > 0) _doShake(shake);
    });
    final rnd = math.Random(_fxSeq * 7919 + delayMs);
    final parts = List<_Particle>.generate(20, (i) => _Particle(rnd, emojis[i % emojis.length]));
    final target = _kEdge[rel];
    _addFx((done) => _Anim(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 2150),
          onDone: done,
          builder: (ctx, t) {
            final pop = Curves.easeOutBack.transform((t / 0.18).clamp(0.0, 1.0));
            final spin = Curves.easeOutCubic.transform((t / 0.62).clamp(0.0, 1.0)) * math.pi * 4;
            final out = Curves.easeInCubic.transform(((t - 0.8) / 0.2).clamp(0.0, 1.0));
            final flash = t < 0.25 ? (1 - t / 0.25) : 0.0;
            final al = Alignment.lerp(const Alignment(0, -0.12), target, out)!;
            final scale = (0.25 + 1.15 * pop) * (1 - 0.7 * out);
            final glow = 0.5 + 0.5 * math.sin(t * math.pi * 6);
            final facing = math.cos(spin) >= 0;
            final row = Row(mainAxisSize: MainAxisSize.min, children: [
              for (final c in cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: facing
                      ? PlayingCard(card: c, width: 58, height: 84, glow: true, glowColor: color)
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: CardBack(params: TrixPrefs.backParams, width: 58, height: 84),
                        ),
                ),
            ]);
            return IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [
                if (flash > 0)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          color.withAlpha((170 * flash).round().clamp(0, 255)),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                for (final p in parts) _particleAt(p, t),
                Positioned.fill(
                  child: Align(
                    alignment: al,
                    child: Opacity(
                      opacity: (1 - out).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(spin),
                          child: row,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, 0.5),
                    child: Opacity(
                      opacity: (((t - 0.12) / 0.1).clamp(0.0, 1.0) * (1 - out)).clamp(0.0, 1.0),
                      child: _fxLabel(title, sub, color, glow),
                    ),
                  ),
                ),
              ]),
            );
          },
        ));
  }

  void _diamondRain(int n, String title, String sub, int delayMs) {
    _later(delayMs, () => playServerSound('diamond_taken'));
    final rnd = math.Random(_fxSeq * 104729 + n);
    final drops = List<List<double>>.generate(math.min(28, 6 + n * 3), (i) => [
          rnd.nextDouble() * 2 - 1,
          rnd.nextDouble() * 0.35,
          14 + rnd.nextDouble() * 14,
          (rnd.nextDouble() - 0.5) * 6,
        ]);
    _addFx((done) => _Anim(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 1650),
          onDone: done,
          builder: (ctx, t) {
            final fade = t > 0.82 ? ((1 - t) / 0.18).clamp(0.0, 1.0) : 1.0;
            return IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [
                for (final d in drops)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(d[0], -1.2 + 2.6 * ((t - d[1]) / (1 - d[1])).clamp(0.0, 1.0)),
                      child: Opacity(
                        opacity: fade,
                        child: Transform.rotate(angle: d[3] * t, child: Text('💎', style: TextStyle(fontSize: d[2]))),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, 0.08),
                    child: Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0)),
                        child: _fxLabel('💎 $title', sub, const Color(0xFF29B6F6), 0.6),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ));
  }

  void _slap(int rel, String text, int delayMs) {
    _later(delayMs, () {
      playServerSound('slap');
      _doShake(6);
    });
    final al = Alignment.lerp(Alignment.center, _kSeat[rel], 0.55)!;
    _addFx((done) => _Anim(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 1250),
          onDone: done,
          builder: (ctx, t) {
            final hit = Curves.easeOutBack.transform((t / 0.24).clamp(0.0, 1.0));
            final fade = t > 0.75 ? ((1 - t) / 0.25).clamp(0.0, 1.0) : 1.0;
            final ring = ((t - 0.18) / 0.5).clamp(0.0, 1.0);
            return IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [
                if (ring > 0 && ring < 1)
                  Positioned.fill(
                    child: Align(
                      alignment: al,
                      child: Opacity(
                        opacity: 1 - ring,
                        child: Container(
                          width: 40 + 170 * ring,
                          height: 40 + 170 * ring,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF9800), width: 0.5 + 5 * (1 - ring)),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Align(
                    alignment: al,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.rotate(
                        angle: -0.7 * (1 - hit),
                        child: Transform.scale(
                          scale: 3.2 - 2.2 * hit,
                          child: const Text('✋', style: TextStyle(fontSize: 52)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (t > 0.15)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(al.x, al.y - 0.25 - 0.15 * t),
                      child: Opacity(opacity: fade, child: _fxLabel(text, '', const Color(0xFFFF9800), 0.5)),
                    ),
                  ),
              ]),
            );
          },
        ));
  }

  void _floatText(int rel, String text, Color color, int delayMs) {
    final from = Alignment.lerp(Alignment.center, _kSeat[rel], 0.6)!;
    _addFx((done) => _Anim(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 1300),
          onDone: done,
          builder: (ctx, t) => IgnorePointer(
            child: Stack(children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment(from.x, from.y - 0.3 * t),
                  child: Opacity(
                    opacity: (t < 0.15 ? t / 0.15 : (1 - t) / 0.85).clamp(0.0, 1.0),
                    child: Text(text,
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                        )),
                  ),
                ),
              ),
            ]),
          ),
        ));
  }

  void _medalFx(int seat, int place) {
    final me = _ti(_v?['me']);
    final rel = (seat - me + 4) % 4;
    const medals = ['🥇', '🥈', '🥉', '🏅'];
    const pts = [200, 150, 100, 50];
    playServerSound('trix_finish');
    final al = Alignment.lerp(Alignment.center, _kSeat[rel], 0.6)!;
    _addFx((done) => _Anim(
          duration: const Duration(milliseconds: 1700),
          onDone: done,
          builder: (ctx, t) {
            final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
            final fade = t > 0.8 ? ((1 - t) / 0.2).clamp(0.0, 1.0) : 1.0;
            return IgnorePointer(
              child: Stack(children: [
                Positioned.fill(
                  child: Align(
                    alignment: al,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: 0.2 + 0.8 * pop,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(t * math.pi * 4),
                            child: Text(medals[place.clamp(0, 3)], style: const TextStyle(fontSize: 44)),
                          ),
                          _fxLabel('${_who(seat)} أنهى أوراقه', '+${pts[place.clamp(0, 3)]}', const Color(0xFF43A047), 0.6),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ));
  }

  // ───── أفعال اللاعب ─────
  Future<void> _play(String c) async {
    if (_acting) return;
    _acting = true;
    playServerSound('card_throw');
    setState(() => _pending = c);
    try {
      await _tdb.rpc('trix_play', params: {'p_game': widget.gameId, 'p_card': c});
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _pending = null);
      _say(trixErrorText(e));
      unawaited(_refresh());
    } finally {
      _acting = false;
    }
  }

  Future<void> _choose(String c) async {
    if (_acting) return;
    _acting = true;
    try {
      await _tdb.rpc('trix_choose_contract', params: {'p_game': widget.gameId, 'p_contract': c});
      await _refresh();
    } catch (e) {
      _say(trixErrorText(e));
    } finally {
      _acting = false;
    }
  }

  Future<void> _sendDouble(List<String> cards) async {
    if (_acting) return;
    _acting = true;
    try {
      await _tdb.rpc('trix_double', params: {'p_game': widget.gameId, 'p_cards': cards});
      _dblSel.clear();
      await _refresh();
    } catch (e) {
      _say(trixErrorText(e));
      unawaited(_refresh());
    } finally {
      _acting = false;
    }
  }

  Future<void> _resign() async {
    setState(() => _askResign = false);
    try {
      await _tdb.rpc('trix_resign', params: {'p_game': widget.gameId});
      await _refresh();
    } catch (e) {
      _say(trixErrorText(e));
    }
  }

  void _newGame() {
    TrixWindow.instance.close();
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null) unawaited(showTrixLauncher(ctx));
  }

  void _tapCard(String c, bool ok, bool canPlay) {
    if (!canPlay) {
      _say('ليس دورك الآن.');
      return;
    }
    if (!ok) {
      _say('هذه الورقة غير مسموحة الآن.');
      return;
    }
    _play(c);
  }

  // ───── البناء ─────
  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0xFF0E0A18),
        child: v == null
            ? _loading()
            : Stack(children: [
                Positioned.fill(child: _body(v)),
                if (_askResign) _resignPanel(v),
                if (_showDesign) _designPanel(),
                if (_showResult && v['status'] == 'finished') _resultPanel(v),
                if (_toast != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 128,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: const Color(0xEE2A2238), borderRadius: BorderRadius.circular(12)),
                        child: Text(_toast!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }

  Widget _loading() {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _felt(null),
          ),
        ),
        const Positioned.fill(
          child: ColoredBox(color: Color(0xA60E0A18)),
        ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xE8171126),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x77FFD166)),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error == null)
                  const CircularProgressIndicator(color: Color(0xFFFFD166))
                else
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                if (_error != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _error = null);
                      unawaited(_refresh());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                TextButton(
                  onPressed: TrixWindow.instance.close,
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap, {Color color = Colors.white60}) {
    return IconButton(
      onPressed: onTap,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      iconSize: 20,
      icon: Icon(icon, color: color),
    );
  }

  Widget _body(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final phase = '${v['phase']}';
    final turn = _ti(v['turn'], -1);
    final active = v['status'] == 'active';
    final myDbl = _tstrs(v['my_doublable']);
    return Column(children: [
      _header(v),
      _scoreRow(v),
      Expanded(child: _tableArea(v)),
      _statusBar(v),
      // سقف ارتفاع مع تمرير: على الشاشات القصيرة (أو الوضع الأفقي) كان
      // اختيار العقد يأكل كل المساحة فيتقلّص Expanded الخاص بالطاولة.
      if (active && phase == 'choose' && turn == me)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 186),
          child: SingleChildScrollView(child: _contractPicker(v)),
        ),
      if (active && myDbl.isNotEmpty) _doublePanel(v, myDbl),
      SizedBox(height: 112, child: _handFan(v)),
      const SizedBox(height: 4),
    ]);
  }

  Widget _header(Map<String, dynamic> v) {
    final contract = v['contract']?.toString();
    final phase = '${v['phase']}';
    final kingdom = _ti(v['kingdom']);
    final handNo = _ti(v['hand_no']);
    final nContracts = math.max(1, _tstrs(v['contracts']).length);
    final owner = _ti(v['owner']);
    final stake = _ti(v['stake']);
    final partner = v['mode'] == 'partner';
    final active = v['status'] == 'active';
    final mode = widget.mode;
    final info = '${partner ? 'شراكة 2×2' : 'فردي'} • ${v['variant'] == 'complex' ? 'كومبلكس' : 'كلاسيك'}'
        ' • مملكة ${math.min(kingdom + 1, 4)}/4 (${_who(owner)})'
        ' • لعبة ${math.min(handNo + 1, nContracts)}/$nContracts${stake > 0 ? ' • رهان $stake' : ''}';
    final cColor = _contractColor[contract] ?? Colors.white24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Row(children: [
        if (active) _iconBtn(Icons.flag_rounded, 'انسحاب', () => setState(() => _askResign = true)),
        _iconBtn(Icons.palette_rounded, 'تصميم الورق', () => setState(() => _showDesign = true)),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
            if (contract != null && phase != 'choose')
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: cColor.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cColor.withAlpha(200)),
                ),
                child: Text('${_contractIcon[contract] ?? ''} ${_contractName[contract] ?? contract}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
          ]),
        ),
        if (mode == TrixWindowMode.full)
          _iconBtn(Icons.picture_in_picture_alt_rounded, 'نافذة عائمة',
              () => TrixWindow.instance.setMode(TrixWindowMode.float))
        else
          _iconBtn(Icons.fullscreen_rounded, 'ملء الشاشة', () => TrixWindow.instance.setMode(TrixWindowMode.full)),
        _iconBtn(Icons.remove_rounded, 'تصغير', () => TrixWindow.instance.setMode(TrixWindowMode.mini)),
        _iconBtn(Icons.close_rounded, 'إغلاق', TrixWindow.instance.close),
      ]),
    );
  }

  Widget _scoreRow(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final sc = _tints(v['scores'], 4);
    final turn = _ti(v['turn'], -1);
    final partner = v['mode'] == 'partner';
    final order = [me, (me + 1) % 4, (me + 2) % 4, (me + 3) % 4];
    Widget chip(int s) {
      final team = partner ? (s % 2 == me % 2 ? const Color(0xFF42A5F5) : const Color(0xFFEF5350)) : null;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: turn == s ? const Color(0x44FFC107) : const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: s == me ? const Color(0xFFFFD54F) : (team ?? Colors.transparent).withAlpha(160)),
          ),
          child: Column(children: [
            Text(_who(s),
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [for (final s in order) chip(s)]),
        if (partner)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'فريقك ${sc[me] + sc[(me + 2) % 4]}   ⟷   الخصم ${sc[(me + 1) % 4] + sc[(me + 3) % 4]}',
              style: const TextStyle(color: Color(0xFFFFE082), fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
      ]),
    );
  }

  Widget _tableArea(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final phase = '${v['phase']}';
    final contract = v['contract']?.toString();
    final trixMode = contract == 'trix' && phase != 'choose';
    final children = <Widget>[
      // الطاولة تُرسم عبر AnimatedBuilder على _tableGlow كي تتحرّك بسلاسة
      // 60 إطارًا/ث. قبل ذلك كانت تقرأ _tableGlow.value دون الاشتراك فيه،
      // فلا تُعاد رسمتها إلا مع setState كل 500ms (حركة متقطّعة ~2 إطار/ث).
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _tableGlow,
          builder: (_, __) => _felt(contract),
        ),
      ),
      for (final rel in const [1, 2, 3]) _seat(v, (me + rel) % 4, rel),
      _mySeatLabel(v),
      if (trixMode) _trixLayout(v) else ..._trickWidgets(v),
      if (phase == 'handover') _handover(v),
      _doublesChips(v),
      _reactBar(v),
      for (final f in _fx) Positioned.fill(key: ValueKey<String>('fx${f.id}'), child: f.child),
    ];
    return AnimatedBuilder(
      animation: _shake,
      builder: (ctx, child) {
        final t = _shake.value;
        final dx = _shake.isAnimating ? math.sin(t * math.pi * 9) * _shakeAmp * (1 - t) : 0.0;
        return Transform.translate(offset: Offset(dx, dx * 0.35), child: child);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        // StackFit.expand مقصود وإلزامي: كل أبناء هذه الـStack موضَّعون
        // (Positioned/Positioned.fill). قاعدة RenderStack أنّ وجود طفل واحد
        // غير موضَّع — ولو بحجم صفري — يجعل الـStack تأخذ حجم ذلك الطفل بدل
        // حجم القيود. وبما أنّ Expanded يمرّر عرضًا مرنًا (0..max)، كان طفل
        // SizedBox.shrink() القادم من _doublesChips يُصفّر عرض الـStack
        // فيصبح عرض الطاولة صفرًا وتختفي لحظة بدء المباراة. expand يثبّت
        // الحجم على القيود فلا يعود أي طفل قادرًا على تصفيره.
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: children,
        ),
      ),
    );
  }

  Widget _felt(String? contract) {
    final c = _contractColor[contract] ?? const Color(0xFFFFD166);
    final pulse = 0.5 + 0.5 * math.sin(_tableGlow.value * math.pi * 2);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..rotateX(0.16)
        ..rotateZ(math.sin(_tableGlow.value * math.pi * 2) * 0.002),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB17A42),
              Color(0xFF4E2818),
              Color(0xFF29150F),
              Color(0xFF8D5A31),
            ],
            stops: [0.0, 0.34, 0.68, 1.0],
          ),
          border: Border.all(color: Color(0xFFE9C879), width: 2.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(150),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 13),
            ),
            BoxShadow(
              color: c.withAlpha((30 + 55 * pulse).round().clamp(0, 255).toInt()),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(
              center: Alignment(-0.15, -0.22),
              radius: 1.15,
              colors: [
                Color(0xFF368B5C),
                Color(0xFF165638),
                Color(0xFF082A1E),
              ],
              stops: [0.0, 0.66, 1.0],
            ),
            border: Border.all(color: const Color(0xFFE3C27A), width: 1.3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrixTableSurfacePainter(
                      animation: _tableGlow,
                      accent: c,
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 14,
                  child: Text('♠', style: TextStyle(color: Color(0x22FFFFFF), fontSize: 27, fontWeight: FontWeight.w900)),
                ),
                const Positioned(
                  right: 20,
                  top: 14,
                  child: Text('♥', style: TextStyle(color: Color(0x22FFD166), fontSize: 27, fontWeight: FontWeight.w900)),
                ),
                const Positioned(
                  left: 20,
                  bottom: 14,
                  child: Text('♣', style: TextStyle(color: Color(0x22FFFFFF), fontSize: 27, fontWeight: FontWeight.w900)),
                ),
                const Positioned(
                  right: 20,
                  bottom: 14,
                  child: Text('♦', style: TextStyle(color: Color(0x22FFD166), fontSize: 27, fontWeight: FontWeight.w900)),
                ),
                Center(
                  child: Opacity(
                    opacity: 0.12 + 0.06 * pulse,
                    child: Text(
                      'TRIX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        shadows: [
                          Shadow(color: c.withAlpha(170), blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backsFan(int n) {
    final shown = math.min(n, 7);
    if (shown <= 0) return const SizedBox(height: 30);
    final bp = TrixPrefs.backParams;
    return SizedBox(
      width: 21.0 + (shown - 1) * 5.0,
      height: 30,
      child: Stack(children: [
        for (var i = 0; i < shown; i++)
          Positioned(left: i * 5.0, top: 0, child: CardBack(params: bp, width: 21, height: 30)),
      ]),
    );
  }

  double? _afkFrac(Map<String, dynamic> v) {
    final upd = _ts(v['updated_at']);
    if (upd == null) return null;
    final since = _serverNow.difference(upd).inMilliseconds;
    return (1 - since / 30000).clamp(0.0, 1.0);
  }

  Widget _seat(Map<String, dynamic> v, int seat, int rel) {
    final me = _ti(v['me']);
    final turn = _ti(v['turn'], -1);
    final phase = '${v['phase']}';
    final active = v['status'] == 'active';
    final seats = (v['seats'] as List?) ?? const [];
    final bot = seat < seats.length && seats[seat] == null;
    final sizes = _tints(v['hand_sizes'], 4, 13);
    final counts = _tints(v['counts'], 4);
    final partner = v['mode'] == 'partner';
    final isTurn = active &&
        turn == seat &&
        (phase == 'play' || phase == 'choose') &&
        _tstrs(v['double_pending']).isEmpty;
    final team = partner ? (seat % 2 == me % 2 ? const Color(0xFF42A5F5) : const Color(0xFFEF5350)) : Colors.white38;
    final name = _name(seat);
    final finished = v['contract'] == 'trix' && _tstrs(v['finish_order']).contains('$seat') && sizes[seat] == 0;
    final place = _tstrs(v['finish_order']).indexOf('$seat');
    final frac = isTurn && !bot ? _afkFrac(v) : null;

    final avatar = Stack(alignment: Alignment.center, children: [
      if (frac != null)
        SizedBox(
          width: 46,
          height: 46,
          child: CircularProgressIndicator(
            value: frac,
            strokeWidth: 3,
            color: frac < 0.3 ? const Color(0xFFFF5252) : const Color(0xFFFFC107),
            backgroundColor: Colors.white12,
          ),
        ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF4A3B6B), Color(0xFF241A38)]),
          border: Border.all(color: isTurn ? const Color(0xFFFFC107) : team, width: isTurn ? 3 : 2),
          boxShadow: isTurn ? const [BoxShadow(color: Color(0x99FFC107), blurRadius: 12)] : null,
        ),
        alignment: Alignment.center,
        child: Text(bot ? '🤖' : (name.isEmpty ? '?' : name.characters.first),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      if (finished && place >= 0)
        Positioned(right: 0, top: 0, child: Text(const ['🥇', '🥈', '🥉', '🏅'][place.clamp(0, 3)], style: const TextStyle(fontSize: 14))),
    ]);

    final label = Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 48, height: 48, child: avatar),
      SizedBox(
        width: 84,
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isTurn ? const Color(0xFFFFE082) : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      ),
      Text('${counts[seat]} أكلة • ${sizes[seat]} ورقة', style: const TextStyle(color: Colors.white54, fontSize: 9)),
      if (partner && seat == (me + 2) % 4)
        const Text('شريكك', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 9, fontWeight: FontWeight.w800)),
    ]);

    final content = rel == 2
        ? Row(mainAxisSize: MainAxisSize.min, children: [label, const SizedBox(width: 4), _backsFan(sizes[seat])])
        : Column(mainAxisSize: MainAxisSize.min, children: [label, const SizedBox(height: 2), _backsFan(sizes[seat])]);
    return Positioned.fill(child: Align(alignment: _kSeat[rel], child: content));
  }

  Widget _mySeatLabel(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final counts = _tints(v['counts'], 4);
    final turn = _ti(v['turn'], -1);
    final isTurn = v['status'] == 'active' && turn == me && _tstrs(v['double_pending']).isEmpty;
    final frac = isTurn && '${v['phase']}' != 'handover' ? _afkFrac(v) : null;
    return Positioned.fill(
      child: Align(
        alignment: const Alignment(0, 0.97),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isTurn ? const Color(0x55FFC107) : const Color(0x33000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('أنت • ${counts[me]} أكلة',
                style: TextStyle(color: isTurn ? const Color(0xFFFFE082) : Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800)),
            if (frac != null) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 3,
                  color: frac < 0.3 ? const Color(0xFFFF5252) : const Color(0xFFFFC107),
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _trickWidgets(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final trick = _tmaps(v['trick']);
    final list = <Map<String, dynamic>>[...trick];
    final p = _pending;
    if (p != null && !trick.any((e) => '${e['c']}' == p)) list.add({'s': me, 'c': p});
    return [
      for (final c in list)
        Positioned.fill(
          key: ValueKey<String>('tc${c['c']}'),
          child: _Anim(
            duration: const Duration(milliseconds: 320),
            builder: (ctx, t) {
              final s = _ti(c['s']);
              final rel = (s - me + 4) % 4;
              final f = Curves.easeOutCubic.transform(t);
              return IgnorePointer(
                child: Align(
                  alignment: Alignment.lerp(_kEdge[rel], _kSlot[rel], f)!,
                  child: Transform.rotate(
                    angle: _kTilt[rel] * f,
                    child: Transform.scale(
                      scale: rel == 0 ? 1.15 - 0.15 * f : 0.8 + 0.2 * f,
                      child: _flipCard('${c['c']}', rel == 0 ? 1 : f, flip: rel != 0),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }

  Widget _layCard(String card) {
    return _Anim(
      key: ValueKey<String>('L$card'),
      duration: const Duration(milliseconds: 460),
      builder: (ctx, t) {
        final f = Curves.easeOutBack.transform(t);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY((1 - t) * math.pi / 2),
          child: Transform.scale(
            scale: 1.4 - 0.4 * f.clamp(0.0, 1.2),
            child: PlayingCard(card: card, width: 36, height: 52, glow: t < 1, glowColor: const Color(0xFF66BB6A)),
          ),
        );
      },
    );
  }

  Widget _trixLayout(Map<String, dynamic> v) {
    final layout = _tmap(v['layout']);
    Widget column(String s) {
      final l = layout[s];
      if (l is! Map) {
        return Container(
          width: 40,
          height: 54,
          margin: const EdgeInsets.only(top: 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
            color: const Color(0x14FFFFFF),
          ),
          alignment: Alignment.center,
          child: Text('J${_suitSym[s]}', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w800)),
        );
      }
      final lo = _ti(l['lo']);
      final hi = _ti(l['hi']);
      final mid = (lo <= 11 && hi >= 11) ? 11 : lo;
      return SizedBox(
        width: 40,
        height: 128,
        child: Stack(clipBehavior: Clip.none, children: [
          if (hi > mid) Positioned(top: 0, left: 2, child: _layCard('$s$hi')),
          Positioned(top: 30, left: 2, child: _layCard('$s$mid')),
          if (lo < mid) Positioned(top: 60, left: 2, child: _layCard('$s$lo')),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Text('${hi - lo + 1}/13',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ),
        ]),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, 0.05),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final s in const ['S', 'H', 'D', 'C'])
                Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: column(s)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _handover(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final d = _tints(v['hand_delta'], 4);
    final contract = v['contract']?.toString();
    final partner = v['mode'] == 'partner';
    final color = _contractColor[contract] ?? const Color(0xFFFFC107);
    return Positioned.fill(
      child: Center(
        child: _Anim(
          key: ValueKey<String>('ho${v['kingdom']}-${v['hand_no']}'),
          duration: const Duration(milliseconds: 520),
          builder: (ctx, t) => Transform.scale(
            scale: Curves.easeOutBack.transform(t),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xF0171126),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
                boxShadow: [BoxShadow(color: color.withAlpha(110), blurRadius: 18)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${_contractIcon[contract] ?? ''} نتيجة ${_contractName[contract] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                for (final s in [me, (me + 1) % 4, (me + 2) % 4, (me + 3) % 4])
                  Text('${_who(s)}: ${d[s] > 0 ? '+' : ''}${d[s]}',
                      style: TextStyle(
                          color: d[s] < 0 ? const Color(0xFFFF8A80) : (d[s] > 0 ? const Color(0xFFA5D6A7) : Colors.white60),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                if (partner) ...[
                  const SizedBox(height: 4),
                  Text('فريقك ${d[me] + d[(me + 2) % 4]} • الخصم ${d[(me + 1) % 4] + d[(me + 3) % 4]}',
                      style: const TextStyle(color: Color(0xFFFFE082), fontSize: 11.5, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// شريط السمايلات: زر صغير على حافة الطاولة يتوسّع إلى صف سمايلات.
  /// موضَّع داخل Stack الطاولة عن قصد (لا داخل الـColumn) كي لا يأكل من
  /// ارتفاع الطاولة — وهو الخطأ الذي أخفاها أصلًا.
  Widget _reactBar(Map<String, dynamic> v) {
    if (v['status'] != 'active') {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    return Positioned(
      left: 6,
      bottom: 4,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _reactOpen
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC140E22),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x66FFD166)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final rx in kReactions)
                    GestureDetector(
                      onTap: () {
                        unawaited(_sendReact(rx));
                        setState(() => _reactOpen = false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(rx.e, style: const TextStyle(fontSize: 21)),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => _reactOpen = false),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close_rounded, color: Colors.white38, size: 17),
                    ),
                  ),
                ]),
              )
            : GestureDetector(
                onTap: () => setState(() => _reactOpen = true),
                // ينبض برفق: الدائرة الصغيرة الصامتة في زاوية الطاولة كانت
                // تمرّ دون أن تُرى، فلا يعرف اللاعب أنّ للسمايلات وجودًا.
                child: AnimatedBuilder(
                  animation: _tableGlow,
                  builder: (_, child) {
                    final t = _tableGlow.value;
                    final pulse = 1 + 0.07 * math.sin(t * math.pi * 2);
                    return Transform.scale(scale: pulse, child: child);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xDD1B1230),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xAAFFD166), width: 1.6),
                      boxShadow: const [
                        BoxShadow(color: Color(0x55FFD166), blurRadius: 10, spreadRadius: 1),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('😀', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _doublesChips(Map<String, dynamic> v) {
    final phase = '${v['phase']}';
    final dbl = _tmap(v['doubles']);
    // لا تُعِد أبدًا طفلًا غير موضَّع إلى Stack الطاولة (انظر _tableArea):
    // SizedBox.shrink() المجرّد كان يُصفّر عرض الطاولة. البديل موضَّع وصفري.
    if (dbl.isEmpty || (phase != 'play' && phase != 'handover')) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    return Positioned(
      top: 4,
      right: 10,
      child: IgnorePointer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final e in dbl.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xCCBF360C),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFFFAB40)),
              ),
              child: Text(
                '🔥 ${_rankLabel(_rankOf(e.key))}${_suitSym[_suitOf(e.key)] ?? ''} • ${_who(_ti(e.value))}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
        ]),
      ),
    );
  }

  String _statusText(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final phase = '${v['phase']}';
    final turn = _ti(v['turn'], -1);
    if (v['status'] == 'finished') return 'انتهت المباراة';
    final pend = _tstrs(v['double_pending']);
    if (phase == 'play' && pend.isNotEmpty) {
      final dl = _ts(v['phase_deadline']);
      final secs = dl == null ? 0 : math.max(0, (dl.difference(_serverNow).inMilliseconds / 1000).ceil());
      return pend.contains('$me') ? '🔥 قرّر الدبل خلال $secs ث' : '⏳ بانتظار قرار الدبل… $secs ث';
    }
    if (phase == 'choose') return turn == me ? '👑 مملكتك — اختر العقد' : '${_name(turn)} يختار العقد…';
    if (phase == 'handover') return 'انتهت اللعبة — التالية بعد لحظات…';
    return turn == me ? 'دورك — اضغط الورقة لرميها' : 'دور ${_name(turn)}';
  }

  Widget _statusBar(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final mine = v['status'] == 'active' && _ti(v['turn'], -1) == me && _tstrs(v['double_pending']).isEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: mine ? const Color(0x33FFC107) : Colors.transparent,
      child: Text(_statusText(v),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: mine ? const Color(0xFFFFD54F) : Colors.white60, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  Widget _contractPicker(Map<String, dynamic> v) {
    final rem = _tstrs(v['remaining']);
    final all = _tstrs(v['contracts']);
    final list = all.isEmpty ? rem : all.where(rem.contains).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (final c in list)
          GestureDetector(
            onTap: _acting ? null : () => _choose(c),
            child: Container(
              width: 112,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _contractColor[c] ?? Colors.grey,
                  Color.lerp(_contractColor[c] ?? Colors.grey, Colors.black, 0.5)!,
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38),
                boxShadow: [BoxShadow(color: (_contractColor[c] ?? Colors.grey).withAlpha(90), blurRadius: 8)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_contractIcon[c] ?? '🃏', style: const TextStyle(fontSize: 20)),
                Text(_contractName[c] ?? c,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                Text(_contractHint[c] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _doublePanel(Map<String, dynamic> v, List<String> cards) {
    final dl = _ts(v['phase_deadline']);
    final secs = dl == null ? 0 : math.max(0, (dl.difference(_serverNow).inMilliseconds / 1000).ceil());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4E1A0A), Color(0xFF2A0F06)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6D00), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66FF6D00), blurRadius: 12)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🔥 هل تدبل؟  ($secs ث)',
            style: const TextStyle(color: Color(0xFFFFAB40), fontWeight: FontWeight.w900, fontSize: 14)),
        const Text('آكل الورقة المدبولة يخسر الضعف، وأنت تكسب قيمتها.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 10.5)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final c in cards)
            GestureDetector(
              onTap: () => setState(() => _dblSel.contains(c) ? _dblSel.remove(c) : _dblSel.add(c)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                transform: Matrix4.translationValues(0.0, _dblSel.contains(c) ? -8.0 : 0.0, 0.0),
                child: PlayingCard(
                    card: c, width: 44, height: 62, glow: _dblSel.contains(c), glowColor: const Color(0xFFFF6D00)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _acting ? null : () => _sendDouble(const []),
              child: const Text('بدون دبل'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
              onPressed: _acting || _dblSel.isEmpty ? null : () => _sendDouble(_dblSel.toList()),
              child: Text('دبل! (${_dblSel.length})'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _handFan(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final hand = _tstrs(v['hand']).where((c) => c != _pending).toList();
    final legal = _tstrs(v['legal']).toSet();
    final canPlay = v['status'] == 'active' &&
        v['phase'] == 'play' &&
        _ti(v['turn'], -1) == me &&
        _tstrs(v['double_pending']).isEmpty &&
        !_acting &&
        _pending == null;
    return LayoutBuilder(builder: (ctx, box) {
      const cw = 54.0, ch = 78.0;
      final n = hand.length;
      if (n == 0) return const SizedBox.shrink();
      final avail = box.maxWidth - cw - 12;
      final step = n <= 1 ? 0.0 : math.min(cw * 0.78, avail / (n - 1));
      final total = step * (n - 1) + cw;
      final start = (box.maxWidth - total) / 2;
      final mid = (n - 1) / 2;
      final cards = <Widget>[];
      for (var i = 0; i < n; i++) {
        final c = hand[i];
        final ok = canPlay && legal.contains(c);
        final off = i - mid;
        cards.add(AnimatedPositioned(
          key: ValueKey<String>('h$c'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: start + step * i,
          top: 14 + off * off * 0.45 - (ok ? 12 : 0),
          child: Transform.rotate(
            angle: off * 0.035,
            child: GestureDetector(
              onTap: () => _tapCard(c, ok, canPlay),
              child: PlayingCard(
                card: c,
                width: cw,
                height: ch,
                dim: canPlay && !ok,
                glow: ok,
                glowColor: const Color(0xFFFFC107),
              ),
            ),
          ),
        ));
      }
      return Stack(clipBehavior: Clip.none, children: cards);
    });
  }

  // ───── لوحات داخل النافذة (النافذة فوق الـNavigator فلا showDialog) ─────
  Widget _scrim({required Widget child, VoidCallback? onTapOut}) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTapOut,
        child: ColoredBox(
          color: const Color(0xB3000000),
          child: Center(child: GestureDetector(onTap: () {}, child: child)),
        ),
      ),
    );
  }

  Widget _resignPanel(Map<String, dynamic> v) {
    final stake = _ti(v['stake']);
    return _scrim(
      onTapOut: () => setState(() => _askResign = false),
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF221A33), borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏳️ الانسحاب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          Text(
            stake > 0 ? 'الانسحاب يعني خسارة الرهان ($stake نقطة) وبلا جائزة. متأكد؟' : 'هل تريد إنهاء المباراة؟ (بلا جائزة)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton(onPressed: () => setState(() => _askResign = false), child: const Text('تراجع'))),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _resign,
                child: const Text('انسحاب'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _designPanel() {
    return _scrim(
      onTapOut: () => setState(() => _showDesign = false),
      child: Container(
        width: 360,
        height: 470,
        decoration: BoxDecoration(color: const Color(0xFF171126), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 14),
            const Expanded(
              child: Text('🎨 تصميم الورق',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            IconButton(
              onPressed: () => setState(() => _showDesign = false),
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
            ),
          ]),
          const Expanded(child: TrixDesignPicker()),
        ]),
      ),
    );
  }

  Widget _resultPanel(Map<String, dynamic> v) {
    final me = _ti(v['me']);
    final sc = _tints(v['scores'], 4);
    final res = _tmap(v['result']);
    final nets = _tints(res['nets'], 4);
    final net = nets[me];
    final stake = _ti(v['stake']);
    final partner = v['mode'] == 'partner';
    final prizes = res['prizes'] is List ? res['prizes'] as List : const [];
    final mp = me < prizes.length && prizes[me] is Map ? _tmap(prizes[me]) : null;
    final pts = mp == null ? 0 : _ti(mp['points']);
    final gems = mp == null ? 0 : _ti(mp['gems']);
    final outcome = _outcome(v);
    final resigned = res['resigned'] != null;
    final order = List<int>.generate(4, (i) => i)..sort((a, b) => sc[b].compareTo(sc[a]));
    final title = outcome > 0 ? '🏆 فزت!' : (outcome == 0 ? '🤝 تعادل' : 'حظًا أوفر');
    final color = outcome > 0 ? const Color(0xFFFFD54F) : (outcome == 0 ? Colors.white : const Color(0xFFFF8A80));
    final rnd = math.Random(7);
    final confetti = List<_Particle>.generate(24, (i) => _Particle(rnd, const ['🎉', '✨', '🏆', '💎'][i % 4]));

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC000000),
        child: Stack(children: [
          if (outcome > 0)
            Positioned.fill(
              child: _Anim(
                key: const ValueKey<String>('confetti'),
                duration: const Duration(milliseconds: 2600),
                builder: (ctx, t) => IgnorePointer(
                  child: Stack(children: [for (final p in confetti) _particleAt(p, t, origin: const Alignment(0, -0.4))]),
                ),
              ),
            ),
          Center(
            child: _Anim(
              key: const ValueKey<String>('result'),
              duration: const Duration(milliseconds: 700),
              builder: (ctx, t) => Transform.scale(
                scale: Curves.easeOutBack.transform(t),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1430),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 24)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
                    if (resigned)
                      const Text('انتهت بانسحاب', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < order.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Text(const ['🥇', '🥈', '🥉', '4️⃣'][i], style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_name(order[i]) + (order[i] == me ? ' (أنت)' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: order[i] == me ? const Color(0xFFFFD54F) : Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text('${sc[order[i]]}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    if (partner)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'فريقك ${sc[me] + sc[(me + 2) % 4]} • الخصم ${sc[(me + 1) % 4] + sc[(me + 3) % 4]}',
                          style: const TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.w800),
                        ),
                      ),
                    const Divider(color: Colors.white24),
                    Text(
                      stake == 0
                          ? 'مباراة ودّية'
                          : (net > 0 ? 'ربحت $net نقطة من الرهان' : (net < 0 ? 'خسرت ${-net} نقطة' : 'استرددت رهانك')),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    if (pts > 0 || gems > 0)
                      Transform.scale(
                        scale: 1 + 0.06 * math.sin(t * math.pi * 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '🎁 جائزة الخادم: ${pts > 0 ? '+$pts نقطة' : ''}${gems > 0 ? '  +$gems 💎' : ''}',
                            style: const TextStyle(color: Color(0xFF3E2700), fontWeight: FontWeight.w900),
                          ),
                        ),
                      )
                    else if (outcome > 0 && !resigned)
                      const Text('لم تُمنح جائزة (الحد اليومي أو شروط الأهلية).',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
                    // موضع «بعد نتيجة اللعبة» — مغلق افتراضيًّا بطلبي
                    // ويفتحه المالك متى شاء. يُرسَم تحت النتيجة وفوق
                    // الأزرار: لا يحجب الجائزة ولا يسبق خبر الفوز.
                    const ServedAdSlot(
                        placement: 'game_result',
                        height: 78,
                        margin: EdgeInsets.only(top: 10)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(onPressed: TrixWindow.instance.close, child: const Text('إغلاق'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: _newGame, child: const Text('مباراة جديدة'))),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
