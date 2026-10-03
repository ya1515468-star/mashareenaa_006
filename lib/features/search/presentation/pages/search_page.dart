import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  String _query = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textAlign: TextAlign.right,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ابحث عن مستخدمين أو منشورات...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'مستخدمون'), Tab(text: 'منشورات')],
        ),
      ),
      body: _query.isEmpty
          ? const Center(
              child: Text('اكتب للبحث',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _ProfileResults(query: _query),
                _PostResults(query: _query),
              ],
            ),
    );
  }
}

class _ProfileResults extends ConsumerWidget {
  final String query;
  const _ProfileResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(profileSearchResultsProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (profiles) {
        if (profiles.isEmpty) {
          return const Center(
            child: Text('لا نتائج',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final profile = profiles[index];
            return ListTile(
              leading: ProfileAvatar(
                  avatarUrl: profile.avatarUrl,
                  displayName: profile.displayName,
                  radius: 20,
                  frameKey: profile.avatarFrameKey),
              title: ServerUsernameDisplay(uid: profile.uid, fallbackName: profile.displayName, fallbackFontSize: 16),
              subtitle:
                  profile.profession != null ? Text(profile.profession!) : null,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => UserProfileViewPage(uid: profile.uid)),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PostResults extends ConsumerWidget {
  final String query;
  const _PostResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(postSearchResultsProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Text('لا نتائج',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}
