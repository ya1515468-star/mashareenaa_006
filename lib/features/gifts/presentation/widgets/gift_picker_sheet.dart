import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/gift_entity.dart';

/// المصدر الوحيد لكتالوج الهدايا — يقرأ من public.gift_catalog حصرًا.
/// لا نسخة ثابتة بديلة: أي تغيير سعر يفعله المالك على الخادم يظهر هنا
/// فورًا عند إعادة فتح القائمة، بلا حاجة لإصدار تطبيق جديد.
final giftCatalogProvider = FutureProvider.autoDispose<List<GiftEntity>>((ref) async {
  final rows = await Supabase.instance.client
      .from('gift_catalog')
      .select('id,emoji,name_ar,price_points,tier')
      .eq('enabled', true)
      .order('price_points');
  return (rows as List)
      .map((r) => GiftEntity.fromRow(Map<String, dynamic>.from(r as Map)))
      .toList();
});

const _tierLabelsAr = {
  GiftTier.basic: 'هدايا أساسية',
  GiftTier.small: 'هدايا يومية',
  GiftTier.medium: 'هدايا مميزة',
  GiftTier.big: 'هدايا كبيرة',
  GiftTier.epic: 'هدايا أسطورية',
  GiftTier.legendary: 'هدايا ملكية',
};

class GiftPickerSheet extends ConsumerWidget {
  final ValueChanged<GiftEntity> onSelect;
  const GiftPickerSheet({super.key, required this.onSelect});

  static Future<void> show(
      BuildContext context, ValueChanged<GiftEntity> onSelect) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPickerSheet(onSelect: onSelect),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final giftsAsync = ref.watch(giftCatalogProvider);
    final byTier = <GiftTier, List<GiftEntity>>{};
    for (final gift in giftsAsync.valueOrNull ?? const <GiftEntity>[]) {
      byTier.putIfAbsent(gift.tier, () => []).add(gift);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: p.divider, borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('أرسل هدية 🎁',
                    style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Expanded(
                child: giftsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('تعذّر تحميل قائمة الهدايا: $e',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textSecondary, fontSize: 12)),
                    ),
                  ),
                  data: (_) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final tier in GiftTier.values)
                      if (byTier[tier]?.isNotEmpty == true) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 10, bottom: 6, right: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _tierLabelsAr[tier]!,
                                style: TextStyle(
                                    color: p.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.85,
                          children: byTier[tier]!.map((gift) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).pop();
                                onSelect(gift);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: p.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.divider),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(gift.emoji,
                                        style: const TextStyle(fontSize: 26)),
                                    const SizedBox(height: 2),
                                    Text(
                                      gift.nameAr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: p.textSecondary),
                                    ),
                                    Text(
                                      '${gift.pricePoints}⭐',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: p.accent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
