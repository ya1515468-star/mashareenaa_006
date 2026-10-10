import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ═══════════════════════════════════════════════════════════════
/// لوحة إدارة سوق المنتجين — موافقة/رفض/حذف الريلات
/// إدارة المناقصات والطلبات الخارجية
/// إدارة حصص النشر الشهرية حسب العضوية
/// ═══════════════════════════════════════════════════════════════

// ─── Provider للريلات المعلّقة ────────────────────────────────────────────────
final _pendingReelsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('producer_reels')
      .stream(primaryKey: ['id'])
      .eq('is_approved', false)
      .order('created_at', ascending: false);
});

final _allReelsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('producer_reels')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100);
});

/// حصص الريلز لكل مستوى عضوية.
///
/// المصدر هو reel_membership_quotas — الجدول الذي تقرؤه فعليًا
/// get_my_reel_quota ويفرضه publish_producer_reel_paid. كانت اللوحة
/// تعدّل reel_publish_quota (جدول موازٍ فقير لا يقرؤه أي مسار نشر)،
/// فكانت كل تعديلات المالك بلا أثر.
final _reelQuotaProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('reel_membership_quotas')
      .select()
      .order('reels_per_month');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _pendingListingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('garment_service_ads')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at', ascending: false);
});

class AdminProducersMarketTab extends ConsumerStatefulWidget {
  const AdminProducersMarketTab({super.key});

  @override
  ConsumerState<AdminProducersMarketTab> createState() =>
      _AdminProducersMarketTabState();
}

class _AdminProducersMarketTabState
    extends ConsumerState<AdminProducersMarketTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFFFD700),
          tabs: const [
            Tab(text: '🎬 ريلات معلّقة'),
            Tab(text: '📋 كل الريلات'),
            Tab(text: '⚡ حصص النشر'),
            Tab(text: '🏷️ إعلانات الألبسة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PendingReelsPanel(),
              _AllReelsPanel(),
              _QuotaPanel(),
              _GarmentListingsPendingPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ريلات معلّقة ─────────────────────────────────────────────────────────────
class _PendingReelsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingReelsProvider);
    return async.when(
      data: (reels) {
        if (reels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('لا توجد ريلات معلّقة',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reels.length,
          itemBuilder: (_, i) => _ReelAdminCard(reel: reels[i]),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

// ─── بطاقة إدارة ريل ──────────────────────────────────────────────────────────
class _ReelAdminCard extends StatefulWidget {
  final Map<String, dynamic> reel;
  const _ReelAdminCard({required this.reel});

  @override
  State<_ReelAdminCard> createState() => _ReelAdminCardState();
}

class _ReelAdminCardState extends State<_ReelAdminCard> {
  bool _busy = false;

  Future<void> _action(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      // owner_moderate_reel حُذفت من الخادم عند تنظيف ازدواج الريلز؛
      // owner_update_reel هي المسار الحيّ الوحيد الآن. 'approve' هنا
      // يعني نشرًا وموافقة معًا، و'reject'/'block' يعني حجبًا مع سبب.
      final patch = <String, dynamic>{
        if (action == 'approve') ...{'is_published': true, 'is_approved': true},
        if (action == 'reject' || action == 'block')
          ...{'is_blocked': true, 'owner_note': note ?? ''},
        if (action == 'unblock') 'is_blocked': false,
      };
      await Supabase.instance.client.rpc('owner_update_reel', params: {
        'p_reel_id': widget.reel['id'],
        'p_patch': patch,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final isApproved = reel['is_approved'] == true;
    final isFeatured = reel['is_featured'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApproved
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة المصغّرة
          if (reel['thumbnail_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: reel['thumbnail_url'],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.white10),
                ),
              ),
            ),
          const SizedBox(height: 10),
          // معلومات
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel['title']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reel['category']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // حالة الريل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isApproved ? '✅ معتمد' : '⏳ معلّق',
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // إحصائيات
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              _Stat('❤️', '${reel['likes_count'] ?? 0}'),
              _Stat('👁', '${reel['views_count'] ?? 0}'),
              _Stat('💬', '${reel['comments_count'] ?? 0}'),
              _Stat('↗️', '${reel['shares_count'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 12),
          // أزرار الإجراءات
          if (_busy)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isApproved)
                  _ActionBtn(
                    label: 'موافقة',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    onTap: () => _action('approve'),
                  ),
                if (isApproved)
                  _ActionBtn(
                    label: 'إلغاء الاعتماد',
                    icon: Icons.cancel_rounded,
                    color: Colors.orange,
                    onTap: () => _action('reject'),
                  ),
                _ActionBtn(
                  label: isFeatured ? 'إلغاء التمييز' : 'تمييز',
                  icon: isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD700),
                  onTap: () => _action(isFeatured ? 'unfeature' : 'feature'),
                ),
                _ActionBtn(
                  label: 'حذف',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('تأكيد الحذف'),
                        content: const Text('هل تريد حذف هذا الريل نهائياً؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('إلغاء')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('حذف',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) _action('delete');
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── كل الريلات ───────────────────────────────────────────────────────────────
class _AllReelsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allReelsProvider);
    return async.when(
      data: (reels) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reels.length,
        itemBuilder: (_, i) => _ReelAdminCard(reel: reels[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}

// ─── حصص النشر ────────────────────────────────────────────────────────────────
class _QuotaPanel extends ConsumerWidget {
  static const _tiers = [
    ('free', 'مجاني', '⚪'),
    ('bronze', 'برونزي', '🟤'),
    ('silver', 'فضي', '⚪'),
    ('gold', 'ذهبي', '🟡'),
    ('vip', 'VIP', '💎'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_reelQuotaProvider);
    return async.when(
      data: (quotas) {
        final quotaMap = {for (final q in quotas) q['tier_id']: q};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '⚡ حصص نشر الريلات الشهرية',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'القيمة -1 تعني غير محدود',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 16),
            ..._tiers.map((tier) {
              final (key, nameAr, emoji) = tier;
              final q = quotaMap[key];
              final limit = q?['reels_per_month'] ?? 0;
              int n(dynamic v, int d) =>
                  v is int ? v : int.tryParse('$v') ?? d;
              return _QuotaEditCard(
                tierKey: key,
                nameAr: nameAr,
                emoji: emoji,
                currentLimit: n(limit, 0),
                costPoints: n(q?['publish_cost_points'], 0),
                costGems: n(q?['publish_cost_gems'], 0),
                maxDuration: n(q?['max_duration_seconds'], 30),
                canPin: q?['can_pin'] == true,
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}

class _QuotaEditCard extends ConsumerStatefulWidget {
  final String tierKey;
  final String nameAr;
  final String emoji;
  final int currentLimit;
  final int costPoints;
  final int costGems;
  final int maxDuration;
  final bool canPin;

  const _QuotaEditCard({
    required this.tierKey,
    required this.nameAr,
    required this.emoji,
    required this.currentLimit,
    required this.costPoints,
    required this.costGems,
    required this.maxDuration,
    required this.canPin,
  });

  @override
  ConsumerState<_QuotaEditCard> createState() => _QuotaEditCardState();
}

class _QuotaEditCardState extends ConsumerState<_QuotaEditCard> {
  late final TextEditingController _ctrl;
  late final TextEditingController _pointsCtrl;
  late final TextEditingController _gemsCtrl;
  late final TextEditingController _durCtrl;
  late bool _canPin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.currentLimit}');
    _pointsCtrl = TextEditingController(text: '${widget.costPoints}');
    _gemsCtrl = TextEditingController(text: '${widget.costGems}');
    _durCtrl = TextEditingController(text: '${widget.maxDuration}');
    _canPin = widget.canPin;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pointsCtrl.dispose();
    _gemsCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null) return;
    setState(() => _busy = true);
    try {
      // update_reel_membership_quota هي التي تكتب في الجدول الذي
      // يقرؤه مسار النشر فعليًا، بعكس owner_update_reel_quota التي
      // كانت تكتب في الجدول الموازي المهمل.
      await Supabase.instance.client
          .rpc('update_reel_membership_quota', params: {
        'p_tier_id': widget.tierKey,
        'p_reels_per_month': val,
        'p_max_duration_seconds': int.tryParse(_durCtrl.text.trim()) ?? 30,
        'p_publish_cost_points': int.tryParse(_pointsCtrl.text.trim()) ?? 0,
        'p_publish_cost_gems': int.tryParse(_gemsCtrl.text.trim()) ?? 0,
        'p_can_pin': _canPin,
        'p_allow_download': true,
        'p_is_enabled': true,
      });
      // الجدول FutureProvider لا يتحدّث تلقائيًا كما تفعل تدفّقات الريلز؛
      // نُبطله بعد الكتابة لتعرض البطاقات القيم الجديدة فورًا.
      ref.invalidate(_reelQuotaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('تم تحديث الحصة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── صف التحكّم الكامل: كل ما يفرضه الخادم فعلًا ───
          Row(children: [
            Expanded(
                child: _numField(_pointsCtrl, 'رسوم النقاط', '⭐')),
            const SizedBox(width: 8),
            Expanded(child: _numField(_gemsCtrl, 'رسوم الجواهر', '💎')),
            const SizedBox(width: 8),
            Expanded(child: _numField(_durCtrl, 'أقصى مدة (ث)', '⏱')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Switch(
              value: _canPin,
              activeThumbColor: const Color(0xFFFFD700),
              onChanged: (v) => setState(() => _canPin = v),
            ),
            const Text('يسمح بالتثبيت',
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          ]),
          const Divider(height: 14, color: Colors.white12),
          Row(
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.nameAr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFFD700)),
                )
              : IconButton(
                  icon: const Icon(Icons.save_rounded, color: Color(0xFFFFD700)),
                  onPressed: _save,
                  tooltip: 'حفظ',
                ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String emoji) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: '$emoji $label',
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 10.5),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      );
}

// ─── إعلانات الألبسة المعلّقة ──────────────────────────────────────────────────
class _GarmentListingsPendingPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingListingsProvider);
    return async.when(
      data: (listings) {
        if (listings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('لا توجد إعلانات معلّقة',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: listings.length,
          itemBuilder: (_, i) => _ListingAdminCard(listing: listings[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _ListingAdminCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  const _ListingAdminCard({required this.listing});

  @override
  State<_ListingAdminCard> createState() => _ListingAdminCardState();
}

class _ListingAdminCardState extends State<_ListingAdminCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      // owner_approve_garment_listing لم تُنشأ قط على الخادم — هذا
      // بالضبط سبب "أزرار الموافقة والرفض لا تعمل". الدالة الحيّة
      // admin_set_garment_service_ad_status تتحكّم بحالة garment_service_ads.
      await Supabase.instance.client.rpc(
          'admin_set_garment_service_ad_status',
          params: {'p_ad_id': widget.listing['id'], 'p_status': 'published'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'أدخل السبب...'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('رفض', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
          'admin_set_garment_service_ad_status',
          params: {'p_ad_id': widget.listing['id'], 'p_status': 'blocked'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l['title']?.toString() ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'القسم: ${l['category_key'] ?? '?'} • ${l['location'] ?? 'غير محدد'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            l['description']?.toString() ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'صاحب الإعلان: ${l['owner_name'] ?? '?'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _approve,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('موافقة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.2),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _reject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Widgets مساعدة ───────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final String emoji;
  final String value;
  const _Stat(this.emoji, this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      '$emoji $value',
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
