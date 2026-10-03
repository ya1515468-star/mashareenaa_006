import '../domain/usecases/store_usecases.dart';
// ignore_for_file: prefer_const_declarations

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../gamification/presentation/pages/points_store_page.dart'
    show StoreFeatureType;
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/entities/store_item_entity.dart';
import '../domain/equipped_items_service.dart';
import '../domain/repositories/store_repository.dart';
import 'widgets/store_effect_engines.dart';
import 'widgets/store_preview.dart';

final storeCatalogProvider = StreamProvider<List<StoreItemEntity>>((ref) {
  return sl<StoreRepository>().watchCatalog();
});

final storeOwnedItemsProvider =
    StreamProvider.family<List<String>, String>((ref, uid) {
  return sl<StoreRepository>().watchOwnedItemIds(uid);
});

/// ═══════════════════════════════════════════════════════════════
///  قسم المتجر — مع توهج  خفيف مشترك
///
///  • المعاينة الحية الكاملة تُفتح فقط في Dialog
///  • 100 ميزة لكل نوع (glow / frame / background) = 300+
///  • ValueNotifier واحد للنبض = صفر تجميد
///  • RepaintBoundary حول كل بطاقة
/// ═══════════════════════════════════════════════════════════════
class StoreFeaturesTab extends ConsumerStatefulWidget {
  final StoreFeatureType? featureType;
  final StoreProductDomain? domain;

  const StoreFeaturesTab({
    super.key,
    this.featureType,
    this.domain,
  });

  @override
  ConsumerState<StoreFeaturesTab> createState() => _StoreFeaturesTabState();
}

class _StoreFeaturesTabState extends ConsumerState<StoreFeaturesTab> {
  String _selectedRarity = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // نبضة مشتركة لجميع البطاقات (صفر تجميد)
  late final ValueNotifier<double> _pulseNotifier;

  @override
  void initState() {
    super.initState();
    _pulseNotifier = ValueNotifier<double>(0.0);
    _startPulse();
  }

  void _startPulse() {
    void tick() async {
      if (!mounted) return;
      final t = DateTime.now().millisecondsSinceEpoch % 3000 / 3000.0;
      _pulseNotifier.value = (math.sin(t * 2 * math.pi) + 1) / 2;
      await Future.delayed(const Duration(milliseconds: 50));
      tick();
    }

    tick();
  }

  @override
  void dispose() {
    _pulseNotifier.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(storeCatalogProvider);
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final ownedAsync =
        myUid == null ? null : ref.watch(storeOwnedItemsProvider(myUid));

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذّر تحميل المتجر: $e')),
      data: (catalog) {
        final type = widget.featureType ?? StoreFeatureType.glow;
        final items = _filterAndGenerate(
          catalog,
          type,
          domain: widget.domain,
        );

        return Column(
          children: [
            _SearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            _RarityFilter(
              selected: _selectedRarity,
              onChanged: (v) => setState(() => _selectedRarity = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${items.length} عنصر',
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyState()
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.18,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isOwned =
                            ownedAsync?.valueOrNull?.contains(item.id) ?? false;
                        return _StoreItemCard(
                          item: item,
                          owned: isOwned,
                          uid: myUid,
                          pulse: _pulseNotifier,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// فلترة العناصر حسب النوع + الندرة + البحث
  List<StoreItemEntity> _filterAndGenerate(
    List<StoreItemEntity> catalog,
    StoreFeatureType type, {
    StoreProductDomain? domain,
  }) {
    final filtered = catalog.where((item) {
      if (!item.enabled) {
        return false;
      }

      if (domain != null && item.domain != domain) {
        return false;
      }

      final categoryMatches = switch (type) {
        StoreFeatureType.glow =>
          item.category == StoreItemCategory.usernameGlow,
        StoreFeatureType.frame =>
          item.category == StoreItemCategory.avatarFrame,
        StoreFeatureType.background =>
          item.category == StoreItemCategory.animatedBackground ||
              item.category == StoreItemCategory.usernameBackground,
      };

      final searchMatches = _searchQuery.isEmpty ||
          item.nameAr.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );

      final rarityMatches =
          _selectedRarity == 'all' || _getRarityKey(item) == _selectedRarity;

      return categoryMatches && searchMatches && rarityMatches;
    }).toList(growable: false);
    return filtered;
  }

  String _getRarityKey(StoreItemEntity item) {
    final rarity = item.rarity.trim().toLowerCase();

    if (rarity == 'mythic') return 'mythic';
    if (rarity == 'legendary') return 'legendary';
    if (rarity == 'epic') return 'epic';
    if (rarity == 'rare') return 'rare';

    return 'common';
  }
}

// ═══════════════════════════════════════════════════════════════
//  شريط البحث
// ═══════════════════════════════════════════════════════════════
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: p.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: '🔍 ابحث في المتجر...',
          hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: p.textSecondary, size: 18),
          filled: true,
          fillColor: p.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  فلتر الندرة
// ═══════════════════════════════════════════════════════════════
class _RarityFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RarityFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = <Map<String, String>>[
      {'id': 'all', 'label': 'الكل'},
      {'id': 'common', 'label': 'عادي'},
      {'id': 'rare', 'label': 'نادر'},
      {'id': 'epic', 'label': 'ملحمي'},
      {'id': 'legendary', 'label': 'أسطوري'},
      {'id': 'mythic', 'label': 'خرافي'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final it = items[index];
          final isSelected = it['id'] == selected;
          return GestureDetector(
            onTap: () => onChanged(it['id']!),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.palette.accent.withValues(alpha: 0.25)
                    : context.palette.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isSelected ? context.palette.accent : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                it['label']!,
                style: TextStyle(
                  color: isSelected
                      ? context.palette.accent
                      : context.palette.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  حالة فارغة
// ═══════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: context.palette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد عناصر',
            style: TextStyle(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  بطاقة العنصر — مع توهج  خفيف مشترك
// ═══════════════════════════════════════════════════════════════
class _StoreItemCard extends ConsumerStatefulWidget {
  final StoreItemEntity item;
  final bool owned;
  final String? uid;
  final ValueNotifier<double> pulse;

  const _StoreItemCard({
    required this.item,
    required this.owned,
    required this.uid,
    required this.pulse,
  });

  @override
  ConsumerState<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends ConsumerState<_StoreItemCard> {
  bool _isPressed = false;

  void _showPreview() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item.nameAr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 150,
                height: 150,
                child: widget.item.assetType == 'gif' &&
                        widget.item.assetUrl != null
                    ? ProductGifViewer(
                        assetPath: widget.item.assetUrl!,
                        productName: widget.item.nameAr)
                    : Center(child: _LiveEffectPreview(item: widget.item)),
              ),
              const SizedBox(height: 12),
              if (!widget.owned)
                ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: Text('${widget.item.pricePoints} ⭐'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _purchase();
                  },
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('تجهيز'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _equip();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase() async {
    if (widget.uid == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('سيتم شراء «${widget.item.nameAr}» من المتجر وحفظ الملكية على الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('شراء')),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;
    final result = await sl<PurchaseStoreItemUseCase>()
        .call(uid: widget.uid!, item: widget.item);
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم الشراء ✓'))),
    );
  }

  Future<void> _equip() async {
    if (widget.uid == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التجهيز'),
        content: Text('سيتم تجهيز «${widget.item.nameAr}» وحفظه على ملفك في الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تجهيز')),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;
    await EquippedItemsService.equip(
      uid: widget.uid!,
      category: widget.item.category,
      itemId: widget.item.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم التجهيز على ملفك الشخصي ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _showPreview,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: ValueListenableBuilder<double>(
            valueListenable: widget.pulse,
            builder: (context, pulse, child) {
              return CustomPaint(
                painter: _CardGlowPainter(
                  pulse: pulse,
                  baseColor: widget.item.colors.first,
                  pressed: _isPressed,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.divider),
                    gradient: LinearGradient(
                      colors: [
                        widget.item.colors.first.withValues(alpha: 0.35),
                        widget.item.colors.first.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniPreview(
                        item: widget.item,
                        pulse: pulse,
                      ),
                      Text(
                        widget.item.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      _ActionButton(
                        owned: widget.owned,
                        enabled: widget.uid != null,
                        price: widget.item.pricePoints,
                        rarityColor: widget.item.colors.first,
                        onPurchase: widget.owned ? _equip : _purchase,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  المعاينة المصغّرة داخل البطاقة
// ═══════════════════════════════════════════════════════════════
class _MiniPreview extends StatelessWidget {
  final StoreItemEntity item;
  final double pulse;

  const _MiniPreview({
    required this.item,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final asset = item.assetUrl;

    if (item.assetType == 'gif' && asset != null && asset.trim().isNotEmpty) {
      return SizedBox(
        width: 78,
        height: 78,
        child: RepaintBoundary(
          child: StoreGifPreview(
            assetPath: asset,
            alt: item.nameAr,
          ),
        ),
      );
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            item.colors.first.withValues(
              alpha: 0.70 + (pulse * 0.15),
            ),
            item.colors.first.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Icon(
        _iconFor(item.category),
        color: item.colors.first,
        size: 30,
      ),
    );
  }

  IconData _iconFor(StoreItemCategory c) {
    switch (c) {
      case StoreItemCategory.currency:
        return Icons.diamond;
      case StoreItemCategory.usernameGlow:
        return Icons.auto_awesome;
      case StoreItemCategory.avatarFrame:
        return Icons.crop_square;
      case StoreItemCategory.animatedBackground:
        return Icons.wallpaper;
      case StoreItemCategory.membership:
        return Icons.workspace_premium;
      case StoreItemCategory.usernameBackground:
        return Icons.text_fields;
      case StoreItemCategory.particleEffect:
        return Icons.bubble_chart;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  زر الإجراء (شراء / تجهيز)
// ═══════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final bool owned;
  final bool enabled;
  final int price;
  final Color rarityColor;
  final VoidCallback onPurchase;

  const _ActionButton({
    required this.owned,
    required this.enabled,
    required this.price,
    required this.rarityColor,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    if (owned) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: enabled ? onPurchase : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 4),
            side: const BorderSide(color: Colors.green),
          ),
          child: const Text(
            '✓ مُجهَّز',
            style: TextStyle(fontSize: 10, color: Colors.green),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPurchase : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: rarityColor,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        child: Text(
          '$price⭐',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  رسّام التوهج  للبطاقة (مُحسَّن — صفر تجميد)
// ═══════════════════════════════════════════════════════════════
class _CardGlowPainter extends CustomPainter {
  final double pulse;
  final Color baseColor;
  final bool pressed;

  _CardGlowPainter({
    required this.pulse,
    required this.baseColor,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final center = rect.center;
    final maxR = math.max(size.width, size.height);

    // هالة خلفية نابضة
    final halo = Paint()
      ..color = baseColor.withValues(alpha: 0.18 + 0.12 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, maxR * 0.55, halo);

    // إطار متوهّج عند الضغط
    if (pressed) {
      final border = Paint()
        ..color = baseColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
      canvas.drawRRect(rrect, border);
    }
  }

  @override
  bool shouldRepaint(_CardGlowPainter old) =>
      old.pulse != pulse ||
      old.pressed != pressed ||
      old.baseColor != baseColor;
}

// ═══════════════════════════════════════════════════════════════
//  المعاينة الحيّة — تُستخدم فقط داخل Dialog (عنصر واحد)
// ═══════════════════════════════════════════════════════════════
class _LiveEffectPreview extends StatelessWidget {
  final StoreItemEntity item;
  const _LiveEffectPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.category) {
      case StoreItemCategory.currency:
        return StoreGifPreview(
          assetPath:
              item.assetUrl ?? 'assets/store_gifs/currency/currency_01.gif',
          alt: item.nameAr,
          interactionPrompt: true,
        );

      case StoreItemCategory.membership:
        return StoreGifPreview(
          assetPath:
              item.assetUrl ?? 'assets/store_gifs/membership/membership_01.gif',
          alt: item.nameAr,
          interactionPrompt: true,
        );

      case StoreItemCategory.avatarFrame:
        return StoreAvatarFrame(
          colors: item.colors,
          child: const CircleAvatar(
            radius: 44,
            child: Icon(Icons.person, size: 40),
          ),
        );

      case StoreItemCategory.usernameGlow:
        return GlowText(
          text: 'اسم المستخدم',
          color: item.colors.first,
          fontSize: 20,
        );

      case StoreItemCategory.particleEffect:
        return Stack(
          alignment: Alignment.center,
          children: [
            ParticleFieldGeneric(color: item.colors.first),
            const Icon(Icons.auto_awesome, color: Colors.white54, size: 30),
          ],
        );
      case StoreItemCategory.animatedBackground:
      case StoreItemCategory.usernameBackground:
        return AnimatedGradientBackgroundGeneric(
          colors: item.colors,
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox.expand(),
        );
    }
  }
}
