import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../../core/services/snack_sfx.dart';
import '../../../../core/services/media_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/garment_contact_gate.dart';

import '../providers/garment_sector_provider.dart';
import 'garment_sector_detail_page.dart';

/// قطاع الألبسة الموحّد — ثلاثة تبويبات:
///   القطاعات · المنشآت · إعلانات الخدمات
///
/// كل البيانات من نظام `garment_*` الخادمي (24 قطاعًا، كتالوج خدمات،
/// رسوم نشر يحدّدها المالك). حلّ محلّ نظام `factory_*` الموازي الذي
/// حُذف لأنه كان يكرّر هذا ويشتّت البيانات.
///
/// اللغة البصرية مطابقة لسوق المنتجين: خلفية سوداء، ذهبي #FFD700،
/// جسيمات متحركة، وشرائح متوهّجة عند الاختيار.
class GarmentSectorPage extends ConsumerStatefulWidget {
  const GarmentSectorPage({super.key});

  @override
  ConsumerState<GarmentSectorPage> createState() => _GarmentSectorPageState();
}

class _GarmentSectorPageState extends ConsumerState<GarmentSectorPage>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);
  static const _amber = Color(0xFFFFA500);

  late final TabController _tabs;
  late final AnimationController _particleController;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  String? _sector;
  String _search = '';
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _particleController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      final r = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) setState(() => _isOwner = r == true);
    } catch (_) {
      // ليست حالة خطأ — غير المالك يرى الصفحة كاملة عدا أدوات الإدارة
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _GarmentParticlePainter(_particleController.value),
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  _tabBar(),
                  _sectorBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        // المنشآت لم تعد تبويبًا مستقلًا: تُنشأ وتُعرض داخل
                        // كل قطاع عند الضغط عليه (GarmentSectorDetailPage).
                        _SectorsTab(
                            sector: _sector,
                            glow: _glowAnim,
                            search: _search,
                            isOwner: _isOwner),
                        _ServiceAdsTab(sector: _sector, isOwner: _isOwner),
                      ],
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

  // لا يوجد AppBar في هذه الصفحة (كلها Scaffold مخصَّص بخلفية سوداء
  // وجسيمات متحركة)، فلم يكن فيها أي زر رجوع — لا شريط نظام يوفّره
  // تلقائيًا. هذا الزر يستعمل Navigator مباشرة، بلا انتظار AppBar.
  Widget _backButton(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white70, size: 18),
        ),
      );

  // زر "نشر إعلان" كان مخفيًا كزر عائم داخل تبويب واحد فقط، فلا يراه من
  // يفتح القطاع على التبويب الأول. صار في الترويسة، ظاهرًا دائمًا.
  Widget _publishAdButton(BuildContext context) => GestureDetector(
        onTap: () async {
          _tabs.animateTo(1);
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _PublishServiceAdSheet(defaultSector: _sector),
          );
          if (ok == true) ref.invalidate(garmentServiceAdsProvider(_sector));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.campaign_rounded, size: 16, color: Colors.black),
            SizedBox(width: 4),
            Text('نشر إعلان',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Builder(builder: _backButton),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) => Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [_gold, _amber]),
                  boxShadow: [
                    BoxShadow(
                        color: _gold.withValues(alpha: _glowAnim.value * .55),
                        blurRadius: 14),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.checkroom_rounded,
                  color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قطاع الألبسة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  Text('المصانع · الورشات · الخدمات · التوريد',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Builder(builder: _publishAdButton),
            if (_isOwner)
              IconButton(
                tooltip: 'أسعار النشر',
                icon: const Icon(Icons.price_change_rounded, color: _gold),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _PublicationFeesDialog(),
                ),
              ),
            IconButton(
              tooltip: 'بحث',
              icon: const Icon(Icons.search_rounded, color: _gold),
              onPressed: _openSearch,
            ),
          ],
        ),
      );

  Widget _tabBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [_gold, _amber]),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontSize: 12.5),
          tabs: const [
            Tab(text: 'القطاعات', height: 40),
            Tab(text: 'إعلانات الخدمات', height: 40),
          ],
        ),
      );

  Widget _sectorBar() {
    final sectors = ref.watch(garmentSectorsProvider);
    return sectors.when(
      loading: () => const SizedBox(height: 46),
      error: (_, __) => const SizedBox(height: 46),
      data: (list) => SizedBox(
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final s = isAll ? null : list[i - 1];
            final key = isAll ? null : s!['sector_key']?.toString();
            final selected = _sector == key;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => GestureDetector(
                  onTap: () => setState(() => _sector = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: selected
                          ? const LinearGradient(colors: [_gold, _amber])
                          : null,
                      color: selected ? null : Colors.white10,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: _gold.withValues(
                                      alpha: _glowAnim.value * .5),
                                  blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isAll ? '🧵' : (s!['icon_emoji']?.toString() ?? '🏭'),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          isAll ? 'الكل' : (s!['name_ar']?.toString() ?? ''),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: selected ? Colors.black : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final ctrl = TextEditingController(text: _search);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D0D1A),
          title: const Text('بحث في قطاع الألبسة'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'اسم المنشأة أو الخدمة أو المدينة…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (s) => Navigator.pop(ctx, s),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('مسح')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('بحث',
                    style: TextStyle(color: Colors.black))),
          ],
        ),
      ),
    );
    if (v != null && mounted) {
      setState(() => _search = v.trim());
      _tabs.animateTo(0);
    }
  }


}

// ═══ تبويب القطاعات ══════════════════════════════════════════════════
class _SectorsTab extends ConsumerWidget {
  final String? sector;
  final Animation<double> glow;
  final String search;
  final bool isOwner;
  const _SectorsTab(
      {required this.sector,
      required this.glow,
      this.search = '',
      this.isOwner = false});

  /// إدارة القطاع للمالك: إعادة تسمية/تغيير الرمز/حذف — خادميًا عبر
  /// owner_manage_garment. القطاع الذي عليه بيانات يُخفى بدل حذفه.
  Future<void> _manageSector(BuildContext context, WidgetRef ref,
      Map<String, dynamic> s) async {
    final name = TextEditingController(text: s['name_ar']?.toString() ?? '');
    final emoji = TextEditingController(text: s['icon_emoji']?.toString() ?? '');
    final m = ScaffoldMessenger.maybeOf(context);
    final action = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('إدارة القطاع'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(controller: emoji, decoration: const InputDecoration(labelText: 'الرمز (إيموجي)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, 'delete'),
              child: const Text('حذف', style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('حفظ')),
        ],
      ),
    );
    try {
      if (action == 'save') {
        await GarmentActions.ownerManage('sector', s['sector_key'].toString(), 'update',
            {'name_ar': name.text.trim(), 'icon_emoji': emoji.text.trim()});
      } else if (action == 'delete') {
        await GarmentActions.ownerManage('sector', s['sector_key'].toString(), 'delete', {});
      } else {
        return;
      }
      ref.invalidate(garmentSectorsProvider);
      m?.showSnackBarSfx(const SnackBar(content: Text('تم الحفظ')));
    } catch (e) {
      m?.showSnackBarSfx(SnackBar(content: Text('تعذّر: $e')));
    } finally {
      name.dispose();
      emoji.dispose();
    }
  }

  Future<void> _createSector(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final emoji = TextEditingController(text: '🧵');
    final m = ScaffoldMessenger.maybeOf(context);
    // كان هنا حقل "المعرّف بالإنجليزية" منفصل، وترك المالك إياه فارغًا —
    // وهو مفهوم غير مألوف لمستخدم عربي — يرمي SECTOR_KEY_AND_NAME_REQUIRED
    // من الخادم. sector_key لا يشترط أحرفًا إنجليزية أصلًا (تحقّقت من قيد
    // الجدول)، فصار يُشتق تلقائيًا من الاسم العربي نفسه — حقل واحد فقط.
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('قطاع جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم (مثال: الجلود)')),
          TextField(controller: emoji, decoration: const InputDecoration(labelText: 'الرمز (إيموجي)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (ok != true) {
      name.dispose();
      emoji.dispose();
      return;
    }
    final trimmedName = name.text.trim();
    if (trimmedName.isEmpty) {
      m?.showSnackBarSfx(const SnackBar(content: Text('اكتب اسم القطاع أولًا')));
      name.dispose();
      emoji.dispose();
      return;
    }
    final derivedKey = trimmedName.replaceAll(RegExp(r'\s+'), '_');
    try {
      await GarmentActions.ownerManage('sector', derivedKey, 'create', {
        'sector_key': derivedKey,
        'name_ar': trimmedName,
        'icon_emoji': emoji.text.trim(),
      });
      ref.invalidate(garmentSectorsProvider);
      m?.showSnackBarSfx(const SnackBar(content: Text('أُنشئ القطاع')));
    } catch (e) {
      final msg = e.toString().contains('duplicate key') || e.toString().contains('23505')
          ? 'يوجد قطاع بهذا الاسم أو بمعرّف مطابق له فعلًا — جرّب اسمًا مختلفًا.'
          : 'تعذّر الإنشاء: $e';
      m?.showSnackBarSfx(SnackBar(content: Text(msg)));
    } finally {
      name.dispose();
      emoji.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectors = ref.watch(garmentSectorsProvider);
    final catalog = ref.watch(garmentServiceCatalogProvider);

    return sectors.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(garmentSectorsProvider)),
      data: (list) {
        final q = search.trim();
        final shown = (sector == null
                ? list
                : list.where((s) => s['sector_key'] == sector).toList())
            .where((s) => q.isEmpty || (s['name_ar']?.toString() ?? '').contains(q))
            .toList();
        final services = catalog.valueOrNull ?? const [];

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: shown.length + (isOwner ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == shown.length) {
              return GestureDetector(
                onTap: () => _createSector(context, ref),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: .4)),
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_circle_outline, color: Color(0xFFFFD700), size: 34),
                    SizedBox(height: 6),
                    Text('قطاع جديد', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w800)),
                  ]),
                ),
              );
            }
            final s = shown[i];
            final key = s['sector_key']?.toString();
            final count =
                services.where((c) => c['sector_key'] == key).length;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GarmentSectorDetailPage(
                      sectorKey: key ?? '',
                      sectorName: s['name_ar']?.toString() ?? '',
                      emoji: s['icon_emoji']?.toString() ?? '🏭',
                      isOwner: isOwner))),
              onLongPress: isOwner ? () => _manageSector(context, ref, s) : null,
              child: AnimatedBuilder(
              animation: glow,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
                  ),
                  border: Border.all(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: .15 + glow.value * .2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s['icon_emoji']?.toString() ?? '🏭',
                        style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s['name_ar']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$count خدمة',
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }
}

// ═══ تبويب المنشآت ═══════════════════════════════════════════════════




// ═══ تبويب إعلانات الخدمات ═══════════════════════════════════════════
class _ServiceAdsTab extends ConsumerWidget {
  final String? sector;
  final bool isOwner;
  const _ServiceAdsTab({required this.sector, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(garmentServiceAdsProvider(sector));

    return Stack(
      children: [
        ads.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          error: (e, _) => _ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(garmentServiceAdsProvider(sector))),
          data: (list) {
            if (list.isEmpty) {
              return const _EmptyState(
                icon: Icons.campaign_rounded,
                title: 'لا إعلانات خدمات',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ServiceAdCard(
                ad: list[i],
                isOwner: isOwner,
                onModerate: (status) async {
                  final id = list[i]['id'].toString();
                  final m = ScaffoldMessenger.maybeOf(context);
                  try {
                    if (status == '__delete__') {
                      await GarmentActions.ownerManage('ad', id, 'delete', {});
                    } else if (status.startsWith('__edit__:')) {
                      final parts = status.substring(9).split('\u0000');
                      await GarmentActions.ownerManage('ad', id, 'update', {
                        'title': parts.first,
                        'description': parts.length > 1 ? parts[1] : '',
                        'city': parts.length > 2 ? parts[2] : '',
                        'phone': parts.length > 3 ? parts[3] : '',
                      });
                    } else {
                      await GarmentActions.setAdStatus(id, status);
                    }
                    ref.invalidate(garmentServiceAdsProvider(sector));
                    m?.showSnackBarSfx(const SnackBar(content: Text('تم التنفيذ')));
                  } catch (e) {
                    m?.showSnackBarSfx(SnackBar(content: Text('تعذّر: $e')));
                  }
                },
              ),
            );
          },
        ),
        // publishServiceAd كانت موجودة في المزوّد وموصولة بالخادم منذ
        // إصلاح p_request_id، لكن بلا أي زر أو نموذج يستدعيها — فتعذّر
        // النشر كليًا. هذا الزر يفتح النموذج الناقص.
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton.extended(
            heroTag: 'publish_service_ad',
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('نشر خدمة',
                style: TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () => _openPublishSheet(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _openPublishSheet(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublishServiceAdSheet(defaultSector: sector),
    );
    if (ok == true) ref.invalidate(garmentServiceAdsProvider(sector));
  }
}

// القطاعات والخدمات تُقرأ من الخادم (garment_sectors /
// get_garment_service_catalog) لا من قوائم مثبّتة: القائمة المثبّتة
// السابقة كانت تضع قطاعًا افتراضيًا 'garment' غير موجود على الخادم،
// فيُرفض كل نشر لم يغيّر فيه المستخدم القطاع يدويًا.
class _PublishServiceAdSheet extends ConsumerStatefulWidget {
  final String? defaultSector;
  const _PublishServiceAdSheet({this.defaultSector});
  @override
  ConsumerState<_PublishServiceAdSheet> createState() =>
      _PublishServiceAdSheetState();
}

class _PublishServiceAdSheetState
    extends ConsumerState<_PublishServiceAdSheet> {

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  XFile? _image;
  double? _lat;
  double? _lng;
  bool _locating = false;

  /// موقع GPS حقيقي من الجهاز (بإذن المستخدم). يُحفظ في specs كإحداثيات،
  /// والعنوان المكتوب يبقى متاحًا كبديل حين لا يُتاح الموقع.
  Future<void> _useGps() async {
    setState(() => _locating = true);
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'خدمة الموقع مغلقة في الجهاز';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'لم يُمنح إذن الموقع';
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 20));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      m?.showSnackBarSfx(const SnackBar(content: Text('حُدّد موقعك')));
    } catch (e) {
      m?.showSnackBarSfx(SnackBar(content: Text('تعذّر تحديد الموقع: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
  String? _service;
  late String? _sector = widget.defaultSector;
  String _currency = 'points';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _city.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _service == null || _sector == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBarSfx(const SnackBar(
          content: Text('اختر الخدمة والقطاع واكتب عنوانًا')));
      return;
    }
    final fees = await ref.read(garmentPublicationFeesProvider.future);
    final fee = fees.firstWhere((f) => f['content_type'] == 'garment_service',
        orElse: () => const <String, dynamic>{});
    final cost = _currency == 'gems' ? (fee['gems_cost'] ?? 0) : (fee['points_cost'] ?? 0);
    // الإعلان لا يُنشر ولا يظهر إلا بعد موافقة صريحة على الرسوم ثم الخصم
    // والتحقق خادميًا في publish_garment_service_ad.
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد رسوم نشر الإعلان'),
        content: Text('سيُخصم $cost ${_currency == 'gems' ? 'جوهرة' : 'نقطة'} من رصيدك، ثم يظهر إعلانك فورًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('ادفع وانشر')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final images = <String>[];
      if (_image != null && me != null) {
        images.add(await MediaUploadService(bucket: 'media')
            .uploadFile(file: _image!, folder: 'garment/ads', uid: me));
      }
      await GarmentActions.publishServiceAd(
        address: _address.text.trim(),
        images: images,
        specs: {
          if (_lat != null) 'lat': _lat,
          if (_lng != null) 'lng': _lng,
        },
        serviceKey: _service!,
        sectorKey: _sector!,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        publicationCurrency: _currency,
      );
      if (mounted) Navigator.pop(context, true);
      messenger?.showSnackBarSfx(const SnackBar(
          content: Text('نُشر الإعلان'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      final s = e.toString();
      messenger?.showSnackBarSfx(SnackBar(
        content: Text(s.contains('INSUFFICIENT')
            ? 'رصيدك لا يكفي لرسوم النشر.'
            : s.contains('QUOTA')
                ? 'استنفدت حصة النشر لعضويتك.'
                : s.contains('ACCESS_REVOKED')
                    ? 'أوقف المالك صلاحية نشر الخدمات لحسابك.'
                    : s.contains('INVALID_SERVICE')
                        ? 'هذه الخدمة لا تتبع القطاع المختار.'
                        : 'تعذّر النشر: $s'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF120A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Text('نشر إعلان خدمة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Builder(builder: (context) {
                  // الخادم يشترط أن تنتمي الخدمة للقطاع المختار
                  // (garment_service_catalog.sector_key) وإلا INVALID_SERVICE،
                  // فتُعرض فقط خدمات القطاع المختار.
                  final services = (ref.watch(garmentServiceCatalogProvider)
                              .valueOrNull ??
                          const <Map<String, dynamic>>[])
                      .where((e) =>
                          _sector == null ||
                          e['sector_key']?.toString() == _sector)
                      .toList();
                  final keys = services
                      .map((e) => e['service_key']?.toString() ?? '')
                      .where((k) => k.isNotEmpty)
                      .toSet();
                  return DropdownButtonFormField<String>(
                    // initialValue خارج القائمة يرمي assertion — نتحقق أولًا
                    initialValue: keys.contains(_service) ? _service : null,
                    dropdownColor: const Color(0xFF1A0F33),
                    decoration:
                        const InputDecoration(labelText: 'نوع الخدمة'),
                    items: [
                      for (final e in services)
                        if ((e['service_key']?.toString() ?? '').isNotEmpty)
                          DropdownMenuItem(
                            value: e['service_key'].toString(),
                            child: Text(e['name_ar']?.toString() ??
                                e['service_key'].toString()),
                          ),
                    ],
                    onChanged: (v) => setState(() => _service = v),
                  );
                }),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final sectors =
                      ref.watch(garmentSectorsProvider).valueOrNull ??
                          const <Map<String, dynamic>>[];
                  final keys = sectors
                      .map((e) => e['sector_key']?.toString() ?? '')
                      .toSet();
                  return DropdownButtonFormField<String>(
                    initialValue: keys.contains(_sector) ? _sector : null,
                    dropdownColor: const Color(0xFF1A0F33),
                    decoration: const InputDecoration(labelText: 'القطاع'),
                    items: [
                      for (final e in sectors)
                        DropdownMenuItem(
                          value: e['sector_key'].toString(),
                          child: Text(e['name_ar']?.toString() ??
                              e['sector_key'].toString()),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _sector = v;
                      _service = null;
                    }),
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
                const SizedBox(height: 10),
                TextField(
                    controller: _desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'التفاصيل')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'المدينة')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'الهاتف')),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان (كتابة)')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating ? null : _useGps,
                      icon: Icon(_lat == null ? Icons.my_location : Icons.check_circle, size: 18),
                      label: Text(_lat == null ? 'تحديد الموقع GPS' : 'تم تحديد الموقع'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final f = await ImagePicker()
                            .pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (f != null) setState(() => _image = f);
                      },
                      icon: Icon(_image == null ? Icons.add_photo_alternate_outlined : Icons.check_circle, size: 18),
                      label: Text(_image == null ? 'رفع صورة' : 'تم اختيار الصورة'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'points', label: Text('نقاط ⭐')),
                    ButtonSegment(value: 'gems', label: Text('جواهر 💎')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (s) =>
                      setState(() => _currency = s.first),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('نشر',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceAdCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final bool isOwner;
  final Future<void> Function(String status) onModerate;
  const _ServiceAdCard(
      {required this.ad, required this.isOwner, required this.onModerate});

  Future<void> _editAd(BuildContext context) async {
    // كل حقل يقبله owner_manage_garment لإعلان (العنوان، الوصف، المدينة،
    // الهاتف) صار قابلًا للتعديل هنا، لا العنوان والوصف فقط.
    final title = TextEditingController(text: ad['title']?.toString() ?? '');
    final desc = TextEditingController(text: ad['description']?.toString() ?? '');
    final city = TextEditingController(text: ad['city']?.toString() ?? '');
    final phone = TextEditingController(text: ad['phone']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تعديل الإعلان'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
            TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      await onModerate(
          '__edit__:${title.text.trim()}\u0000${desc.text.trim()}\u0000${city.text.trim()}\u0000${phone.text.trim()}');
    }
    title.dispose();
    desc.dispose();
    city.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = (ad['price_minor_units'] as num?)?.toInt() ?? 0;
    final status = ad['status']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
        ),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ad['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
              ),
              if (price > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                      '${(price / 100).toStringAsFixed(2)} ${ad['currency'] ?? 'USD'}',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          // اسم الناشر كما يظهر في الغرفة (بمؤثراته وخلفيته).
          ServerUsernameDisplay(
            uid: ad['owner_uid']?.toString() ?? '',
            fallbackName: 'عضو',
            fallbackFontSize: 12,
          ),
          if (ad['images'] is List && (ad['images'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network((ad['images'] as List).first.toString(),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          if (ad['description']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(ad['description'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ad['city']?.toString().isNotEmpty == true)
                _Tag('📍 ${ad['city']}'),
              if (ad['unit']?.toString().isNotEmpty == true)
                _Tag('الوحدة: ${ad['unit']}'),
              if (ad['min_qty'] != null) _Tag('أقل كمية: ${ad['min_qty']}'),
              if (ad['specs'] is Map && (ad['specs'] as Map)['lat'] != null)
                _Tag('🛰️ ${((ad['specs'] as Map)['lat'] as num).toStringAsFixed(4)}, ${((ad['specs'] as Map)['lng'] as num).toStringAsFixed(4)}'),
            ],
          ),
          if (ad['owner_uid']?.toString() != Supabase.instance.client.auth.currentUser?.id) ...[
            const SizedBox(height: 8),
            GarmentContactGate(
              targetType: 'service_ad',
              targetId: ad['id'].toString(),
              ownerUid: ad['owner_uid']?.toString() ?? '',
              ownerName: 'صاحب الإعلان',
              detail: ad,
            ),
          ],
          if (isOwner) ...[
            const Divider(height: 18, color: Colors.white12),
            Row(
              children: [
                Text('الحالة: $status',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const Spacer(),
                TextButton(
                  onPressed: () => onModerate('published'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF34D399),
                      visualDensity: VisualDensity.compact),
                  child: const Text('قبول', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white54),
                  onPressed: () => _editAd(context),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => onModerate('__delete__'),
                ),
                TextButton(
                  onPressed: () => onModerate('blocked'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      visualDensity: VisualDensity.compact),
                  child: const Text('رفض', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══ ورقة نشر منشأة ══════════════════════════════════════════════════





// ═══ تبويب منشآتي — الإنشاء لا يَنشر، فهنا يتم النشر ═══════════════
//
// المنشأة المحفوظة تبقى is_published=false ولا يعرضها دليل المنشآت،
// فبدت وكأنها ضاعت بعد الحفظ. هذا التبويب يعرض منشآت العضو مهما كانت
// حالتها، ويتيح نشرها — والنشر يخصم رسوم النشر التي يحدّدها المالك.






// ═══ ودجات مشتركة ════════════════════════════════════════════════════
class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  const _EmptyState({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFFFD700).withValues(alpha: .4)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),

          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12.5)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700)),
              ),
            ],
          ),
        ),
      );
}

// ═══ جسيمات الخلفية (مطابقة لسوق المنتجين) ═══════════════════════════
class _GarmentParticlePainter extends CustomPainter {
  final double progress;
  static final List<_P> _particles = List.generate(
      40,
      (i) => _P(
            x: (i * 0.0713) % 1.0,
            y: (i * 0.0971) % 1.0,
            size: 1.0 + (i % 5) * 0.5,
            speed: 0.008 + (i % 7) * 0.002,
            phase: i * 0.251,
          ));

  _GarmentParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.phase) % 1.0;
      final y = (p.y - t * p.speed * 10) % 1.0;
      final x = p.x + math.sin(t * math.pi * 2 + p.phase) * 0.03;
      final opacity = (math.sin(t * math.pi * 2) + 1) / 2 * 0.4;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GarmentParticlePainter old) =>
      old.progress != progress;
}

class _P {
  final double x, y, size, speed, phase;
  const _P(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.phase});
}


/// المالك يضبط رسوم نشر المنشأة وإعلان الخدمة والمنتج داخل قطاع الألبسة.
/// الحفظ خادمي (admin_upsert_garment_publication_fee يرفض غير المالك)، والرسوم
/// الجديدة تظهر فورًا في نوافذ تأكيد الدفع لدى الأعضاء.
class _PublicationFeesDialog extends ConsumerStatefulWidget {
  const _PublicationFeesDialog();
  @override
  ConsumerState<_PublicationFeesDialog> createState() => _PublicationFeesDialogState();
}

class _PublicationFeesDialogState extends ConsumerState<_PublicationFeesDialog> {
  static const _labels = {
    'garment_business': 'إضافة منشأة',
    'garment_service': 'إعلان خدمة',
    'garment_product': 'إعلان منتج',
  };
  final Map<String, TextEditingController> _points = {};
  final Map<String, TextEditingController> _gems = {};
  final Map<String, bool> _enabled = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._points.values, ..._gems.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final m = ScaffoldMessenger.of(context);
    try {
      for (final key in _points.keys) {
        await GarmentActions.setPublicationFee(
          contentType: key,
          pointsCost: int.tryParse(_points[key]!.text.trim()) ?? 0,
          gemsCost: int.tryParse(_gems[key]!.text.trim()) ?? 0,
          isEnabled: _enabled[key] ?? true,
        );
      }
      ref.invalidate(garmentPublicationFeesProvider);
      nav.pop();
      m.showSnackBarSfx(const SnackBar(content: Text('حُفظت أسعار النشر')));
    } catch (e) {
      m.showSnackBarSfx(SnackBar(content: Text('تعذّر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fees = ref.watch(garmentPublicationFeesProvider);
    return AlertDialog(
      title: const Text('أسعار النشر'),
      content: fees.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('تعذّر التحميل: $e'),
        data: (rows) {
          for (final r in rows) {
            final k = r['content_type'].toString();
            _points.putIfAbsent(k, () => TextEditingController(text: '${r['points_cost'] ?? 0}'));
            _gems.putIfAbsent(k, () => TextEditingController(text: '${r['gems_cost'] ?? 0}'));
            _enabled.putIfAbsent(k, () => r['is_enabled'] != false);
          }
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(_labels[r['content_type']] ?? r['content_type'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Switch(
                        value: _enabled[r['content_type'].toString()] ?? true,
                        onChanged: (v) => setState(() => _enabled[r['content_type'].toString()] = v),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _points[r['content_type'].toString()],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'نقاط ⭐'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _gems[r['content_type'].toString()],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'جواهر 💎'),
                        ),
                      ),
                    ]),
                  ]),
                ),
            ]),
          );
        },
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}
