import 'package:flutter/material.dart';
import 'visual_effect_config.dart';
import 'visual_effect_painter.dart';
import 'effect_engine_support.dart';

class VisualEffectEngine extends StatefulWidget {
  final String? effectKey;
  final VisualEffectPlacement placement;
  final VisualEffectQuality quality;
  final Widget child;
  final VisualEffectLayer? layer;
  final int seed;
  const VisualEffectEngine({super.key, required this.effectKey, required this.placement, this.quality=VisualEffectQuality.medium, this.child=const SizedBox.shrink(), this.layer, this.seed=97});
  @override State<VisualEffectEngine> createState()=>_VisualEffectEngineState();
}
class _VisualEffectEngineState extends State<VisualEffectEngine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller=AnimationController(vsync:this,duration:const Duration(seconds:6))..repeat();
  late final EffectEngine _engine = EffectEngine();
  @override void dispose(){_controller.dispose();_engine.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final config = _engine.resolve(widget.effectKey, widget.quality);
    if(config==null) return widget.child;
    final effectiveLayer = widget.layer ?? config.layer;
    if(config.placement != VisualEffectPlacement.both && config.placement != widget.placement) return widget.child;
    return RepaintBoundary(child:AnimatedBuilder(animation:_controller,builder:(context,_){
      return Stack(clipBehavior:Clip.none,fit:StackFit.passthrough,children:[
        effectiveLayer==VisualEffectLayer.behind ? Positioned.fill(child:CustomPaint(painter:VisualEffectPainter(config:config,t:_controller.value,seed:widget.seed))) : const SizedBox.shrink(),
        widget.child,
        if(effectiveLayer!=VisualEffectLayer.behind) Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:VisualEffectPainter(config:config,t:_controller.value,seed:widget.seed))))
      ]);
    }));
  }
}
