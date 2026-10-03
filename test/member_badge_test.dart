import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/member_badges/domain/member_badge.dart';

void main() {
  test('member badge maps server catalog fields', () {
    final badge = MemberBadge.fromMap({
      'id': '1',
      'badge_key': 'badge_lion',
      'name_ar': 'أسد',
      'category': 'animal',
      'description': 'شارة اختبار',
      'asset_url': 'https://example.test/badges/v1/lion.gif',
      'asset_path': 'badges/v1/lion.gif',
      'mime_type': 'image/gif',
      'file_size_bytes': 120000,
      'width': 48,
      'height': 32,
      'is_active': true,
    });
    expect(badge.badgeKey, 'badge_lion');
    expect(badge.assetPath, 'badges/v1/lion.gif');
    expect(badge.fileSizeBytes, 120000);
    expect(badge.active, isTrue);
  });
}
