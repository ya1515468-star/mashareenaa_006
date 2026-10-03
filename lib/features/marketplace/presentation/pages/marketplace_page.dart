import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/entities/listing_entity.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/listing_card.dart';
import 'create_listing_page.dart';
import 'my_orders_page.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(
        title: const Text('السوق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'طلباتي',
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyOrdersPage()));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    CreateListingPage(initialCategory: _selectedCategory)),
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
                ...MarketplaceCategories.all.map(
                  (c) => _CategoryChip(
                    label: MarketplaceCategories.labelOf(c),
                    selected: _selectedCategory == c,
                    onTap: () => setState(() => _selectedCategory = c),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: listingsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const ErrorView(message: 'تعذر تحميل السوق الآن. تحقق من الاتصال ثم أعد المحاولة.'),
              data: (listings) {
                if (listings.isEmpty) {
                  return const Center(
                    child: Text('لا توجد إعلانات بعد',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (context, index) =>
                      ListingCard(listing: listings[index]),
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
