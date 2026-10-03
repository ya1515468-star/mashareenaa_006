import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../store/domain/entities/store_item_entity.dart';
import '../../../store/domain/usecases/store_usecases.dart';
import '../../../store/presentation/store_features_tab.dart';

/// إدارة كتالوج المتجر (300 عنصر) — DRAGON يعدّل سعر أو يعطّل أي
/// عنصر مباشرة. فلترة حسب الفئة + بحث بالاسم لتسهيل التنقّل بين
/// هذا العدد الكبير من العناصر.
class AdminStoreTab extends ConsumerStatefulWidget {
  const AdminStoreTab({super.key});

  @override
  ConsumerState<AdminStoreTab> createState() => _AdminStoreTabState();
}

class _AdminStoreTabState extends ConsumerState<AdminStoreTab> {
  StoreItemCategory? _filterCategory;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(storeCatalogProvider);
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم...', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label:
                            const Text('الكل', style: TextStyle(fontSize: 11)),
                        selected: _filterCategory == null,
                        onSelected: (_) =>
                            setState(() => _filterCategory = null),
                      ),
                    ),
                    for (final cat in StoreItemCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(cat.labelAr,
                              style: const TextStyle(fontSize: 11)),
                          selected: _filterCategory == cat,
                          onSelected: (_) =>
                              setState(() => _filterCategory = cat),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalogAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (catalog) {
              final filtered = catalog.where((i) {
                if (_filterCategory != null && i.category != _filterCategory) {
                  return false;
                }
                if (_search.isNotEmpty && !i.nameAr.contains(_search)) {
                  return false;
                }
                return true;
              }).toList();

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => _EditableItemRow(
                  item: filtered[index],
                  myUid: myUid,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditableItemRow extends ConsumerStatefulWidget {
  final StoreItemEntity item;
  final String? myUid;
  const _EditableItemRow({required this.item, required this.myUid});

  @override
  ConsumerState<_EditableItemRow> createState() => _EditableItemRowState();
}

class _EditableItemRowState extends ConsumerState<_EditableItemRow> {
  late final TextEditingController _priceController = TextEditingController(
    text: widget.item.pricePoints.toString(),
  );

  late final TextEditingController _gemsPriceController = TextEditingController(
    text: widget.item.priceGems?.toString() ?? '',
  );

  late bool _enabled = widget.item.enabled;

  bool _saving = false;

  @override
  void dispose() {
    _priceController.dispose();
    _gemsPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.myUid == null) return;

    final pricePoints = int.tryParse(_priceController.text.trim());

    final priceGems = int.tryParse(_gemsPriceController.text.trim());

    if (pricePoints == null ||
        priceGems == null ||
        pricePoints < 0 ||
        priceGems < 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب إدخال سعر صالح بالنقاط وسعر صالح بالجواهر.',
          ),
        ),
      );

      return;
    }

    setState(() => _saving = true);

    final result = await sl<UpdateStoreItemUseCase>().call(
      itemId: widget.item.id,
      pricePoints: pricePoints,
      priceGems: priceGems,
      enabled: _enabled,
      requestedByUid: widget.myUid!,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isRight() ? 'تم الحفظ ✓' : 'فشل: صلاحية غير كافية',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: widget.item.colors.first),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.item.nameAr,
                style: TextStyle(fontSize: 12.5, color: p.textPrimary)),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  onPressed: _save),
        ],
      ),
    );
  }
}
