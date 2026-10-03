import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../providers/friend_provider.dart';

class FriendsListPage extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const FriendsListPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends ConsumerState<FriendsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأصدقاء'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'أصدقائي'), Tab(text: 'طلبات واردة')],
        ),
      ),
      body: myUid == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(myUid: myUid),
                _PendingRequestsTab(myUid: myUid),
              ],
            ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  final String myUid;
  const _FriendsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider(myUid));

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Text('لا يوجد أصدقاء بعد',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final otherUid = friend.otherParticipant(myUid);
            return Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileByIdProvider(otherUid));
                final profile = profileAsync.valueOrNull;
                return ListTile(
                  leading: ProfileAvatar(
                    avatarUrl: profile?.avatarUrl,
                    displayName: profile?.displayName ?? '',
                    radius: 20,
                    frameKey: profile?.avatarFrameKey,
                  ),
                  title: profile == null ? const Text('...') : ServerUsernameDisplay(uid: otherUid, fallbackName: profile.displayName, fallbackFontSize: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => UserProfileViewPage(uid: otherUid)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PendingRequestsTab extends ConsumerWidget {
  final String myUid;
  const _PendingRequestsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingFriendRequestsProvider(myUid));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Text('لا توجد طلبات واردة',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Consumer(
              builder: (context, ref, _) {
                final profileAsync =
                    ref.watch(profileByIdProvider(request.fromUid));
                final profile = profileAsync.valueOrNull;
                return ListTile(
                  leading: ProfileAvatar(
                    avatarUrl: profile?.avatarUrl,
                    displayName: profile?.displayName ?? '',
                    radius: 20,
                    frameKey: profile?.avatarFrameKey,
                  ),
                  title: profile == null ? const Text('...') : ServerUsernameDisplay(uid: request.fromUid, fallbackName: profile.displayName, fallbackFontSize: 16),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle,
                            color: AppColors.success),
                        onPressed: () => ref
                            .read(friendControllerProvider.notifier)
                            .respond(request, accept: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppColors.error),
                        onPressed: () => ref
                            .read(friendControllerProvider.notifier)
                            .respond(request, accept: false),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
