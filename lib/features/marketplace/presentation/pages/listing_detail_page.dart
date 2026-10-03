import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/listing_entity.dart';
import '../providers/marketplace_provider.dart';

class ListingDetailPage extends ConsumerWidget {
  final ListingEntity listing;
  const ListingDetailPage({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(profileByIdProvider(listing.sellerUid));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final controllerState = ref.watch(marketplaceControllerProvider);
    final isMine = myUid == listing.sellerUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.title),
        actions: [
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('حذف الإعلان'),
                    content: const Text('هل تريد حذف هذا الإعلان؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (confirmed == true && myUid != null) {
                  await ref
                      .read(marketplaceControllerProvider.notifier)
                      .deleteListing(
                        listingId: listing.id,
                        sellerUid: listing.sellerUid,
                        requestedByUid: myUid,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listing.imageUrls.isNotEmpty)
              Image.network(listing.imageUrls.first,
                  height: 260, width: double.infinity, fit: BoxFit.cover)
            else
              Container(
                height: 200,
                color: AppColors.surfaceHighlight,
                child: const Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.textMuted),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(listing.price.formatted,
                      style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                      'البائع: ${sellerAsync.valueOrNull?.displayName ?? '...'}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Text(listing.description),
                  const SizedBox(height: 28),
                  if (!isMine)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: Text(controllerState.isLoading
                            ? 'جارٍ الشراء...'
                            : 'شراء الآن (دفع فعلي من محفظتك)'),
                        onPressed: controllerState.isLoading || myUid == null
                            ? null
                            : () async {
                                final success = await ref
                                    .read(
                                        marketplaceControllerProvider.notifier)
                                    .placeOrder(
                                        listing: listing, buyerUid: myUid);

                                if (!context.mounted) return;

                                final state =
                                    ref.read(marketplaceControllerProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'تم الشراء بنجاح! خُصم المبلغ من محفظتك'
                                          : state.error?.toString() ??
                                              'فشلت عملية الشراء',
                                    ),
                                  ),
                                );
                                if (success) Navigator.of(context).pop();
                              },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
