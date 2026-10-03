import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/member_badge_repository.dart';

final memberBadgeRepositoryProvider = Provider<MemberBadgeRepository>(
  (_) => MemberBadgeRepository(),
);

final memberBadgeForUserProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
  return ref.watch(memberBadgeRepositoryProvider).getForUser(userId);
});
