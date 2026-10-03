import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/gamification/domain/entities/name_animation.dart';

void main() {
  test('40 bundled legacy animal contracts remain parseable as reference payloads', () {
    final dir = Directory('assets/name_animations/animals');
    expect(dir.existsSync(), isTrue);
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, hasLength(40));
    // These are retained legacy design references. Runtime animals now require GIF Storage assets.

    for (final file in files) {
      final raw = jsonDecode(file.readAsStringSync());
      expect(raw, isA<Map>());
      final json = Map<String, dynamic>.from(raw as Map);
      expect(json['layers'], isA<List>());
      expect(json['meta'], isA<Map>());
      final meta = Map<String, dynamic>.from(json['meta'] as Map);
      expect(meta['transparent'], true);
      expect((json['fr'] as num).toDouble(), greaterThan(0));
      expect((json['fr'] as num).toDouble(), lessThanOrEqualTo(30));
      final duration = (((json['op'] as num).toDouble() - (json['ip'] as num).toDouble()) / (json['fr'] as num).toDouble()) * 1000;
      expect(duration, inInclusiveRange(1200, 2400));
    }
  });

  test('NameAnimation preserves the server-side GIF contract', () {
    final animation = NameAnimation.fromMap(const <String, dynamic>{
      'effect_key': 'fox_animal',
      'name_ar': 'ثعلب',
      'category': 'land',
      'asset_path': null,
      'storage_path': 'catalog/fox_animal.gif',
      'asset_url': 'https://example.invalid/storage/v1/object/public/name-animations/catalog/fox_animal.gif',
      'animation_type': 'gif',
      'fps': 24,
      'duration_ms': 1800,
      'max_width': 44,
      'max_height': 30,
      'transparent': true,
      'loop': true,
      'is_active': true,
      'source_width': 128,
      'source_height': 96,
      'frame_count': 48,
      'render_effect': 'float_glow',
    });
    expect(animation.key, 'fox_animal');
    expect(animation.storagePath, 'catalog/fox_animal.gif');
    expect(animation.assetUrl, contains('/name-animations/catalog/fox_animal.gif'));
    expect(animation.animationType, 'gif');
    expect(animation.maxWidth, 44);
    expect(animation.maxHeight, 30);
  });
}
