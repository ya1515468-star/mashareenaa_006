import 'package:flutter/material.dart';

/// البند 15: اللون البنفسجي في الشات استُبدل بذهبي **متحرك** لا ذهبي ثابت.
///
/// درجات الذهب هنا هي نفس الدرجات المستعملة أصلًا في عناصر الشات الذهبية
/// (الفئة الأسطورية: FFF3A3 → FFD45C → 8A5A00)، حتى يبقى الذهب في التطبيق
/// كله عائلة لون واحدة لا عائلتين متنافرتين.
const List<Color> kAnimatedGoldStops = [
  Color(0xFF8A5A00),
  Color(0xFFFFD45C),
  Color(0xFFFFF3A3),
  Color(0xFFFFD45C),
  Color(0xFF8A5A00),
];

/// درجة ذهبية مفردة لأماكن تستلزم Color واحدًا لا تدرّجًا.
const Color kGoldSolid = Color(0xFFFFD45C);

/// متحكّم حركة مشترك لكل عناصر الذهب: لمعة واحدة تمرّ على الشاشة بإيقاع
/// موحّد بدل أن يلمع كل عنصر بإيقاعه فتبدو الواجهة مضطربة. ولأنه واحد
/// فالتكلفة ثابتة مهما تعدّدت العناصر.
class _GoldTicker extends ChangeNotifier {
  _GoldTicker._() {
    _controller = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _controller.addListener(notifyListeners);
  }

  static final _vsync = _AlwaysTickerProvider();
  static _GoldTicker? _instance;
  static _GoldTicker get instance => _instance ??= _GoldTicker._();

  late final AnimationController _controller;
  double get value => _controller.value;
}

class _AlwaysTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// تدرّج ذهبي متحرك يملأ أي حاوية: اللمعة تنزلق أفقيًا باستمرار.
class AnimatedGoldGradient extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final Border? border;

  const AnimatedGoldGradient({
    super.key,
    required this.child,
    this.borderRadius,
    this.border,
  });

  @override
  State<AnimatedGoldGradient> createState() => _AnimatedGoldGradientState();
}

class _AnimatedGoldGradientState extends State<AnimatedGoldGradient> {
  final _ticker = _GoldTicker.instance;

  @override
  void initState() {
    super.initState();
    _ticker.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الإزاحة تدور من -1 إلى 1 فتمرّ اللمعة عبر الحاوية ثم تعود.
    final t = _ticker.value;
    final shift = (t * 2) - 1;
    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: widget.border,
        gradient: LinearGradient(
          colors: kAnimatedGoldStops,
          begin: Alignment(-1 + shift, -0.3),
          end: Alignment(1 + shift, 0.3),
        ),
      ),
      child: widget.child,
    );
  }
}

/// أيقونة بذهب متحرك عبر ShaderMask — بديل مباشر لأي
/// `Icon(x, color: <بنفسجي>)`.
class AnimatedGoldIcon extends StatefulWidget {
  final IconData icon;
  final double size;

  const AnimatedGoldIcon(this.icon, {super.key, this.size = 24});

  @override
  State<AnimatedGoldIcon> createState() => _AnimatedGoldIconState();
}

class _AnimatedGoldIconState extends State<AnimatedGoldIcon> {
  final _ticker = _GoldTicker.instance;

  @override
  void initState() {
    super.initState();
    _ticker.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shift = (_ticker.value * 2) - 1;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: kAnimatedGoldStops,
        begin: Alignment(-1 + shift, -0.3),
        end: Alignment(1 + shift, 0.3),
      ).createShader(bounds),
      // اللون أبيض لأن srcIn يستبدله بالتدرّج بالكامل.
      child: Icon(widget.icon, size: widget.size, color: Colors.white),
    );
  }
}
