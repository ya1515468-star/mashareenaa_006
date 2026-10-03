import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'visual_effect_config.dart';

class VisualEffectPainter extends CustomPainter {
  final VisualEffectConfig config;
  final double t;
  final int seed;
  VisualEffectPainter(
      {required this.config, required this.t, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final double minDim = math.min(size.width, size.height);
    final base = minDim * .5 * config.scale;
    final areaWidth = size.width <= 1.0 ? 1.0 : size.width;
    final rnd = math.Random(seed);
    final key = config.effectKey;

    // First ten models follow the supplied video's ornamental identity-frame
    // language: symmetric wings, a crest, layered highlight and timed motion.
    const videoKeys = <String>{
      'pulse_glow','lightning','fire','flame','crossed_swords',
      'ice_crystals','orbiting_stars','meteor_shower','neon_rainbow','rotating_ring'
    };
    if (videoKeys.contains(key)) {
      _paintVideoReferenceFrame(canvas, size, t, config, key);
    }

    switch (key) {
      case 'pulse_glow':
        final pulse = .5 + .5 * math.sin(t * math.pi * 2 * config.speed);
        canvas.drawCircle(
            Offset(cx, cy),
            base * (.72 + .1 * pulse),
            Paint()
              ..color = config.colors.first.withValues(alpha: .12 + .12 * pulse)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 8 * pulse));
        break;
      case 'lightning':
        final flash = ((t * 7.1) % 1.0) < .16 ? 1.0 : .42;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + config.intensity * 1.2
          ..strokeCap = StrokeCap.round
          ..color = config.colors.first.withValues(alpha: .85 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        for (var b = 0; b < 2; b++) {
          final path = Path()..moveTo(size.width * (.08 + b * .5), 0);
          for (var i = 1; i < 7; i++) {
            path.lineTo(
                size.width *
                    (.08 +
                        b * .5 +
                        (i.isEven ? .04 : -.03) * math.sin((t * 19) + i + b)),
                size.height * i / 7);
          }
          canvas.drawPath(path, p);
        }
        break;
      case 'fire':
      case 'flame':
        final count = config.particleCount;
        for (var i = 0; i < count; i++) {
          final phase =
              ((t * config.speed * rnd.nextDouble()) + i / count) % 1.0;
          final x = (i * 37.0 + rnd.nextDouble() * 19) % areaWidth;
          final y = size.height * (1 - phase);
          final sway = math.sin(phase * math.pi * 3 + i) * size.width * .08;
          final radius = (1.5 + rnd.nextDouble() * 3) * (1 - phase * .35);
          final color = config.colors[i % config.colors.length]
              .withValues(alpha: (1 - phase).clamp(.05, 1).toDouble() * .8);
          canvas.drawCircle(
              Offset(x + sway, y),
              radius,
              Paint()
                ..color = color
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .6));
        }
        break;
      case 'crossed_swords':
        final cycle = (t * config.speed) % 1.0;
        final collide = math.sin(cycle * math.pi);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = config.colors.first.withValues(alpha: .82);
        final a = Offset(size.width * .12 + size.width * .22 * collide,
            size.height * .15 + size.height * .7 * collide);
        final b = Offset(size.width * .88 - size.width * .22 * collide,
            size.height * .85 - size.height * .7 * collide);
        canvas.drawLine(a, b, p..color = config.colors.first);
        canvas.drawLine(Offset(a.dx, a.dy + 6), Offset(b.dx, b.dy + 6),
            p..color = config.colors.last.withValues(alpha: .6));
        if (cycle < .22) {
          canvas.drawCircle(
              Offset(cx, cy),
              4 + 5 * collide,
              Paint()
                ..color = Colors.white.withValues(alpha: .8)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
        break;
      case 'ice_crystals':
        for (var i = 0; i < 9; i++) {
          final a = (i / 9) * math.pi * 2 + t * config.speed;
          final r = base * (.72 + .1 * math.sin(i));
          final o = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
          final p = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                config.colors[i % config.colors.length].withValues(alpha: .7);
          canvas.drawLine(o + const Offset(-4, 0), o + const Offset(4, 0), p);
          canvas.drawLine(o + const Offset(0, -4), o + const Offset(0, 4), p);
        }
        break;
      case 'orbiting_stars':
      case 'electric_orbit':
      case 'rotating_ring':
        final rings = key == 'rotating_ring' ? 1 : 2;
        final slots = key == 'rotating_ring' ? 1 : 5;
        for (var r = 0; r < rings; r++) {
          final rr = base * (.72 - r * .12);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = key == 'electric_orbit' ? 1.2 : 1
            ..color =
                config.colors[r % config.colors.length].withValues(alpha: .62);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(cx, cy),
                  width: rr * 2,
                  height: rr * (1.0 - .22 * r) * 2),
              paint);
          for (var i = 0; i < slots; i++) {
            final a = t * math.pi * 2 * config.speed * (r.isEven ? 1 : -1) +
                i * math.pi * 2 / (key == 'rotating_ring' ? 1.0 : 5.0);
            final o = Offset(
                cx + math.cos(a) * rr, cy + math.sin(a) * rr * (1 - .22 * r));
            canvas.drawCircle(o, key == 'rotating_ring' ? 2.5 : 2,
                Paint()..color = config.colors[(i + r) % config.colors.length]);
          }
        }
        break;
      case 'meteor_shower':
        final p = Paint()..strokeCap = StrokeCap.round;
        for (var i = 0; i < config.particleCount; i++) {
          final phase = (t * config.speed + i / config.particleCount) % 1.0;
          final x = (i * 53.0 + phase * size.width * .8) % size.width;
          final y = phase * size.height;
          const tail = Offset(-6, -12);
          canvas.drawLine(
              Offset(x, y),
              Offset(x + tail.dx, y + tail.dy),
              p
                ..strokeWidth = 1.2
                ..color = config.colors[i % 2]
                    .withValues(alpha: (1 - phase).clamp(0, 1).toDouble())
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        }
        break;
      case 'neon_rainbow':
        final shift = t * math.pi * 2 * config.speed;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..shader = SweepGradient(
                  startAngle: shift,
                  endAngle: shift + math.pi * 2,
                  colors: config.colors)
              .createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(2),
                Radius.circular(math.min(12, size.height * .3))),
            p);
        break;
      case 'spark_burst':
      case 'golden_sparkle':
      case 'diamond_shine':
        final shine = t * config.speed;
        for (var i = 0; i < config.particleCount; i++) {
          final phase = (shine + i / config.particleCount) % 1;
          final a = i * 2.17;
          final r = base * (.3 + .55 * phase);
          final o = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
          final alpha = (math.sin(phase * math.pi)).clamp(0, 1);
          final p = Paint()
            ..color = config.colors[i % config.colors.length]
                .withValues(alpha: alpha.toDouble());
          final s = key == 'diamond_shine' ? 2.4 : 1.6;
          canvas.drawLine(o - Offset(s, 0), o + Offset(s, 0), p);
          canvas.drawLine(o - Offset(0, s), o + Offset(0, s), p);
        }
        break;
      case 'bubbles':
      case 'snow':
      case 'petals':
      case 'hearts':
      case 'coins':
      case 'rose_petal':
        for (var i = 0; i < config.particleCount; i++) {
          final phase = (t * config.speed * (.6 + rnd.nextDouble() * .8) +
                  i / config.particleCount) %
              1.0;
          final x = ((i * 71.0) +
                  math.sin(phase * math.pi * 2 + i) * size.width * .15) %
              areaWidth;
          final y = size.height * (1 - phase);
          final o = Offset(x, y);
          final c = config.colors[i % config.colors.length].withValues(
              alpha:
                  (math.sin(phase * math.pi) * .75).clamp(.0, .8).toDouble());
          final p = Paint()
            ..color = c
            ..style = PaintingStyle.fill;
          if (key == 'snow') {
            canvas.drawCircle(o, 1.2 + rnd.nextDouble() * 2.2, p);
          } else if (key == 'bubbles') {
            canvas.drawCircle(
                o,
                2 + rnd.nextDouble() * 3,
                p
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = .8);
          } else if (key == 'coins') {
            canvas.save();
            canvas.translate(o.dx, o.dy);
            canvas.scale(math.cos(phase * math.pi * 2), 1);
            canvas.drawOval(const Rect.fromLTWH(-3, -4, 6, 8), p);
            canvas.restore();
          } else {
            final path = Path();
            final s = 2 + rnd.nextDouble() * 2;
            if (key == 'hearts') {
              path.moveTo(o.dx, o.dy + s);
              path.cubicTo(o.dx - s * 1.5, o.dy - s, o.dx - s * .2,
                  o.dy - s * 1.5, o.dx, o.dy - s * .2);
              path.cubicTo(o.dx + s * .2, o.dy - s * 1.5, o.dx + s * 1.5,
                  o.dy - s, o.dx, o.dy + s);
            } else {
              canvas.save();
              canvas.translate(o.dx, o.dy);
              canvas.rotate(math.sin(phase * math.pi * 2) * .7);
              canvas.drawOval(
                  Rect.fromCenter(
                      center: Offset.zero, width: s * 2, height: s * 1.4),
                  p);
              canvas.restore();
            }
          }
        }
        break;
      case 'magic_runes':
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = config.colors.first.withValues(alpha: .58);
        canvas.drawCircle(Offset(cx, cy), base * .76, p);
        canvas.drawCircle(Offset(cx, cy), base * .62, p);
        for (var i = 0; i < 7; i++) {
          final a = t * math.pi * 2 * config.speed + i * math.pi * 2 / 7;
          final o = Offset(
              cx + math.cos(a) * base * .68, cy + math.sin(a) * base * .68);
          canvas.drawLine(o - const Offset(3, 0), o + const Offset(3, 0),
              p..color = config.colors[i % config.colors.length]);
        }
        break;
      case 'plasma_arc':
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = config.colors.first.withValues(alpha: .72)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        final path = Path()..moveTo(0, cy);
        for (var i = 1; i < 8; i++) {
          path.lineTo(size.width * i / 8,
              cy + math.sin(t * 11 + i * 1.7) * size.height * .18);
        }
        path.lineTo(size.width, cy);
        canvas.drawPath(path, p);
        canvas.save();
        canvas.translate(0, 4);
        canvas.drawPath(
            path, p..color = config.colors.last.withValues(alpha: .45));
        canvas.restore();
        break;
      case 'cosmic_dust':
        for (var i = 0; i < config.particleCount; i++) {
          final a = i * 1.618;
          final rr = ((i * 31) % 100) / 100 * base;
          final z = .5 + .5 * math.sin(t * math.pi * 2 * config.speed + i);
          canvas.drawCircle(
              Offset(cx + math.cos(a + t * .6) * rr,
                  cy + math.sin(a + t * .4) * rr),
              .7 + 1.2 * z,
              Paint()
                ..color = config.colors[i % 3].withValues(alpha: .2 + .55 * z));
        }
        break;
      case 'solar_flare':
        final pulse = .75 + .25 * math.sin(t * math.pi * 2 * config.speed);
        canvas.drawCircle(
            Offset(cx, cy),
            base * .55,
            Paint()
              ..color = config.colors.first.withValues(alpha: .14 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        for (var i = 0; i < 10; i++) {
          final a = i * .63 + t * 1.5;
          final p = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = config.colors[i % 2].withValues(alpha: .42);
          canvas.drawArc(
              Rect.fromCircle(
                  center: Offset(cx, cy),
                  radius: base * (.55 + .08 * math.sin(i))),
              a,
              .35 + math.sin(t * 5 + i) * .15,
              false,
              p);
        }
        break;
      case 'shadow_smoke':
        for (var i = 0; i < 12; i++) {
          final phase = (t * config.speed + i / 12) % 1;
          final o = Offset(cx + math.sin(phase * 5 + i) * base * .35,
              cy - base * .55 + phase * base * 1.1);
          canvas.drawCircle(
              o,
              4 + phase * 7,
              Paint()
                ..color =
                    config.colors[i % 2].withValues(alpha: .08 * (1 - phase))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
        break;
      case 'wind_blades':
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.4
          ..color = config.colors.first.withValues(alpha: .58);
        for (var i = 0; i < 5; i++) {
          final y = size.height * (.15 + i * .16);
          canvas.drawArc(
              Rect.fromLTWH(-base * .3, y - 4, size.width + base * .6, 10),
              math.pi * .05 + math.sin(t * 10 + i) * .1,
              math.pi * .75,
              false,
              p);
        }
        break;
      case 'water_wave':
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = config.colors.first.withValues(alpha: .48);
        for (var r = 0; r < 3; r++) {
          final rr = base * (.4 + r * .18) +
              math.sin(t * math.pi * 2 * config.speed + r) * 3;
          canvas.drawCircle(Offset(cx, cy), rr, p);
        }
        break;
      case 'phoenix':
        final wing = math.sin(t * math.pi * 2 * config.speed) * .18;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..color = config.colors.first.withValues(alpha: .72);
        final left = Path()
          ..moveTo(cx, cy)
          ..quadraticBezierTo(
              cx - base * .55, cy - base * .3, cx - base * .7, cy + wing * base)
          ..quadraticBezierTo(
              cx - base * .35, cy + base * .1, cx, cy + base * .22);
        final right = Path()
          ..moveTo(cx, cy)
          ..quadraticBezierTo(
              cx + base * .55, cy - base * .3, cx + base * .7, cy + wing * base)
          ..quadraticBezierTo(
              cx + base * .35, cy + base * .1, cx, cy + base * .22);
        canvas.drawPath(left, p);
        canvas.drawPath(
            right, p..color = config.colors.last.withValues(alpha: .68));
        for (var i = 0; i < 10; i++) {
          final phase = (t * config.speed + i / 10) % 1;
          canvas.drawCircle(
              Offset(cx + (i.isEven ? -1 : 1) * math.sin(i) * base * .35,
                  cy + base * .1 - phase * base * .8),
              1.2,
              Paint()
                ..color = config.colors[i % 3].withValues(alpha: 1 - phase));
        }
        break;
      case 'comet':
        final a = t * math.pi * 2 * config.speed;
        final rr = base * .72;
        final head = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr * .72);
        final tail = Offset(
            cx + math.cos(a - 0.55) * rr, cy + math.sin(a - 0.55) * rr * .72);
        canvas.drawLine(
            head,
            tail,
            Paint()
              ..strokeWidth = 2.2
              ..color = config.colors.first.withValues(alpha: .6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        canvas.drawCircle(head, 3, Paint()..color = Colors.white);
        break;

      case 'aurora_ribbon':
        for (var band = 0; band < 3; band++) {
          final path = Path();
          for (var i = 0; i <= 40; i++) {
            final x = size.width * i / 40;
            final y = cy +
                math.sin(
                      i * .38 + t * math.pi * 2 * config.speed + band,
                    ) *
                    size.height *
                    (.24 + band * .035) +
                (band - 1) * 4;
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..color = config.colors[band % config.colors.length]
                  .withValues(alpha: .42)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        break;
      case 'laser_sweep':
        final x = (t * config.speed % 1.0) * size.width;
        final sweepRect = Rect.fromLTWH(x - 20, 0, 40, size.height);
        canvas.drawRect(
          Rect.fromLTWH(x - 4, 0, 8, size.height),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.transparent,
                config.colors.first.withValues(alpha: .75),
                Colors.transparent,
              ],
            ).createShader(sweepRect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = config.colors.last.withValues(alpha: .7)
            ..strokeWidth = 1.2,
        );
        break;
      case 'hologram_scan':
        final y = (t * config.speed % 1.0) * size.height;
        final p = Paint()
          ..color = config.colors.first.withValues(alpha: .36)
          ..strokeWidth = 1.0;
        for (var i = 0; i < 7; i++) {
          final lineY = (i * size.height / 7 + y) % size.height;
          canvas.drawLine(
            Offset(0, lineY),
            Offset(size.width, lineY),
            p,
          );
        }
        canvas.drawRect(
          rect.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = config.colors.last.withValues(alpha: .45),
        );
        break;
      case 'galaxy_swirl':
        for (var arm = 0; arm < 3; arm++) {
          final path = Path();
          for (var i = 0; i < 65; i++) {
            final u = i / 64;
            final a = u * math.pi * 4.2 +
                t * math.pi * 2 * config.speed +
                arm * 2.094;
            final r = base * (.05 + u * .78);
            final o = Offset(
              cx + math.cos(a) * r,
              cy + math.sin(a) * r * .62,
            );
            if (i == 0) {
              path.moveTo(o.dx, o.dy);
            } else {
              path.lineTo(o.dx, o.dy);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 + arm * .35
              ..color = config.colors[arm % config.colors.length]
                  .withValues(alpha: .55),
          );
        }
        break;
      case 'orbiting_planets':
        final rings = <double>[.7, .52, .34];
        for (var j = 0; j < rings.length; j++) {
          final a = t * math.pi * 2 * config.speed * (j.isEven ? 1 : -1) + j;
          final r = base * rings[j];
          final o = Offset(
            cx + math.cos(a) * r,
            cy + math.sin(a) * r * .7,
          );
          final ringColor = config.colors[j % config.colors.length];
          canvas.drawCircle(
            o,
            2.5 + j,
            Paint()..color = ringColor,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: r * 2,
              height: r * 1.4,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8
              ..color = ringColor.withValues(alpha: .3),
          );
        }
        break;
      case 'electric_storm':
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        for (var b = 0; b < 7; b++) {
          final path = Path()..moveTo(cx, cy);
          for (var s = 0; s < 9; s++) {
            final a = s / 8 * math.pi * 2 + b * .7 + t * 10;
            final rr = base * (.15 + s / 18) + math.sin(t * 30 + b + s) * 3;
            final o = Offset(
              cx + math.cos(a) * rr,
              cy + math.sin(a) * rr,
            );
            path.lineTo(o.dx, o.dy);
          }
          final alpha = .18 + .08 * math.sin(t * 20 + b);
          canvas.drawPath(
            path,
            p..color = config.colors[b % config.colors.length]
                .withValues(alpha: alpha),
          );
        }
        break;
      case 'crystal_shards':
        for (var i = 0; i < config.particleCount; i++) {
          final a = t * math.pi * 2 * config.speed + i * .73;
          final r = base * (.35 + .45 * ((i * 31) % 100) / 100);
          final o = Offset(
            cx + math.cos(a) * r,
            cy + math.sin(a) * r * .8,
          );
          final shardSize = 2.5 + (i % 4) * .7;
          final path = Path()
            ..moveTo(o.dx, o.dy - shardSize)
            ..lineTo(o.dx + shardSize, o.dy)
            ..lineTo(o.dx, o.dy + shardSize)
            ..lineTo(o.dx - shardSize, o.dy)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: .65),
          );
        }
        break;
      case 'starfield':
        for (var i = 0; i < config.particleCount; i++) {
          final x = ((i * 83.0) % 97) / 97 * size.width;
          final phase = (t * config.speed + i * .17) % 1;
          final y = (i * 47.0 + phase * size.height) % size.height;
          final starSize = .6 + (i % 4) * .7;
          canvas.drawCircle(
            Offset(x, y),
            starSize,
            Paint()
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: .35 + .45 * math.sin(phase * math.pi)),
          );
        }
        break;
      case 'arcane_portal':
        for (var r = 0; r < 3; r++) {
          final radius = base * (.28 + r * .16);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = config.colors[r % config.colors.length]
                .withValues(alpha: .5);
          canvas.drawCircle(Offset(cx, cy), radius, paint);
          for (var k = 0; k < 6; k++) {
            final a = t * math.pi * 2 * config.speed *
                    (r.isEven ? 1 : -1) +
                k * math.pi / 3;
            final o = Offset(
              cx + math.cos(a) * radius,
              cy + math.sin(a) * radius,
            );
            canvas.drawCircle(o, 1.8, paint);
          }
        }
        break;
      case 'celestial_wings':
        for (var side = -1; side <= 1; side += 2) {
          final path = Path()
            ..moveTo(cx, cy + base * .25);
          for (var i = 0; i < 14; i++) {
            final u = i / 13;
            final x = cx + side * (u * base * .72);
            final y = cy +
                math.sin(u * math.pi) * base * .32 -
                math.sin(t * math.pi * 2 * config.speed + u * 4) * 4;
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = config.colors[(side + 1) % config.colors.length]
                  .withValues(alpha: .5),
          );
        }
        break;
      case 'butterfly_swarm':
        for (var i = 0; i < config.particleCount; i++) {
          final phase = (t * config.speed + i * .071) % 1;
          final x = size.width *
              (.1 + .8 * ((math.sin(i * 9.2 + phase * 5) + 1) / 2));
          final y = size.height *
              (.15 + .7 * ((math.sin(i * 3.1 + phase * 7) + 1) / 2));
          final flap = math.cos(phase * math.pi * 8);
          const s = 2.2;
          final p = Paint()
            ..color = config.colors[i % config.colors.length]
                .withValues(alpha: .35 + .35 * flap.abs());
          canvas.drawCircle(Offset(x - s * flap, y), s, p);
          canvas.drawCircle(Offset(x + s * flap, y), s, p);
        }
        break;
      case 'autumn_leaves':
        for (var i = 0; i < config.particleCount; i++) {
          final ph = (t * config.speed * (.7 + (i % 5) / 5) + i * .07) % 1;
          final x = (i * 53 + math.sin(ph * 10 + i) * 12) % size.width;
          final y = size.height * (1 - ph);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(ph * math.pi * 4 + i);
          final p = Paint()
            ..color = config.colors[i % config.colors.length]
                .withValues(alpha: .6);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 6,
              height: 9,
            ),
            p,
          );
          canvas.restore();
        }
        break;
      case 'ember_rain':
        for (var i = 0; i < config.particleCount; i++) {
          final ph = (t * config.speed + i * .061) % 1;
          final x = (i * 41 + math.sin(ph * 8 + i) * 8) % size.width;
          final y = size.height * (1 - ph);
          final len = 8 + 4 * math.sin(i);
          final alpha =
              (math.sin(ph * math.pi) * .8).clamp(0, 1).toDouble();
          canvas.drawLine(
            Offset(x, y),
            Offset(x + 2, y + len),
            Paint()
              ..strokeWidth = 1.2
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: alpha),
          );
        }
        break;
      case 'lava_flow':
        for (var i = 0; i < 6; i++) {
          final path = Path();
          for (var s = 0; s <= 24; s++) {
            final u = s / 24;
            final x = u * size.width;
            final y = cy +
                math.sin(u * 6 + t * math.pi * 2 * config.speed + i) * 6 +
                i * 3;
            if (s == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: .42),
          );
        }
        break;
      case 'poison_bubbles':
        for (var i = 0; i < config.particleCount; i++) {
          final ph =
              (t * config.speed * (.6 + (i % 4) * .1) + i * .07) % 1;
          final x = (i * 47 + math.sin(ph * 9 + i) * 14) % size.width;
          final y = size.height * (1 - ph);
          canvas.drawCircle(
            Offset(x, y),
            2 + i % 4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: .5),
          );
          canvas.drawCircle(
            Offset(x + 1, y - 1),
            .7,
            Paint()..color = Colors.white.withValues(alpha: .35),
          );
        }
        break;
      case 'moon_dust':
        final rr = base * (.4 + .28 * math.sin(t * math.pi));
        for (var i = 0; i < config.particleCount; i++) {
          final a = i * .67 + t * math.pi * 2 * config.speed;
          final r = rr * (.55 + .45 * ((i * 17) % 100) / 100);
          canvas.drawCircle(
            Offset(
              cx + math.cos(a) * r,
              cy + math.sin(a) * r * .55,
            ),
            1.3,
            Paint()
              ..color = config.colors[i % config.colors.length]
                  .withValues(alpha: .28 + .3 * ((i % 5) / 5)),
          );
        }
        break;
      case 'water_droplets':
        for(var i=0;i<config.particleCount;i++){final ph=(t*config.speed+i*.053)%1; final x=(i*61+math.sin(ph*12+i)*10)%size.width; final y=size.height*(1-ph); final s=1.5+(i%3); canvas.drawCircle(Offset(x,y),s,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=config.colors[i%config.colors.length].withValues(alpha:.5)); canvas.drawLine(Offset(x,y+s),Offset(x,y+s+3),Paint()..color=config.colors.first.withValues(alpha:.3)..strokeWidth=1);}
        break;
      case 'sonic_rings':
        for(var i=0;i<6;i++){final ph=(t*config.speed+i/6)%1; final rr=base*(.1+.8*ph); canvas.drawCircle(Offset(cx,cy),rr,Paint()..style=PaintingStyle.stroke..strokeWidth=1.1..color=config.colors[i%config.colors.length].withValues(alpha:(1-ph)*.45));}
        break;
      case 'golden_crown':
        final y=cy-base*.45+math.sin(t*math.pi*2*config.speed)*4; final path=Path()..moveTo(cx-base*.38,y+14)..lineTo(cx-base*.26,y-2)..lineTo(cx-base*.08,y+10)..lineTo(cx,y-8)..lineTo(cx+base*.08,y+10)..lineTo(cx+base*.26,y-2)..lineTo(cx+base*.38,y+14)..close(); canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=config.colors.first.withValues(alpha:.72));
        break;
      case 'royal_aura':
        for(var i=0;i<5;i++){final rr=base*(.42+i*.08+math.sin(t*math.pi*2*config.speed+i)*.015); canvas.drawCircle(Offset(cx,cy),rr,Paint()..style=PaintingStyle.stroke..strokeWidth=1.4..color=config.colors[i%config.colors.length].withValues(alpha:.16));}
        break;
      case 'vortex':
        for (var ring = 0; ring < 4; ring++) {
          final path = Path();
          final turns = 1.7 + ring * .32;
          const points = 90;
          for (var i = 0; i <= points; i++) {
            final u = i / points;
            final a = (u * math.pi * 2 * turns) +
                (t * math.pi * 2 * config.speed * (1 + ring * .08));
            final rr = base * (.18 + .2 * ring) + u * base * .46;
            final o =
                Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr * .78);
            if (i == 0) {
              path.moveTo(o.dx, o.dy);
            } else {
              path.lineTo(o.dx, o.dy);
            }
          }
          canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0 + ring * .45
                ..strokeCap = StrokeCap.round
                ..color = config.colors[ring % 3].withValues(
                    alpha: .28 + .12 * math.sin(t * math.pi * 2 + ring)));
        }
        for (var i = 0; i < config.particleCount; i++) {
          final a =
              (t * math.pi * 2 * config.speed * (1 + (i % 4) * .08)) + i * .93;
          final r = base * (.22 + .52 * ((i * 37) % 100) / 100);
          final o = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r * .78);
          final pulse = .6 + .4 * math.sin(t * math.pi * 4 + i);
          canvas.drawCircle(
              o,
              1.0 + 1.2 * pulse,
              Paint()
                ..color =
                    config.colors[i % 3].withValues(alpha: .45 + .35 * pulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
        }
        final core = .75 + .25 * math.sin(t * math.pi * 4);
        canvas.drawCircle(
            Offset(cx, cy),
            base * .15,
            Paint()
              ..color = config.colors.first.withValues(alpha: .10 * core)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        break;
      default:
        final pulse = .5 + .5 * math.sin(t * math.pi * 2);
        canvas.drawCircle(
            Offset(cx, cy),
            base * .65,
            Paint()
              ..color = config.colors.first.withValues(alpha: .12 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
  }

  void _paintVideoReferenceFrame(Canvas canvas, Size size, double t,
      VisualEffectConfig config, String key) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final short = math.min(size.width, size.height);
    final w = math.min(size.width * .92, short * 1.75);
    final h = math.max(18.0, math.min(size.height * .52, short * .72));
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    const variants = <String>[
      'pulse_glow','lightning','fire','flame','crossed_swords',
      'ice_crystals','orbiting_stars','meteor_shower','neon_rainbow','rotating_ring'
    ];
    final variant = variants.indexOf(key);
    final phase = (t * config.speed) % 1.0;
    final baseColor = config.colors.first.withValues(alpha: .72);
    final highlight = config.colors.length > 1
        ? config.colors[1].withValues(alpha: .86)
        : baseColor;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Identity plate: two nested passes reproduce the layered frame language.
    final radius = math.max(8.0, h * .22);
    final plate = RRect.fromRectAndRadius(rect.deflate(math.max(2, short * .022)),
        Radius.circular(radius));
    stroke..strokeWidth = math.max(1.0, short * .012)..color = baseColor;
    canvas.drawRRect(plate, stroke);
    stroke..strokeWidth = math.max(.7, short * .006)
      ..color = highlight.withValues(alpha: .46 + .20 * math.sin(phase * math.pi));
    canvas.drawRRect(plate.deflate(short * .018), stroke);

    // Distinct silhouettes: feathered, crystal, flame and crown-like variants.
    final span = rect.width * (.17 + (variant % 4) * .035);
    final top = rect.top + rect.height * (.18 + .035 * math.sin(phase * math.pi * 2));
    final bottom = rect.bottom - rect.height * .13;
    Path buildWing(bool mirror) {
      final p = Path();
      final sx = mirror ? rect.right - rect.width * .05 : rect.left + rect.width * .05;
      final sign = mirror ? -1.0 : 1.0;
      p.moveTo(sx + sign * span, bottom);
      p.cubicTo(sx + sign * span * .10, bottom,
          sx - sign * span * .02, top + h * .18,
          sx + sign * span * .18, top);
      final count = 4 + (variant % 4);
      for (var i = 0; i <= count; i++) {
        final f = i / count;
        final x = sx + sign * span * (.18 + f * .82);
        final y = top + math.sin(f * math.pi) * h * (.14 + (variant % 3) * .025);
        p.lineTo(x, y);
        p.lineTo(x - sign * span * .075, y + h * .07);
      }
      p.close();
      return p;
    }
    stroke..strokeWidth = math.max(1.1, short * (.007 + variant * .0007))
      ..color = highlight.withValues(alpha: .60 + .18 * math.sin(phase * math.pi));
    canvas.drawPath(buildWing(false), stroke);
    canvas.drawPath(buildWing(true), stroke);

    final crestY = rect.top + rect.height * .17;
    final crestR = short * (.035 + (variant % 3) * .009);
    final glow = Paint()
      ..color = highlight.withValues(alpha: .68 + .22 * (1 - phase))
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, short * .008);
    if (variant % 4 == 0) {
      final crown = Path()
        ..moveTo(cx - crestR * 1.6, crestY + crestR)
        ..lineTo(cx - crestR * .9, crestY - crestR)
        ..lineTo(cx, crestY + crestR * .15)
        ..lineTo(cx + crestR * .9, crestY - crestR)
        ..lineTo(cx + crestR * 1.6, crestY + crestR)
        ..close();
      canvas.drawPath(crown, glow);
    } else if (variant % 4 == 1) {
      canvas.save();
      canvas.translate(cx, crestY);
      canvas.rotate((phase - .5) * .55);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: crestR * 2.5, height: crestR),
          Radius.circular(crestR * .35)), glow);
      canvas.restore();
    } else {
      canvas.drawCircle(Offset(cx, crestY), crestR * (1 + .18 * math.sin(phase * math.pi * 2)), glow);
      stroke..strokeWidth = short * .004..color = baseColor.withValues(alpha: .62);
      final rays = 6 + variant;
      for (var i = 0; i < rays; i++) {
        final a = i * math.pi * 2 / rays + phase * (.5 + variant * .08);
        final r1 = crestR * 1.35;
        final r2 = crestR * (2.0 + .25 * math.sin(phase * math.pi * 2 + i));
        canvas.drawLine(Offset(cx + math.cos(a) * r1, crestY + math.sin(a) * r1),
            Offset(cx + math.cos(a) * r2, crestY + math.sin(a) * r2), stroke);
      }
    }

    // Timed directional shimmer plus sparse edge particles.
    final shimmerX = rect.left + rect.width * ((phase + variant * .07) % 1.0);
    final shimmerRect = Rect.fromLTWH(shimmerX, rect.top, rect.width * .08, rect.height);
    final sp = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        highlight.withValues(alpha: .26 + .18 * (1 - phase)),
        Colors.transparent,
      ]).createShader(shimmerRect);
    canvas.drawRect(shimmerRect, sp);
    for (var i = 0; i < 3 + variant % 4; i++) {
      final a = phase * math.pi * 2 * (variant.isEven ? 1 : -1) + i * math.pi / 3;
      final edge = Offset(cx + math.cos(a) * rect.width * .46,
          cy + math.sin(a) * rect.height * .30);
      canvas.drawCircle(edge, short * (.005 + .0015 * (i % 3)), glow);
    }
  }

  @override
  bool shouldRepaint(covariant VisualEffectPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.config.effectKey != config.effectKey;
}
