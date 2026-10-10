import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/services/server_sounds.dart';

/// نرد ثلاثي الأبعاد حقيقي: مكعب بستة أوجه (مجموع كل وجهين متقابلين = 7)
/// يُرسَم بمصفوفات تحويل ثلاثية الأبعاد مع منظور وإخفاء للأوجه الخلفية.
///
/// ضمان تطابق النتيجة مع النقاط المعروضة: الوجه الذي يستقر مواجهًا
/// للمشاهد هو الوجه الذي يحمل قيمة [Dice3D.value] حرفيًا، لأن مصفوفة
/// الاستقرار تُحسب من نفس جدول الأوجه الذي تُرسَم منه النقاط. لا يوجد أي
/// رقم يُعرض منفصلًا عن الوجه المرسوم.
class _FaceDef {
  final int value;
  final double rx;
  final double ry;
  const _FaceDef(this.value, this.rx, this.ry);
}

const List<_FaceDef> _faces = [
  _FaceDef(1, 0, 0),
  _FaceDef(6, 0, math.pi),
  _FaceDef(3, 0, math.pi / 2),
  _FaceDef(4, 0, -math.pi / 2),
  _FaceDef(2, -math.pi / 2, 0),
  _FaceDef(5, math.pi / 2, 0),
];

Matrix4 _faceRot(_FaceDef f) => Matrix4.identity()
  ..rotateY(f.ry)
  ..rotateX(f.rx);

Matrix4 _faceRotInv(_FaceDef f) => Matrix4.identity()
  ..rotateX(-f.rx)
  ..rotateY(-f.ry);

/// مواضع النقاط القياسية لكل وجه (شبكة 3×3).
const Map<int, List<List<int>>> _pipLayout = {
  1: [[1, 1]],
  2: [[0, 0], [2, 2]],
  3: [[0, 0], [1, 1], [2, 2]],
  4: [[0, 0], [0, 2], [2, 0], [2, 2]],
  5: [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]],
  6: [[0, 0], [0, 2], [1, 0], [1, 2], [2, 0], [2, 2]],
};

class _PipsPainter extends CustomPainter {
  final int value;
  _PipsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final cells = _pipLayout[value.clamp(1, 6)]!;
    final s = size.width;
    final r = s * 0.095;
    for (final c in cells) {
      final center = Offset(s * (0.25 + 0.25 * c[1]), s * (0.25 + 0.25 * c[0]));
      final paint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A3A3A), Color(0xFF000000)],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PipsPainter old) => old.value != value;
}

/// مكعب نرد واحد. [progress] من 0 إلى 1: 0 بداية الدحرجة، 1 استقرار تام على
/// الوجه [value].
class Dice3D extends StatelessWidget {
  final int value;
  final double progress;
  final double size;
  final int seed;
  const Dice3D({
    super.key,
    required this.value,
    required this.progress,
    this.size = 120,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(1, 6);
    final p = progress.clamp(0.0, 1.0);
    final e = Curves.easeOutCubic.transform(p);
    final k = 1 - e;
    final dir = seed.isEven ? 1.0 : -1.0;

    final spin = Matrix4.identity()
      ..rotateZ((2 * math.pi + 0.6) * k * dir)
      ..rotateX((4 * math.pi + 0.9) * k)
      ..rotateY((6 * math.pi + 0.4) * k * dir);
    final target = _faces.firstWhere((f) => f.value == v);
    final settle = _faceRotInv(target);
    final tilt = Matrix4.identity()
      ..rotateX(-0.38)
      ..rotateY(-0.5);
    final rotOnly = Matrix4.identity()
      ..multiply(tilt)
      ..multiply(spin)
      ..multiply(settle);
    final base = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..multiply(rotOnly);

    final half = size / 2;
    final core = <Widget>[];
    final faceWidgets = <Widget>[];
    for (final f in _faces) {
      final rot = _faceRot(f);
      final rotated = Matrix4.copy(rotOnly)..multiply(rot);
      // z لمتجه الوجه العمودي بعد كل الدورانات = المدخل (2,2).
      final nz = rotated.entry(2, 2);
      if (nz <= 0.0) continue; // وجه خلفي: لا يُرسَم
      final shade = nz.clamp(0.0, 1.0);
      final faceColorA =
          Color.lerp(const Color(0xFFB4BCC4), const Color(0xFFFAFBFC), shade)!;
      final faceColorB =
          Color.lerp(const Color(0xFF8E98A2), const Color(0xFFDDE2E7), shade)!;

      core.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)
          ..multiply(rot)
          ..translate(0.0, 0.0, half * 0.985),
        child: Container(
          width: size * 0.97,
          height: size * 0.97,
          decoration: BoxDecoration(
            color: faceColorB,
            borderRadius: BorderRadius.circular(size * 0.12),
          ),
        ),
      ));
      faceWidgets.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)
          ..multiply(rot)
          ..translate(0.0, 0.0, half),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [faceColorA, faceColorB],
            ),
          ),
          child: CustomPaint(painter: _PipsPainter(f.value)),
        ),
      ));
    }

    final hop = -(math.sin(p * math.pi * 3).abs()) * size * 0.5 * (1 - p);
    final shadowScale = 1.0 - (hop.abs() / (size * 0.9));
    final box = size * 1.7;
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(0, size * 0.78),
            child: Container(
              width: size * 0.95 * shadowScale.clamp(0.4, 1.0),
              height: size * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.black.withValues(alpha: 0.35),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: size * 0.12),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, hop),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [...core, ...faceWidgets],
            ),
          ),
        ],
      ),
    );
  }
}

/// حوار مسرح النرد: يدحرج نردًا واحدًا (رمية سريعة) أو اثنين (تحدٍّ)، ثم
/// يستقر كل نرد على القيمة المُمرَّرة حرفيًا ويعرض سطر النتيجة.
class DiceStageDialog extends StatefulWidget {
  final List<({String label, int value})> dice;
  final String? footer;
  final Duration hold;

  /// نغمة الاستقرار: dice_land عادةً، dice_jackpot للجائزة، game_win/game_lose للتحدي.
  final String finishSound;
  const DiceStageDialog({
    super.key,
    required this.dice,
    this.footer,
    this.hold = const Duration(milliseconds: 2200),
    this.finishSound = 'dice_land',
  });

  @override
  State<DiceStageDialog> createState() => _DiceStageDialogState();
}

class _DiceStageDialogState extends State<DiceStageDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _done = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400));
    playServerSound('dice_roll');
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        playServerSound(widget.finishSound);
        setState(() => _done = true);
        _closeTimer = Timer(widget.hold, () {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final diceSize =
        widget.dice.length > 1 ? math.min(90.0, (width - 48) / 3.4) : 120.0;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.dice.length; i++)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.dice[i].label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, _) => Dice3D(
                            value: widget.dice[i].value,
                            progress: _ctrl.value,
                            size: diceSize,
                            seed: i,
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _done ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Text('${widget.dice[i].value}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _done ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(widget.footer ?? '',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// واجهة الاستدعاء المستخدمة في الشات.
class AnimatedDiceRoller {
  static bool _open = false;

  /// رمية فردية. النتيجة [result] تأتي من الخادم وتُعرَض كما هي.
  static Future<void> show(BuildContext context, int result,
      {String label = 'النرد', String? footer, bool jackpot = false}) async {
    if (_open) return;
    _open = true;
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        builder: (_) => DiceStageDialog(
          dice: [(label: label, value: result)],
          finishSound: jackpot ? 'dice_jackpot' : 'dice_land',
          footer: footer ?? 'النتيجة: $result',
          hold: footer != null
              ? const Duration(milliseconds: 3600)
              : const Duration(milliseconds: 2200),
        ),
      );
    } finally {
      _open = false;
    }
  }

  /// تحدٍّ بين لاعبين؛ كل الأرقام والنتيجة من الخادم.
  static Future<void> showDuel(
    BuildContext context, {
    required String fromName,
    required String toName,
    required int fromRoll,
    required int toRoll,
    required int stake,
    required String? winnerName,
    String finishSound = 'dice_land',
  }) async {
    if (_open) return;
    _open = true;
    try {
      final footer = winnerName == null
          ? 'تعادل — لا تغيير في النقاط'
          : (stake > 0
              ? 'فاز $winnerName وربح $stake نقطة'
              : 'فاز $winnerName');
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        builder: (_) => DiceStageDialog(
          dice: [
            (label: fromName, value: fromRoll),
            (label: toName, value: toRoll),
          ],
          footer: footer,
          finishSound: finishSound,
          hold: const Duration(milliseconds: 3200),
        ),
      );
    } finally {
      _open = false;
    }
  }
}
