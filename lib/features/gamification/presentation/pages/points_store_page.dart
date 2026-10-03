import '../../../../core/data/supabase_document_compat.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../store/domain/big_store_catalog.dart';
import '../../../../core/di/injection_container.dart';
import '../../../store/domain/entities/store_item_entity.dart';
import '../../../store/domain/usecases/store_usecases.dart';
import '../../../store/presentation/widgets/store_preview.dart';

/// Compatibility enum retained because StoreFeaturesTab imports it.
enum StoreFeatureType { glow, frame, background }

class PointsStorePage extends StatefulWidget {
  const PointsStorePage({super.key});

  @override
  State<PointsStorePage> createState() => _PointsStorePageState();
}

class _PointsStorePageState extends State<PointsStorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Future<Map<String, BigStoreProduct>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _catalogFuture = _loadCatalog();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<Map<String, BigStoreProduct>> _loadCatalog() async {
    final catalogResult = await sl<ListStoreCatalogUseCase>().call();

    return catalogResult.fold(
      (failure) => throw Exception(
        'تعذّر تحميل كتالوج المتجر من الخادم: ${failure.message}',
      ),
      (items) {
        final result = <String, BigStoreProduct>{};

        for (final item in items) {
          final section = switch (item.category) {
            StoreItemCategory.currency => 'currency',
            StoreItemCategory.usernameGlow => 'glow',
            StoreItemCategory.avatarFrame => 'frame',
            StoreItemCategory.animatedBackground => 'background',
            StoreItemCategory.membership => 'membership',
            StoreItemCategory.particleEffect => 'background',
            StoreItemCategory.usernameBackground => 'background',
          };

          final asset = item.assetUrl?.trim();

          if (asset == null || asset.isEmpty) {
            throw Exception(
              'عنصر المتجر ${item.id} لا يملك asset_url صالحًا.',
            );
          }

          final sku = item.sku.trim().isEmpty ? item.id : item.sku.trim();

          result[item.id] = BigStoreProduct(
            id: item.id,
            sku: sku,
            section: section,
            nameAr: item.nameAr,
            pricePoints: item.pricePoints,
            priceGems: item.priceGems ?? 0,
            assetUrl: asset,
            rarity: item.rarity,
            featured: item.isFeatured,
          );
        }

        return result;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MASHAREENA DIGITAL WORLD'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(98),
            child: Column(
              children: [
                const _StoreIntroBar(),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabs: const [
                    Tab(
                        icon: _StoreTabIcon(
                            asset:
                                'assets/store_gifs/currency/currency_01.gif'),
                        text: 'النقاط والجواهر'),
                    Tab(
                        icon: _StoreTabIcon(
                            asset: 'assets/store_gifs/glow/glow_01.gif'),
                        text: 'التوهجات'),
                    Tab(icon: Icon(Icons.crop_square_rounded), text: 'الإطارات'),
                    Tab(
                        icon: _StoreTabIcon(
                            asset:
                                'assets/store_gifs/background/background_01.gif'),
                        text: 'الخلفيات'),
                    Tab(
                        icon: _StoreTabIcon(
                            asset:
                                'assets/store_gifs/membership/membership_01.gif'),
                        text: 'الميزات والعضويات'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: FutureBuilder<Map<String, BigStoreProduct>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final catalog = snapshot.data ?? const <String, BigStoreProduct>{};

            return HeroMode(
              enabled: false,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SectionGrid(
                    products: _products(catalog, 'currency'),
                    title: ' النقاط والجواهر',
                    sectionAsset: 'assets/store_gifs/currency/currency_01.gif',
                  ),
                  _SectionGrid(
                    products: _products(catalog, 'glow'),
                    title: '50 توهج ',
                    sectionAsset: 'assets/store_gifs/glow/glow_01.gif',
                  ),
                  _SectionGrid(
                    products: _products(catalog, 'frame'),
                    title: 'إطارات GIF من الخادم',
                    sectionAsset: 'assets/store_gifs/glow/glow_01.gif',
                  ),
                  _SectionGrid(
                    products: _products(catalog, 'background'),
                    title: '50 خلفية ',
                    sectionAsset:
                        'assets/store_gifs/background/background_01.gif',
                  ),
                  _MembershipSection(
                    products: _products(catalog, 'membership'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<BigStoreProduct> _products(
    Map<String, BigStoreProduct> catalog,
    String section,
  ) {
    final items = catalog.values
        .where((product) => product.section == section)
        .toList(growable: false);

    return items;
  }
}

class _StoreTabIcon extends StatelessWidget {
  final String asset;

  const _StoreTabIcon({required this.asset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: StoreGifPreview(
        assetPath: asset,
        alt: 'Mashareena  store section',
        interactionPrompt: false,
      ),
    );
  }
}

class _StoreIntroBar extends StatelessWidget {
  const _StoreIntroBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF15071F), Color(0xFF651A91)],
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'كل عناصر المتجر  • 250 منتجًا • معاينة تفاعلية • شراء خادمي',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  final List<BigStoreProduct> products;
  final String title;
  final String sectionAsset;

  const _SectionGrid({
    required this.products,
    required this.title,
    required this.sectionAsset,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1400
        ? 6
        : width >= 1000
            ? 5
            : width >= 720
                ? 4
                : 2;

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.crop_square_rounded, size: 60, color: Colors.white30),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('لا توجد إطارات محلية. الإطارات الجديدة تُرفع من مالك المنصة كملفات GIF إلى الخادم.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0E0A18), Color(0xFF32124D)],
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  height: 68,
                  width: 68,
                  child: StoreGifPreview(
                    assetPath: sectionAsset,
                    alt: title,
                    interactionPrompt: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 28),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ProductCard(product: products[index]),
              childCount: products.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.70,
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipSection extends StatelessWidget {
  final List<BigStoreProduct> products;

  const _MembershipSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _MembershipPolicyBanner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 28),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ProductCard(product: products[index]),
              childCount: products.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.70,
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipPolicyBanner extends StatelessWidget {
  const _MembershipPolicyBanner();

  @override
  Widget build(BuildContext context) {
    // لافتة سياسة العضويات أُزيلت: نصّ إداري داخلي عن استثناءات
    // المالك لا يعني العضو المشتري، ويشغل مساحة فوق البضاعة نفسها.
    return const SizedBox.shrink();
  }
}

class _ProductCard extends StatefulWidget {
  final BigStoreProduct product;

  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _busy = false;

  Future<bool> _confirmPurchase({required String title, required String detail, String action = 'شراء'}) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(detail),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
            ],
          ),
        ) ?? false;
  }

  Future<void> _purchase() async {
    if (_busy) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جلسة المستخدم غير موجودة.'),
        ),
      );
      return;
    }

    if (widget.product.section == 'membership') {
      await _purchaseMembership();
      return;
    }

    final confirmed = await _confirmPurchase(
      title: 'تأكيد الشراء',
      detail: 'سيتم شراء «${widget.product.nameAr}» مقابل ${widget.product.pricePoints} نقطة وحفظ العملية على الخادم. هل تريد المتابعة؟',
    );
    if (!confirmed) return;

    setState(() => _busy = true);

    try {
      final category = switch (widget.product.section) {
        'frame' => StoreItemCategory.avatarFrame,
        'glow' => StoreItemCategory.usernameGlow,
        'background' => StoreItemCategory.animatedBackground,
        'currency' => StoreItemCategory.currency,
        _ => throw StateError(
            'قسم متجر غير مدعوم: ${widget.product.section}',
          ),
      };

      final item = StoreItemEntity(
        id: widget.product.id,
        category: category,
        nameAr: widget.product.nameAr,
        pricePoints: widget.product.pricePoints,
        priceGems: widget.product.priceGems,
        colors: const [],
        enabled: true,
        assetUrl: widget.product.assetUrl,
        rarity: widget.product.rarity,
        isFeatured: widget.product.featured,
        sku: widget.product.sku,
        assetType: 'gif',
        previewAsset: widget.product.assetUrl,
      );

      final result = await sl<PurchaseStoreItemUseCase>().call(
        uid: user.id,
        item: item,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم شراء العنصر ✓'),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يكتمل الشراء: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _purchaseMembership() async {
    if (_busy) return;
    final confirmed = await _confirmPurchase(
      title: 'تأكيد الاشتراك',
      detail: 'سيتم شراء «${widget.product.nameAr}» وتثبيت العضوية عبر الخادم. هل تريد المتابعة؟',
      action: 'تأكيد',
    );
    if (!confirmed) return;

    setState(() => _busy = true);

    try {
      final callable = SupabaseFunctionsCompat.instance.httpsCallable(
        'purchaseMembership',
      );

      await callable.call({
        'tierId': widget.product.membershipTier,
        'requestId': const Uuid().v4(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد العملية من الخادم.'),
        ),
      );
    } on SupabaseFunctionException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'لم تكتمل عملية العضوية.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _gift() async {
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إهداء العضوية من DRAGON'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'UID المستلم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('إهداء'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target == null || target.isEmpty || !mounted) return;
    try {
      final callable = SupabaseFunctionsCompat.instance
          .httpsCallable('adminGrantMembershipTier');
      await callable.call({
        'targetUid': target,
        'tierId': widget.product.membershipTier,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إهداء العضوية مجانًا من DRAGON.')),
      );
    } on SupabaseFunctionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذر الإهداء.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF251035), Color(0xFF0F0B15)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: const Color(0x554A2769)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: ProductGifViewer(
                assetPath: p.assetUrl,
                productName: p.nameAr,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Text(
              p.nameAr,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              p.section == 'membership'
                  ? 'عضوية ${p.membershipTier ?? 'premium'} — السعر من الخادم'
                  : '${p.pricePoints} نقطة',
              style: const TextStyle(
                color: Color(0xFFFFD43B),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _purchase,
                child: _busy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('شراء'),
              ),
            ),
          ),
          if (p.section == 'membership' &&
              SupabaseAuthCompat.instance.currentUser?.email ==
                  'ya1515468@gmail.com')
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy || p.membershipTier == null ? null : _gift,
                  icon: const Icon(Icons.card_giftcard, size: 16),
                  label: const Text('إهداء مجانًا من DRAGON'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
