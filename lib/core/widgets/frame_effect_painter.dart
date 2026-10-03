import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'frame_effect_catalog.dart';

/// Reusable, deterministic vector effect renderer for avatar frames.
class FrameEffectPainter extends CustomPainter {
  final String effect;
  final double t;
  const FrameEffectPainter({required this.effect, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final e = FrameEffectCatalog.normalize(effect);
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * .43;
    switch (e) {
      case 'pulse_glow': _pulse(canvas, c, r); break;
      case 'lightning': _lightning(canvas, c, r); break;
      case 'fire': _fire(canvas, c, r, 1.0); break;
      case 'flame': _fire(canvas, c, r, 1.45); break;
      case 'crossed_swords': _swords(canvas, c, r); break;
      case 'ice_crystals': _crystals(canvas, c, r); break;
      case 'orbiting_stars': _orbitStars(canvas, c, r); break;
      case 'meteor_shower': _meteors(canvas, c, r); break;
      case 'neon_rainbow': _rainbow(canvas, c, r); break;
      case 'rotating_ring': _ring(canvas, c, r); break;
      case 'spark_burst': _burst(canvas, c, r); break;
      case 'bubbles': _bubbles(canvas, c, r); break;
      case 'snow': _snow(canvas, c, r); break;
      case 'petals': _petals(canvas, c, r); break;
      case 'hearts': _hearts(canvas, c, r); break;
      case 'coins': _coins(canvas, c, r); break;
      case 'magic_runes': _runes(canvas, c, r); break;
      case 'plasma_arc': _plasma(canvas, c, r); break;
      case 'cosmic_dust': _dust(canvas, c, r); break;
      case 'solar_flare': _solar(canvas, c, r); break;
      case 'shadow_smoke': _smoke(canvas, c, r); break;
      case 'wind_blades': _wind(canvas, c, r); break;
      case 'electric_orbit': _electric(canvas, c, r); break;
      case 'golden_sparkle': _gold(canvas, c, r); break;
      case 'diamond_shine': _diamond(canvas, c, r); break;
      case 'water_wave': _water(canvas, c, r); break;
      case 'rose_petal': _rose(canvas, c, r); break;
      case 'phoenix': _phoenix(canvas, c, r); break;
      case 'comet': _comet(canvas, c, r); break;
      case 'vortex': _vortex(canvas, c, r); break;
    }
  }

  Paint _p(Color color, {double width = 2, PaintingStyle style = PaintingStyle.stroke}) =>
      Paint()..color=color..style=style..strokeWidth=width..strokeCap=StrokeCap.round;

  void _pulse(Canvas c, Offset o, double r) {
    final a=.25+.35*((math.sin(t*math.pi*2)+1)/2);
    c.drawCircle(o,r,_p(Colors.white.withValues(alpha:a),width:r*.07));
  }
  void _lightning(Canvas c, Offset o, double r) {
    final phase=(t*6)%1; final flash=math.max(0.15, 1-(phase-.18).abs()*4);
    final p=_p(Colors.white.withValues(alpha:flash),width:r*.055);
    for(final side in [-1.0,1.0]) { final path=Path()..moveTo(o.dx+side*r*.92,o.dy-r*.42)..lineTo(o.dx+side*r*.58,o.dy-r*.08)..lineTo(o.dx+side*r*.78,o.dy-r*.02)..lineTo(o.dx+side*r*.48,o.dy+r*.36); c.drawPath(path,p); }
    c.drawCircle(o,r*.83,_p(Colors.cyanAccent.withValues(alpha:flash*.3),width:r*.025));
  }
  void _fire(Canvas c, Offset o, double r, double speed) {
    final fill=_p(Colors.orangeAccent.withValues(alpha:.72),style:PaintingStyle.fill);
    for(int i=0;i<12;i++){final a=i/12*math.pi*2+t*speed;final x=o.dx+math.cos(a)*r;final y=o.dy+math.sin(a)*r;final s=r*(.055+.018*math.sin(t*20+i).abs());final path=Path()..moveTo(x-s,y+s)..quadraticBezierTo(x-s*1.5,y-s,x,y-s*3.2)..quadraticBezierTo(x+s*1.5,y-s,x+s,y+s)..close(); c.save();c.translate(0,math.sin(t*18+i)*2);c.rotate(math.sin(t*8+i)*.2);c.drawPath(path,fill);c.restore();}
  }
  void _swords(Canvas c, Offset o, double r) {
    final hit=math.sin(t*math.pi*4); final base=.62+hit*.22;
    for(final s in [-1.0,1.0]) {c.save();c.translate(o.dx,o.dy);c.rotate(s*base);final p=_p(Colors.white.withValues(alpha:.95),width:r*.055);c.drawLine(Offset(0,r*.52),Offset(0,-r*.62),p);c.drawLine(Offset(-r*.13,r*.18),Offset(r*.13,r*.18),p);c.drawLine(Offset(-r*.07,-r*.54),Offset(r*.07,-r*.7),p);c.restore();}
    final spark=(hit.abs()); for(int i=0;i<6;i++){final a=i/6*math.pi*2+t*3;final rr=r*(.1+.18*spark);c.drawCircle(o+Offset(math.cos(a)*rr,math.sin(a)*rr),r*.018,_p(Colors.yellowAccent.withValues(alpha:spark),style:PaintingStyle.fill));}
  }
  void _crystals(Canvas c, Offset o, double r){for(int i=0;i<10;i++){final a=i/10*math.pi*2+t*.15;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);final p=_p(Colors.lightBlueAccent.withValues(alpha:.8),width:r*.025);final path=Path()..moveTo(q.dx,q.dy-r*.09)..lineTo(q.dx+r*.055,q.dy)..lineTo(q.dx,q.dy+r*.09)..lineTo(q.dx-r*.055,q.dy)..close();c.drawPath(path,p);}}
  void _orbitStars(Canvas c, Offset o, double r){for(int i=0;i<7;i++){final a=i/7*math.pi*2+t*2.2;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);_star(c,q,r*.045,5,Colors.white.withValues(alpha:.7+.3*math.sin(t*10+i).abs()));}}
  void _meteors(Canvas c, Offset o, double r){for(int i=0;i<6;i++){final a=i/6*math.pi*2+t*1.5;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);final tail=q-Offset(math.cos(a),math.sin(a))*r*.22;c.drawLine(tail,q,_p(Colors.white.withValues(alpha:.65),width:r*.035));c.drawCircle(q,r*.035,_p(Colors.white,style:PaintingStyle.fill));}}
  void _rainbow(Canvas c, Offset o, double r){final p=_p(Colors.transparent,width:r*.07);p.shader=const SweepGradient(colors:<Color>[Colors.red,Colors.orange,Colors.yellow,Colors.green,Colors.cyan,Colors.blue,Colors.purple,Colors.red]).createShader(Rect.fromCircle(center:o,radius:r));c.drawCircle(o,r,p);}
  void _ring(Canvas c, Offset o, double r){c.drawArc(Rect.fromCircle(center:o,radius:r),t*math.pi*2,math.pi*1.25,false,_p(Colors.white.withValues(alpha:.9),width:r*.055));}
  void _burst(Canvas c, Offset o, double r){final pulse=(math.sin(t*math.pi*6)+1)/2;for(int i=0;i<16;i++){final a=i/16*math.pi*2;final q=o+Offset(math.cos(a)*r*(.7+.25*pulse),math.sin(a)*r*(.7+.25*pulse));c.drawLine(o+Offset(math.cos(a)*r*.35,math.sin(a)*r*.35),q,_p(Colors.orangeAccent.withValues(alpha:.8),width:r*.018));}}
  void _bubbles(Canvas c, Offset o, double r){for(int i=0;i<9;i++){final a=i/9*math.pi*2+t*.7;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawCircle(q,r*(.03+.015*math.sin(t*5+i).abs()),_p(Colors.white.withValues(alpha:.55),width:r*.018));}}
  void _snow(Canvas c, Offset o, double r){for(int i=0;i<12;i++){final a=i/12*math.pi*2;final q=o+Offset(math.cos(a+t*.25)*r,math.sin(a+t*.25)*r);c.drawCircle(q,r*.025,_p(Colors.white.withValues(alpha:.85),style:PaintingStyle.fill));}}
  void _petals(Canvas c, Offset o, double r){for(int i=0;i<9;i++){final a=i/9*math.pi*2+t;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.save();c.translate(q.dx,q.dy);c.rotate(a);c.drawOval(Rect.fromCenter(center:Offset.zero,width:r*.09,height:r*.04),_p(Colors.pinkAccent.withValues(alpha:.75),style:PaintingStyle.fill));c.restore();}}
  void _hearts(Canvas c, Offset o, double r){for(int i=0;i<7;i++){final a=i/7*math.pi*2-t*.5;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);final p=_p(Colors.redAccent.withValues(alpha:.8),width:r*.025);final path=Path()..moveTo(q.dx,q.dy+r*.06)..cubicTo(q.dx-r*.08,q.dy-r*.02,q.dx-r*.04,q.dy-r*.1,q.dx,q.dy-r*.035)..cubicTo(q.dx+r*.04,q.dy-r*.1,q.dx+r*.08,q.dy-r*.02,q.dx,q.dy+r*.06);c.drawPath(path,p);}}
  void _coins(Canvas c, Offset o, double r){for(int i=0;i<6;i++){final a=i/6*math.pi*2+t;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawOval(Rect.fromCenter(center:q,width:r*.12,height:r*(.04+.06*math.sin(t*8+i).abs())),_p(Colors.amber.withValues(alpha:.9),style:PaintingStyle.fill));}}
  void _runes(Canvas c, Offset o, double r){for(int i=0;i<8;i++){final a=i/8*math.pi*2-t*.4;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawCircle(q,r*.045,_p(Colors.deepPurpleAccent.withValues(alpha:.85),width:r*.02));}}
  void _plasma(Canvas c, Offset o, double r){final path=Path();for(int i=0;i<=36;i++){final a=i/36*math.pi*2;final rr=r*(.94+.06*math.sin(a*7+t*18));final q=o+Offset(math.cos(a)*rr,math.sin(a)*rr);i==0?path.moveTo(q.dx,q.dy):path.lineTo(q.dx,q.dy);}c.drawPath(path,_p(Colors.purpleAccent.withValues(alpha:.8),width:r*.045));}
  void _dust(Canvas c, Offset o, double r){for(int i=0;i<24;i++){final a=i/24*math.pi*2+t*(i.isEven?-.5:.35);final rr=r*(.45+.5*((i*17)%23)/23);final q=o+Offset(math.cos(a)*rr,math.sin(a)*rr);c.drawCircle(q,r*.012,_p(Colors.cyanAccent.withValues(alpha:.55),style:PaintingStyle.fill));}}
  void _solar(Canvas c, Offset o, double r){final p=_p(Colors.yellowAccent.withValues(alpha:.5+.3*math.sin(t*8).abs()),width:r*.045);for(int i=0;i<16;i++){final a=i/16*math.pi*2+t*.4;c.drawLine(o+Offset(math.cos(a)*r*.8,math.sin(a)*r*.8),o+Offset(math.cos(a)*r*1.08,math.sin(a)*r*1.08),p);}}
  void _smoke(Canvas c, Offset o, double r){for(int i=0;i<9;i++){final a=i/9*math.pi*2+t*.2;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawCircle(q,r*(.04+.025*math.sin(t*4+i).abs()),_p(Colors.black.withValues(alpha:.22),style:PaintingStyle.fill));}}
  void _wind(Canvas c, Offset o, double r){for(int i=0;i<8;i++){final a=i/8*math.pi*2+t*1.4;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawLine(q,q+Offset(-math.sin(a)*r*.16,math.cos(a)*r*.16),_p(Colors.white.withValues(alpha:.65),width:r*.025));}}
  void _electric(Canvas c, Offset o, double r){for(int i=0;i<3;i++){final a=t*math.pi*2+i*math.pi*2/3;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawCircle(q,r*.04,_p(Colors.cyanAccent,style:PaintingStyle.fill));}}
  void _gold(Canvas c, Offset o, double r){for(int i=0;i<12;i++){final a=i/12*math.pi*2+t;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);_star(c,q,r*.045,4,Colors.amberAccent);}}
  void _diamond(Canvas c, Offset o, double r){final p=_p(Colors.white.withValues(alpha:.4+.6*math.sin(t*10).abs()),width:r*.025);for(int i=0;i<5;i++){final a=i/5*math.pi*2+t;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);c.drawLine(q-Offset(r*.07,0),q+Offset(r*.07,0),p);c.drawLine(q-Offset(0,r*.07),q+Offset(0,r*.07),p);}}
  void _water(Canvas c, Offset o, double r){for(int k=0;k<3;k++){final path=Path();for(int i=0;i<=30;i++){final a=i/30*math.pi*2;final rr=r*(.94+k*.035+.018*math.sin(a*5+t*5+k));final q=o+Offset(math.cos(a)*rr,math.sin(a)*rr);i==0?path.moveTo(q.dx,q.dy):path.lineTo(q.dx,q.dy);}c.drawPath(path,_p(Colors.lightBlueAccent.withValues(alpha:.45+.15*k),width:r*.018));}}
  void _rose(Canvas c, Offset o, double r){_petals(c,o,r);c.drawCircle(o,r*.12,_p(Colors.redAccent.withValues(alpha:.5),style:PaintingStyle.fill));}
  void _phoenix(Canvas c, Offset o, double r){final p=_p(Colors.orangeAccent.withValues(alpha:.8),width:r*.04);final lift=math.sin(t*math.pi*2)*r*.06;c.drawArc(Rect.fromCircle(center:o+Offset(0,lift),radius:r),math.pi*1.05,math.pi*.9,false,p);c.drawArc(Rect.fromCircle(center:o+Offset(0,lift),radius:r*.72),math.pi*1.15,math.pi*.7,false,p);}
  void _comet(Canvas c, Offset o, double r){final a=t*math.pi*2;final q=o+Offset(math.cos(a)*r,math.sin(a)*r);for(int i=1;i<=6;i++){final s=i/6;c.drawLine(q,q-Offset(math.cos(a)*r*.35*s,math.sin(a)*r*.35*s),_p(Colors.white.withValues(alpha:(1-s)*.7),width:r*.02));}c.drawCircle(q,r*.05,_p(Colors.white,style:PaintingStyle.fill));}
  void _vortex(Canvas c, Offset o, double r){for(int i=0;i<4;i++){final rect=Rect.fromCircle(center:o,radius:r*(.65+i*.09));c.drawArc(rect,t*math.pi*2+i,math.pi*1.35,false,_p(Colors.purpleAccent.withValues(alpha:.55),width:r*.025));}}

  void _star(Canvas canvas, Offset c, double r, int points, Color color) {final path=Path();for(int i=0;i<points*2;i++){final rr=i.isEven?r:r*.42;final a=-math.pi/2+i*math.pi/points;final q=c+Offset(math.cos(a)*rr,math.sin(a)*rr);i==0?path.moveTo(q.dx,q.dy):path.lineTo(q.dx,q.dy);}path.close();canvas.drawPath(path,_p(color,style:PaintingStyle.fill));}
  @override bool shouldRepaint(covariant FrameEffectPainter old) => old.effect!=effect || old.t!=t;
}
