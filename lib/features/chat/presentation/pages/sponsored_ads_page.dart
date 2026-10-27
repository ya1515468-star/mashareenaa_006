import 'dart:typed_data';
import '../../../../core/error/failure_text.dart';
import 'dart:async';
import '../../../../core/services/snack_sfx.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';

/// الإعلانات الممولة.
///
/// العضو يختار الفئة ثم **المدّة** (١٠ أيام، شهر، ٣ أشهر، سنة… كما
/// يضبطها المالك) ثم عملة الدفع، فيُخصم السعر ويُنشَر الإعلان بتاريخ
/// انتهاء محسوب على الخادم.
///
/// القراءة خادمية: جدول sponsored_ads لم يبقَ مقروءًا من العميل. كان
/// العميل يقرأ كل الإعلانات ويُرشِّح الاستهداف محليًّا — أي أنّ أيّ
/// عميل كان يرى إعلانات غيره المستهدَفة ويعرض ما يشاء بلا احتساب
/// ظهور. الآن list_sponsored_ads للدليل وad_serve للظهور المدفوع.
class SponsoredAdsPage extends ConsumerStatefulWidget {
  const SponsoredAdsPage({super.key});
  @override
  ConsumerState<SponsoredAdsPage> createState() => _SponsoredAdsPageState();
}

class _SponsoredAdsPageState extends ConsumerState<SponsoredAdsPage> {
  final _db = Supabase.instance.client;
  bool _isOwner = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  static List<Map<String, dynamic>> _asRows(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final owner = await _db.rpc('is_my_platform_owner');
      final cats = await _db
          .from('sponsored_ad_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      final ads = await _db.rpc('list_sponsored_ads', params: {'p_limit': 120});
      if (!mounted) return;
      setState(() {
        _isOwner = owner == true;
        _categories = _asRows(cats);
        _ads = _asRows(ads);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureText.of(e);
        _loading = false;
      });
    }
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => _CategoryManagerSheet(onChanged: _load),
    );
  }

  // ── النشر ────────────────────────────────────────────────────────
  Future<void> _create() async {
    await _load();
    if (!mounted) return;
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('لا توجد فئات إعلانات متاحة بعد.')));
      return;
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => _PublishSheet(categories: _categories),
    );
    if (result == null || !mounted) return;

    final m = ScaffoldMessenger.of(context);
    try {
      String? imageUrl;
      final bytes = result['bytes'] as Uint8List?;
      final uid = _db.auth.currentUser?.id;
      if (bytes != null && uid != null) {
        imageUrl = await MediaUploadService(bucket: 'media').uploadBytes(
          bytes: bytes,
          fileName: result['name'] as String? ?? 'ad.jpg',
          folder: 'sponsored_ads',
          uid: uid,
        );
      }
      // request_id يُولَّد مرّة واحدة لهذه المحاولة: إعادة النداء بعد
      // انقطاع شبكة لا تخصم مرّتين.
      final res = await _db.rpc('publish_sponsored_ad_with_plan', params: {
        'p_category_key': result['category'],
        'p_plan_id': result['plan_id'],
        'p_text': result['text'],
        'p_image_url': imageUrl,
        'p_currency': result['currency'],
        'p_request_id': result['request_id'],
      });
      final days = res is Map ? _n(res['days']) : 0;
      m.showSnackBarSfx(SnackBar(
        content: Text('تم نشر الإعلان ✓  لمدّة $days يومًا'),
        backgroundColor: const Color(0xFF16A34A),
      ));
      await _load();
    } catch (e) {
      final t = e.toString();
      m.showSnackBarSfx(SnackBar(
        content: Text(
          t.contains('INSUFFICIENT_GEMS')
              ? 'رصيدك من الجواهر لا يكفي لهذه المدّة.'
              : t.contains('INSUFFICIENT_POINTS')
                  ? 'رصيدك من النقاط لا يكفي لهذه المدّة.'
                  : t.contains('DUPLICATE_REQUEST')
                      ? 'هذا الإعلان نُشر بالفعل.'
                      : t.contains('INVALID_PLAN')
                          ? 'هذه المدّة لم تبقَ متاحة — أعد الاختيار.'
                          : t.contains('AD_TEXT_TOO_LONG')
                              ? 'نص الإعلان أطول من 500 حرف.'
                              : FailureText.of(e),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعلانات الممولة — مشاريعنا'),
        actions: [
          if (_isOwner)
            IconButton(
                tooltip: 'إدارة الفئات والأسعار',
                onPressed: _manageCategories,
                icon: const Icon(Icons.admin_panel_settings_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('نشر إعلان'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('تعذّر تحميل الإعلانات:\n$_error',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton(
                        onPressed: _load, child: const Text('إعادة')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _ads.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('لا توجد إعلانات ممولة حاليًا')),
                        ])
                      : _buildList(),
                ),
    );
  }

  Widget _buildList() {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final r in _ads) {
      final key = r['category_key']?.toString() ?? 'بلا فئة';
      byCategory.putIfAbsent(key, () => []).add(r);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in byCategory.entries) ...[
          _categoryHeader(entry.key),
          const SizedBox(height: 6),
          for (final ad in entry.value) _adCard(ad),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> ad) {
    final mine = ad['is_mine'] == true;
    final paused = ad['paused'] == true;
    final expired = ad['expired'] == true;
    final capped = ad['capped'] == true;
    final dim = mine && (paused || expired || capped);

    return Opacity(
      opacity: dim ? .55 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: mine
                ? AppColors.gold.withValues(alpha: .75)
                : AppColors.gold.withValues(alpha: .3),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((ad['author_uid']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ServerUsernameDisplay(
                uid: ad['author_uid'].toString(),
                fallbackName: 'عضو',
                fallbackFontSize: 13,
                showBadges: true,
                compactBadges: true,
              ),
            ),
          if ((ad['image_url']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(ad['image_url'].toString(),
                    height: 150, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Text(ad['text']?.toString() ?? '',
              style: const TextStyle(color: Colors.white)),
          // صاحب الإعلان وحده يرى أداءه وحالته — لا الآخرون.
          if (mine) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 6),
            Text(
              [
                'إعلانك',
                '${_n(ad['impressions'])}'
                    '${_n(ad['cap']) > 0 ? '/${_n(ad['cap'])}' : ''} ظهور',
                '${_n(ad['clicks'])} نقرة',
                if (expired) 'انتهت مدّته'
                else if (paused) 'موقوف من الإدارة'
                else if (capped) 'بلغ سقف الظهور'
                else if (ad['ends_at'] != null) _remaining(ad['ends_at']),
              ].join('  ·  '),
              style: const TextStyle(color: AppColors.gold, fontSize: 11),
            ),
          ],
        ]),
      ),
    );
  }

  static String _remaining(Object? endsAt) {
    final t = DateTime.tryParse('$endsAt');
    if (t == null) return '';
    final d = t.difference(DateTime.now());
    if (d.isNegative) return 'انتهت مدّته';
    if (d.inDays >= 1) return 'يبقى ${d.inDays} يومًا';
    return 'يبقى ${d.inHours} ساعة';
  }

  Widget _categoryHeader(String key) {
    final cat = _categories.where((c) => c['category_key'] == key).firstOrNull;
    final label = cat == null ? key : '${cat['emoji']} ${cat['label_ar']}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w900)),
    );
  }
}

/// ورقة النشر: فئة ← مدّة ← عملة ← نص وصورة.
///
/// الأسعار تُجلَب من الخادم لكل فئة على حدة لأنّ المالك قد يضع فارق
/// سعر لفئة بعينها — فعرض سعر المدّة وحده يجعل الخصم مفاجأة.
class _PublishSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  const _PublishSheet({required this.categories});
  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  final _db = Supabase.instance.client;
  final _text = TextEditingController();
  late final String _requestId;

  String? _category;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _plan;
  String? _currency;
  bool _loadingPlans = false;
  String? _planError;
  Uint8List? _bytes;
  String? _name;

  @override
  void initState() {
    super.initState();
    // يُولَّد مرّة لكل فتح للورقة: ضمانة ألّا يُحصَّل الطلب مرّتين.
    _requestId = const Uuid().v4();
    if (widget.categories.length == 1) {
      _category = widget.categories.first['category_key']?.toString();
      unawaited(_loadPlans());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _loadPlans() async {
    setState(() {
      _loadingPlans = true;
      _planError = null;
      _plans = [];
      _plan = null;
      _currency = null;
    });
    try {
      final raw = await _db.rpc('get_ad_duration_plans',
          params: {'p_category_key': _category});
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _plans = rows;
        _loadingPlans = false;
        if (rows.length == 1) _pick(rows.first, notify: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _planError = FailureText.of(e);
        _loadingPlans = false;
      });
    }
  }

  void _pick(Map<String, dynamic> p, {bool notify = true}) {
    _plan = p;
    // العملة الافتراضية: النقاط إن كانت المدّة مسعَّرة بها — فهي ما
    // يجمعه العضو بالاستخدام، فلا تُستهلك جواهره المدفوعة بلا اختياره.
    _currency = _n(p['points']) > 0 ? 'points' : 'gems';
    if (notify) setState(() {});
  }

  String _priceLabel(Map<String, dynamic> p) {
    final parts = <String>[
      if (_n(p['points']) > 0) '⭐ ${_n(p['points'])}',
      if (_n(p['gems']) > 0) '💎 ${_n(p['gems'])}',
    ];
    return parts.isEmpty ? '—' : parts.join(' أو ');
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = _category != null &&
        _plan != null &&
        _currency != null &&
        _text.text.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إعلان ممول جديد',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),

                const _StepLabel('١', 'الفئة'),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in widget.categories)
                    ChoiceChip(
                      label: Text('${c['emoji']} ${c['label_ar']}'),
                      selected: _category == c['category_key'],
                      onSelected: (_) {
                        setState(() =>
                            _category = c['category_key'].toString());
                        unawaited(_loadPlans());
                      },
                    ),
                ]),

                if (_category != null) ...[
                  const SizedBox(height: 16),
                  const _StepLabel('٢', 'مدّة الظهور'),
                  const SizedBox(height: 6),
                  if (_loadingPlans)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (_planError != null)
                    Row(children: [
                      Expanded(
                        child: Text('تعذّر جلب المُدد: $_planError',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                          onPressed: _loadPlans, child: const Text('إعادة')),
                    ])
                  else if (_plans.isEmpty)
                    const Text('لا توجد مُدد متاحة لهذه الفئة بعد.',
                        style: TextStyle(color: Colors.white54, fontSize: 12))
                  else
                    Column(
                      children: [
                        for (final p in _plans)
                          _PlanRow(
                            label: '${p['label']}',
                            days: _n(p['days']),
                            price: _priceLabel(p),
                            cap: _n(p['impression_cap']),
                            selected: _plan?['id'] == p['id'],
                            onTap: () => _pick(p),
                          ),
                      ],
                    ),
                ],

                if (_plan != null) ...[
                  const SizedBox(height: 16),
                  const _StepLabel('٣', 'الدفع'),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    if (_n(_plan!['points']) > 0)
                      ChoiceChip(
                        label: Text('⭐ ${_n(_plan!['points'])} نقطة'),
                        selected: _currency == 'points',
                        onSelected: (_) =>
                            setState(() => _currency = 'points'),
                      ),
                    if (_n(_plan!['gems']) > 0)
                      ChoiceChip(
                        label: Text('💎 ${_n(_plan!['gems'])} جوهرة'),
                        selected: _currency == 'gems',
                        onSelected: (_) => setState(() => _currency = 'gems'),
                      ),
                  ]),
                ],

                const SizedBox(height: 16),
                const _StepLabel('٤', 'الإعلان'),
                const SizedBox(height: 6),
                TextField(
                  controller: _text,
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'نص الإعلان', border: OutlineInputBorder()),
                ),
                Row(children: [
                  if (_bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_bytes!,
                          width: 56, height: 56, fit: BoxFit.cover),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked == null) return;
                      final b = await picked.readAsBytes();
                      if (!mounted) return;
                      setState(() {
                        _bytes = b;
                        _name = picked.name;
                      });
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(
                        _bytes == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة'),
                  ),
                ]),

                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: canPublish
                          ? () => Navigator.pop(context, {
                                'category': _category,
                                'plan_id': _plan!['id'],
                                'text': _text.text.trim(),
                                'currency': _currency,
                                'request_id': _requestId,
                                'bytes': _bytes,
                                'name': _name,
                              })
                          : null,
                      child: Text(_plan == null
                          ? 'نشر'
                          : 'نشر لمدّة ${_n(_plan!['days'])} يومًا'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String n;
  final String text;
  const _StepLabel(this.n, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.gold, shape: BoxShape.circle),
          child: Text(n,
              style: const TextStyle(
                  color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ]);
}

class _PlanRow extends StatelessWidget {
  final String label;
  final int days;
  final String price;
  final int cap;
  final bool selected;
  final VoidCallback onTap;
  const _PlanRow({
    required this.label,
    required this.days,
    required this.price,
    required this.cap,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.gold.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .04),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: .12),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18, color: selected ? AppColors.gold : Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              Text(
                cap > 0 ? '$days يومًا · حتى $cap ظهور' : '$days يومًا · ظهور بلا سقف',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ]),
          ),
          Text(price,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

/// إدارة فئات الإعلانات للمالك: إضافة، تعديل فارق السعر، حذف.
class _CategoryManagerSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _CategoryManagerSheet({required this.onChanged});
  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rows = await Supabase.instance.client
        .from('sponsored_ad_categories')
        .select()
        .order('sort_order');
    if (mounted) {
      setState(() {
        _all = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? c]) async {
    final key = TextEditingController(text: c?['category_key']?.toString() ?? '');
    final emoji = TextEditingController(text: c?['emoji']?.toString() ?? '🧵');
    final label = TextEditingController(text: c?['label_ar']?.toString() ?? '');
    final gems = TextEditingController(text: '${c?['gems_cost'] ?? 0}');
    final points = TextEditingController(text: '${c?['points_cost'] ?? 0}');
    var active = c?['is_active'] != false;
    final m = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(c == null ? 'فئة جديدة' : 'تعديل الفئة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: key, enabled: c == null,
                  decoration: const InputDecoration(
                      labelText: 'المعرّف (إنجليزي، مثل tailoring)')),
              TextField(controller: emoji,
                  decoration: const InputDecoration(labelText: 'الرمز (إيموجي)')),
              TextField(controller: label,
                  decoration: const InputDecoration(labelText: 'الاسم الظاهر')),
              const SizedBox(height: 8),
              const Text(
                'السعر هنا فارق يُضاف فوق سعر المدّة التي يختارها العضو. '
                'صفر = سعر المدّة وحده.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              Row(children: [
                Expanded(child: TextField(controller: points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'فارق نقاط ⭐'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: gems,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'فارق جواهر 💎'))),
              ]),
              SwitchListTile(value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('مفعّلة')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await Supabase.instance.client
            .rpc('owner_upsert_sponsored_ad_category', params: {
          'p_category_key': key.text.trim(),
          'p_emoji': emoji.text.trim(),
          'p_label_ar': label.text.trim(),
          'p_points_cost': int.tryParse(points.text.trim()) ?? 0,
          'p_gems_cost': int.tryParse(gems.text.trim()) ?? 0,
          'p_is_active': active,
        });
        await _load();
        widget.onChanged();
      } catch (e) {
        m?.showSnackBarSfx(SnackBar(content: Text(FailureText.action(e, action: 'الحفظ'))));
      }
    }
  }

  Future<void> _delete(String key) async {
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client
          .rpc('owner_delete_sponsored_ad_category', params: {'p_category_key': key});
      await _load();
      widget.onChanged();
    } catch (e) {
      m?.showSnackBarSfx(SnackBar(content: Text(FailureText.action(e, action: 'الحذف'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(
                  child: Text('فئات الإعلانات الممولة',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => _edit(),
                  icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700))),
            ]),
            const Divider(color: Colors.white24),
            if (_loading)
              const Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator())
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in _all)
                    ListTile(
                      leading: Text(c['emoji']?.toString() ?? '🧵',
                          style: const TextStyle(fontSize: 20)),
                      title: Text(c['label_ar']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        (((c['gems_cost'] as num?) ?? 0) == 0 &&
                                ((c['points_cost'] as num?) ?? 0) == 0)
                            ? 'بلا فارق سعر'
                            : '+⭐ ${c['points_cost'] ?? 0}  ·  +💎 ${c['gems_cost'] ?? 0}'
                                '${c['is_active'] == false ? ' — معطّلة' : ''}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white54, size: 18),
                            onPressed: () => _edit(c)),
                        IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent, size: 18),
                            onPressed: () =>
                                _delete(c['category_key'].toString())),
                      ]),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
