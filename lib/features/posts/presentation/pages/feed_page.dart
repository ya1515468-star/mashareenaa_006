import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/entities/content_categories.dart';
import '../providers/post_provider.dart';
import '../widgets/post_card.dart';
import 'create_post_page.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(title: const Text('الأقسام والمنشورات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    CreatePostPage(initialCategory: _selectedCategory)),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _CategoryChip(
                  label: 'الكل',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ...ContentCategories.all.map(
                  (c) => _CategoryChip(
                    label: ContentCategories.labelOf(c),
                    selected: _selectedCategory == c,
                    onTap: () => setState(() => _selectedCategory = c),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: feedAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const ErrorView(message: 'تعذر تحميل المنشورات الآن. تحقق من الاتصال ثم أعد المحاولة.'),
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(
                    child: Text('لا توجد منشورات بعد',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => PostCard(post: posts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
        labelStyle: TextStyle(
            color: selected ? AppColors.background : AppColors.textPrimary),
      ),
    );
  }
}
