import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/profile/presentation/widgets/name_template.dart';

void main() {
  test('name template registry holds only the 9 distinct designs', () {
    // 41 نسخة مكرّرة بصريًا حُذفت نهائيًا؛ يبقى 9 تصاميم مميّزة.
    expect(NameTemplateRegistry.all, hasLength(9));
    expect(NameTemplateRegistry.all.map((e) => e.key).toSet(), hasLength(9));
    expect(NameTemplateRegistry.get('name_template_01'), isNotNull);
    expect(NameTemplateRegistry.get('name_template_12'), isNotNull);
    expect(NameTemplateRegistry.get('name_template_02'), isNull);
    expect(NameTemplateRegistry.get('visualfx_fire'), isNull);
    expect(NameTemplateRegistry.get('username_effect_01'), isNull);
    // كل تعريف في السجل يجب أن يقابله ملف صورة موجود فعلًا.
    for (final t in NameTemplateRegistry.all) {
      expect(File(t.asset).existsSync(), isTrue, reason: t.asset);
    }
  });
}
