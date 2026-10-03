import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/profile/presentation/widgets/name_template.dart';

void main() {
  test('name template registry is exactly 50 and independent', () {
    expect(NameTemplateRegistry.all, hasLength(50));
    expect(NameTemplateRegistry.all.map((e) => e.key).toSet(), hasLength(50));
    expect(NameTemplateRegistry.get('name_template_01'), isNotNull);
    expect(NameTemplateRegistry.get('visualfx_fire'), isNull);
    expect(NameTemplateRegistry.get('username_effect_01'), isNull);
  });
}
