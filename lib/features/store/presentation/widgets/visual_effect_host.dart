import 'package:flutter/material.dart';
import 'visual_effect_config.dart';
import 'visual_effect_engine.dart';

class VisualEffectHost extends StatelessWidget {
  final String? effectKey;
  final VisualEffectPlacement placement;
  final Widget child;
  final VisualEffectQuality quality;
  final VisualEffectLayer? layer;
  final int seed;
  const VisualEffectHost({super.key,required this.effectKey,required this.placement,required this.child,this.quality=VisualEffectQuality.medium,this.layer,this.seed=97});
  @override Widget build(BuildContext context)=>VisualEffectEngine(effectKey:effectKey,placement:placement,quality:quality,layer:layer,seed:seed,child:child);
}
