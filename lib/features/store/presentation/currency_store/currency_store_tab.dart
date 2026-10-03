import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'currency_packages_provider.dart';
import 'currency_purchase_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// متجر النقاط والجواهر — قسم داخل متجر الشات
/// المالك يتحكم: الأسعار، الكميات، الأيقونات، طريقة العرض
/// ═══════════════════════════════════════════════════════════════════
class CurrencyStoreTab extends ConsumerStatefulWidget {
  const CurrencyStoreTab({super.key});

  @override
  ConsumerState<CurrencyStoreTab> createState() => _CurrencyStoreTabState();
}

class _CurrencyStoreTabState extends ConsumerState<CurrencyStoreTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      final r = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) setState(() => _isOwner = r == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // رأس القسم
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const _ShimmerCurrencyIcon(emoji: '⭐', color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متجر النقاط والجواهر',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('اشحن رصيدك، انطلق في التفاعل',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              if (_isOwner)
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded,
                      color: Color(0xFFFFD700)),
                  onPressed: () => _showAddPackageSheet(),
                  tooltip: 'إضافة باقة جديدة',
                ),
            ],
          ),
        ),

        // تبويبات نقاط / جواهر
        TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFFFD700),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('نقاط'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💎', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('جواهر'),
                ],
              ),
            ),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _PackagesGrid(type: 'points', isOwner: _isOwner),
              _PackagesGrid(type: 'gems',   isOwner: _isOwner),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddPackageSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageEditorSheet(existing: existing),
    );
  }
}

// ─── شبكة الباقات ──────────────────────────────────────────────────
class _PackagesGrid extends ConsumerWidget {
  final String type;
  final bool isOwner;
  const _PackagesGrid({required this.type, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currencyPackagesProvider(type));
    return async.when(
      data: (pkgs) {
        if (pkgs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(type == 'points' ? '⭐' : '💎',
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'لا توجد باقات ${type == 'points' ? 'نقاط' : 'جواهر'} بعد',
                  style: const TextStyle(color: Colors.white54),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text('+ أضف باقة',
                        style: TextStyle(color: Color(0xFFFFD700))),
                  ),
                ],
              ],
            ),
          );
        }

        // الباقة المميزة أولاً
        final featured = pkgs.where((p) => p['is_featured'] == true).toList();
        final regular  = pkgs.where((p) => p['is_featured'] != true).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (featured.isNotEmpty) ...[
              ...featured.map((p) => _FeaturedPackageCard(
                    package: p,
                    type: type,
                    isOwner: isOwner,
                  )),
              const SizedBox(height: 8),
            ],
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: regular.length,
              itemBuilder: (_, i) => _PackageCard(
                package: regular[i],
                type: type,
                isOwner: isOwner,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      ),
      error: (e, _) =>
          Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

// ─── بطاقة باقة مميزة (بانر) ────────────────────────────────────────
class _FeaturedPackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final String type;
  final bool isOwner;
  const _FeaturedPackageCard({
    required this.package,
    required this.type,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final isPoints = type == 'points';
    final color1   = isPoints ? const Color(0xFFFFD700) : const Color(0xFF6C63FF);
    final color2   = isPoints ? const Color(0xFFFFA500) : const Color(0xFF00D4FF);

    return GestureDetector(
      onTap: () => _buy(context),
      onLongPress: isOwner ? () => _edit(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color1.withValues(alpha: 0.3), color2.withValues(alpha: 0.15)],
          ),
          border: Border.all(color: color1.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [BoxShadow(color: color1.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // الأيقونة
              _PackageIcon(iconUrl: package['icon_url'], type: type, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (package['badge_label'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          package['badge_label'],
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      package['name']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_fmt(package['amount'])} ${isPoints ? 'نقطة' : 'جوهرة'}',
                      style: TextStyle(color: color1, fontSize: 13),
                    ),
                    if ((package['bonus_amount'] ?? 0) > 0)
                      Text(
                        '+ ${_fmt(package['bonus_amount'])} مكافأة',
                        style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    package['price_display']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('اشتر',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context) async {
    HapticFeedback.lightImpact();
    await CurrencyStorePurchaseFlow.run(context, package);
  }

  void _edit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageEditorSheet(existing: package),
    );
  }

  String _fmt(dynamic v) =>
      v == null ? '0' : v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─── بطاقة باقة عادية ───────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final String type;
  final bool isOwner;
  const _PackageCard({
    required this.package,
    required this.type,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final isPoints = type == 'points';
    final accent   = isPoints ? const Color(0xFFFFD700) : const Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        CurrencyStorePurchaseFlow.run(context, package);
      },
      onLongPress: isOwner
          ? () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _PackageEditorSheet(existing: package),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF111122),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشارة
            if (package['badge_label'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  package['badge_label'],
                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            // الأيقونة
            _PackageIcon(iconUrl: package['icon_url'], type: type, size: 44),
            const SizedBox(height: 8),
            // الكمية
            Text(
              _fmt(package['amount']),
              style: TextStyle(
                  color: accent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              isPoints ? 'نقطة' : 'جوهرة',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            if ((package['bonus_amount'] ?? 0) > 0)
              Text(
                '+ ${_fmt(package['bonus_amount'])}',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
              ),
            const SizedBox(height: 6),
            // السعر
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  package['price_display']?.toString() ?? '',
                  style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) =>
      v == null ? '0' : v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─── أيقونة الباقة ───────────────────────────────────────────────────
class _PackageIcon extends StatelessWidget {
  final String? iconUrl;
  final String type;
  final double size;
  const _PackageIcon({this.iconUrl, required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: iconUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _defaultIcon(),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() => Text(
    type == 'points' ? '⭐' : '💎',
    style: TextStyle(fontSize: size * 0.8),
  );
}

// ─── شيمر ─────────────────────────────────────────────────────────────
class _ShimmerCurrencyIcon extends StatefulWidget {
  final String emoji;
  final Color color;
  const _ShimmerCurrencyIcon({required this.emoji, required this.color});

  @override
  State<_ShimmerCurrencyIcon> createState() => _ShimmerCurrencyIconState();
}

class _ShimmerCurrencyIconState extends State<_ShimmerCurrencyIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: math.sin(_ctrl.value * 2 * math.pi) * 0.1,
        child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

// ─── ورقة تعديل/إضافة باقة (المالك) ────────────────────────────────
class _PackageEditorSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const _PackageEditorSheet({this.existing});

  @override
  ConsumerState<_PackageEditorSheet> createState() => _PackageEditorSheetState();
}

class _PackageEditorSheetState extends ConsumerState<_PackageEditorSheet> {
  final _nameCtrl     = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _amountCtrl   = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _displayCtrl  = TextEditingController();
  final _badgeCtrl    = TextEditingController();
  final _bonusCtrl    = TextEditingController(text: '0');
  final _iconCtrl     = TextEditingController();
  final _sortCtrl     = TextEditingController(text: '0');

  String _type        = 'points';
  String _style       = 'card';
  bool   _featured    = false;
  bool   _active      = true;
  bool   _busy        = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text    = e['name']?.toString() ?? '';
      _descCtrl.text    = e['description']?.toString() ?? '';
      _amountCtrl.text  = e['amount']?.toString() ?? '';
      _priceCtrl.text   = e['price_usd']?.toString() ?? '';
      _displayCtrl.text = e['price_display']?.toString() ?? '';
      _badgeCtrl.text   = e['badge_label']?.toString() ?? '';
      _bonusCtrl.text   = e['bonus_amount']?.toString() ?? '0';
      _iconCtrl.text    = e['icon_url']?.toString() ?? '';
      _sortCtrl.text    = e['sort_order']?.toString() ?? '0';
      _type             = e['currency_type']?.toString() ?? 'points';
      _style            = e['display_style']?.toString() ?? 'card';
      _featured         = e['is_featured'] == true;
      _active           = e['is_active'] != false;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _amountCtrl, _priceCtrl,
        _displayCtrl, _badgeCtrl, _bonusCtrl, _iconCtrl, _sortCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final ctrl = ref.read(currencyStoreControllerProvider);
      await ctrl.upsertPackage(
        id:            widget.existing?['id'],
        currencyType:  _type,
        name:          _nameCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        amount:        int.tryParse(_amountCtrl.text) ?? 0,
        priceUsd:      double.tryParse(_priceCtrl.text) ?? 0,
        priceDisplay:  _displayCtrl.text.trim(),
        iconUrl:       _iconCtrl.text.trim().isEmpty ? null : _iconCtrl.text.trim(),
        badgeLabel:    _badgeCtrl.text.trim().isEmpty ? null : _badgeCtrl.text.trim(),
        isFeatured:    _featured,
        sortOrder:     int.tryParse(_sortCtrl.text) ?? 0,
        isActive:      _active,
        displayStyle:  _style,
        bonusAmount:   int.tryParse(_bonusCtrl.text) ?? 0,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الباقة'),
        content: const Text('هل تريد حذف هذه الباقة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(currencyStoreControllerProvider).deletePackage(widget.existing!['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF111122),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.existing != null ? 'تعديل الباقة' : 'باقة جديدة',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.existing != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _delete,
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // نوع العملة
                  Row(
                    children: [
                      Expanded(
                        child: _TypeBtn(
                          label: '⭐ نقاط',
                          selected: _type == 'points',
                          onTap: () => setState(() => _type = 'points'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeBtn(
                          label: '💎 جواهر',
                          selected: _type == 'gems',
                          onTap: () => setState(() => _type = 'gems'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(_nameCtrl,    'اسم الباقة *',    Icons.label_rounded),
                  const SizedBox(height: 10),
                  _field(_descCtrl,    'الوصف',           Icons.description_rounded, maxLines: 2),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_amountCtrl, 'الكمية *', Icons.numbers_rounded, num: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(_bonusCtrl, 'مكافأة', Icons.add_circle_outline_rounded, num: true)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_priceCtrl,   'السعر (USD)',  Icons.attach_money_rounded, num: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(_displayCtrl, 'عرض السعر',   Icons.sell_rounded)),
                  ]),
                  const SizedBox(height: 10),
                  _field(_badgeCtrl, 'شارة (مثال: الأوفر)', Icons.star_rounded),
                  const SizedBox(height: 10),
                  _field(_iconCtrl, 'رابط الأيقونة (URL)', Icons.image_rounded),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_sortCtrl, 'ترتيب العرض', Icons.sort_rounded, num: true)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _style,
                        dropdownColor: const Color(0xFF1A1A2E),
                        decoration: _inputDeco('نمط العرض', Icons.view_agenda_rounded),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'card',    child: Text('بطاقة')),
                          DropdownMenuItem(value: 'banner',  child: Text('بانر')),
                          DropdownMenuItem(value: 'compact', child: Text('مضغوط')),
                        ],
                        onChanged: (v) => setState(() => _style = v ?? 'card'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Switch(
                        value: _featured,
                        activeThumbColor: const Color(0xFFFFD700),
                        onChanged: (v) => setState(() => _featured = v),
                      ),
                      const Text('مميز (يظهر أولاً بحجم كبير)',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      Switch(
                        value: _active,
                        activeThumbColor: Colors.green,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                      const Text('مفعّل',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black)
                    : Text(
                        widget.existing != null ? 'حفظ التعديلات' : 'إضافة الباقة',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, bool num = false}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: num ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
    prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFFD700)),
    ),
  );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? const Color(0xFFFFD700).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFD700) : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// تدفّق الشراء المشترك بين بطاقة الباقة الكبيرة والبطاقة المدمجة.
// يعرض تأكيدًا يبيّن ما سيُخصم وما سيُضاف، ثم ينادي الخادم، ثم يُحدّث
// المحافظ في الواجهة. لا حساب مالي هنا إطلاقًا — الخادم هو المرجع.
// ═══════════════════════════════════════════════════════════════════
class CurrencyStorePurchaseFlow {
  const CurrencyStorePurchaseFlow._();

  static Future<void> run(
      BuildContext context, Map<String, dynamic> package) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final isPoints = (package['currency_type']?.toString() ?? 'points') == 'points';
    final label = isPoints ? 'نقطة' : 'جوهرة';
    final amount = (package['amount'] as num?)?.toInt() ?? 0;
    final bonus = (package['bonus_amount'] as num?)?.toInt() ?? 0;
    final total = amount + bonus;
    final priceText = package['price_display']?.toString().trim().isNotEmpty == true
        ? package['price_display'].toString()
        : '\$${package['price_usd'] ?? 0}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(package['name']?.toString() ?? 'شراء باقة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isPoints ? '⭐ $total $label' : '💎 $total $label',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900)),
              if (bonus > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('يشمل $bonus $label هدية',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF34D399))),
                ),
              const SizedBox(height: 12),
              Text('السعر: $priceText',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              const Text('يُخصم من رصيد شام كاش.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white54)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد الشراء')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    messenger?.showSnackBar(const SnackBar(
        content: Text('جارٍ تنفيذ الشراء…'),
        duration: Duration(seconds: 2)));

    final result = await CurrencyPurchaseService.purchase(
        packageId: package['id'].toString());

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(result.ok ? result.successMessage : (result.error ?? '')),
      backgroundColor:
          result.ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      duration: const Duration(seconds: 3),
    ));
  }
}
