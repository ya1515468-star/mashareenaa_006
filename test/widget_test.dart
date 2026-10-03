import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/admin/presentation/pages/admin_chat_badges_tab.dart';
import 'package:mashareena/features/rbac/presentation/widgets/server_chat_badge_above_name.dart';

void main() {
  test('member badge admin and renderer widgets are constructible', () {
    expect(const AdminChatBadgesTab(), isA<AdminChatBadgesTab>());
    expect(
      const ServerChatBadgeAboveName(
        uid: '00000000-0000-0000-0000-000000000000',
      ),
      isA<ServerChatBadgeAboveName>(),
    );
  });
}
