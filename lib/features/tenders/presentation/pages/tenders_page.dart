import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/media_upload_service.dart';
import '../providers/tenders_provider.dart';

/// ═══════════════════════════════════════════════════════════════
/// قسم المناقصات — مخصص للعضويات المدفوعة
/// مربوط بالخادم بالكامل، المالك يتحكم في كل شيء
/// ═══════════════════════════════════════════════════════════════
class TendersPage extends ConsumerStatefulWidget {
  const TendersPage({super.key});

  @override
  ConsumerState<TendersPage> createState() => _TendersPageState();
}

class _TendersPageState extends ConsumerState<TendersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _isOwner = false;

  static const _tabs = ['📋 نشطة', '✅ منتهية', '⏳ تقديماتي'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadOwnerFlag();
  }

  Future<void> _loadOwnerFlag() async {
    try {
      final r = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) setState(() => _isOwner = r == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D22),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🏗️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('المناقصات',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showOwnerSettings(),
              tooltip: 'إعدادات المالك',
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showPostTenderSheet(context),
            tooltip: 'نشر مناقصة',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TenderList(status: 'active', isOwner: _isOwner),
          _TenderList(status: 'closed', isOwner: _isOwner),
          const _MySubmissionsList(),
        ],
      ),
    );
  }

  void _showPostTenderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D22),
      builder: (_) => const _PostTenderSheet(),
    );
  }

  void _showOwnerSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D22),
      builder: (_) => const _TenderOwnerSettingsSheet(),
    );
  }
}

// ─── قائمة المناقصات ──────────────────────────────────────────────────────────
class _TenderList extends ConsumerWidget {
  final String status;
  final bool isOwner;
  const _TenderList({required this.status, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tendersAsync = ref.watch(tendersProvider(status));

    return tendersAsync.when(
      data: (tenders) {
        if (tenders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏗️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  status == 'active'
                      ? 'لا توجد مناقصات نشطة حالياً'
                      : 'لا توجد مناقصات منتهية',
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tenders.length,
          itemBuilder: (context, i) => _TenderCard(
            tender: tenders[i],
            isOwner: isOwner,
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(
          child: Text('خطأ: $e',
              style: const TextStyle(color: Colors.white38))),
    );
  }
}

// ─── بطاقة المناقصة ───────────────────────────────────────────────────────────
class _TenderCard extends ConsumerWidget {
  final Map<String, dynamic> tender;
  final bool isOwner;
  const _TenderCard({required this.tender, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadline = DateTime.tryParse(tender['deadline']?.toString() ?? '');
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final budgetMin = tender['budget_min'];
    final budgetMax = tender['budget_max'];

    return Card(
      color: const Color(0xFF12122A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: daysLeft != null && daysLeft <= 3
              ? Colors.orange.withValues(alpha: 0.6)
              : const Color(0xFF3A3A6A),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── نوع + عاجل ──────────────────────────────────
            Row(
              children: [
                _CategoryBadge(
                    category: tender['category']?.toString() ?? 'other'),
                const Spacer(),
                if (daysLeft != null && daysLeft <= 3)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      daysLeft == 0 ? '⚡ آخر يوم!' : '⚡ $daysLeft أيام',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isOwner) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white38, size: 18),
                    onPressed: () => _showOwnerMenu(context, ref),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ─── صاحب المناقصة ────────────────────────────────
            // بنفس مكوّن غرف الشات ليظهر الاسم موحّدًا في كل
            // المشروع، محمّلًا بألوان العضو وشاراته وألقابه.
            if ((tender['uid'] ?? tender['owner_uid']) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: ServerUsernameDisplay(
                        uid: (tender['uid'] ?? tender['owner_uid']).toString(),
                        fallbackName: 'عضو',
                        fallbackFontSize: 12.5,
                        showBadges: true,
                        compactBadges: true,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── العنوان ──────────────────────────────────────
            Text(
              tender['title']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // ─── الوصف ────────────────────────────────────────
            Text(
              tender['description']?.toString() ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // ─── التفاصيل ─────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (budgetMin != null || budgetMax != null)
                  _InfoChip(
                    icon: Icons.attach_money,
                    label: _budgetLabel(budgetMin, budgetMax),
                    color: const Color(0xFF4CAF50),
                  ),
                if (deadline != null)
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: _dateLabel(deadline),
                    color: daysLeft != null && daysLeft <= 3
                        ? Colors.orange
                        : Colors.white54,
                  ),
                if (tender['location'] != null)
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: tender['location'].toString(),
                    color: Colors.white54,
                  ),
                if (tender['quantity'] != null)
                  _InfoChip(
                    icon: Icons.production_quantity_limits_outlined,
                    label: 'الكمية: ${tender['quantity']}',
                    color: Colors.white54,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── أزرار التقديم والتفاصيل ─────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDetails(context, ref),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('التفاصيل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: tender['status'] == 'active'
                        ? () => _showSubmitSheet(context, ref)
                        : null,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('تقديم عرض'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _budgetLabel(dynamic min, dynamic max) {
    if (min != null && max != null) {
      return '$min - $max \$';
    } else if (min != null) {
      return 'من $min \$';
    } else if (max != null) {
      return 'حتى $max \$';
    }
    return 'بحسب العرض';
  }

  String _dateLabel(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D22),
      builder: (_) => _TenderDetailsSheet(tender: tender),
    );
  }

  void _showSubmitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D22),
      builder: (_) =>
          _SubmitBidSheet(tenderId: tender['id']?.toString() ?? ''),
    );
  }

  void _showOwnerMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D22),
      builder: (_) => _OwnerTenderMenu(tender: tender),
    );
  }
}

// ─── تفاصيل المناقصة ────────────────────────────────────────────────────────
class _TenderDetailsSheet extends ConsumerWidget {
  final Map<String, dynamic> tender;
  const _TenderDetailsSheet({required this.tender});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync =
        ref.watch(tenderSubmissionsProvider(tender['id']?.toString() ?? ''));
    final deadline = DateTime.tryParse(tender['deadline']?.toString() ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            // العنوان
            Text(
              tender['title']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // الوصف الكامل
            Text(
              tender['description']?.toString() ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),

            // متطلبات تفصيلية
            if (tender['requirements'] != null) ...[
              const Text('📋 المتطلبات:',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                tender['requirements'].toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],

            // معلومات جانبية
            _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'آخر موعد للتقديم',
                value: deadline != null
                    ? '${deadline.day}/${deadline.month}/${deadline.year}'
                    : '—'),
            _DetailRow(
                icon: Icons.attach_money,
                label: 'الميزانية',
                value:
                    '${tender['budget_min'] ?? '—'} - ${tender['budget_max'] ?? '—'} \$'),
            _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'الموقع',
                value: tender['location']?.toString() ?? '—'),
            _DetailRow(
                icon: Icons.inventory_2_outlined,
                label: 'الكمية',
                value: tender['quantity']?.toString() ?? '—'),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            // عدد العروض (للمالك)
            submissionsAsync.when(
              data: (subs) => Text(
                '📨 ${subs.length} عرض مُقدَّم',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── تقديم عرض ─────────────────────────────────────────────────────────────
class _SubmitBidSheet extends ConsumerStatefulWidget {
  final String tenderId;
  const _SubmitBidSheet({required this.tenderId});

  @override
  ConsumerState<_SubmitBidSheet> createState() => _SubmitBidSheetState();
}

class _SubmitBidSheetState extends ConsumerState<_SubmitBidSheet> {
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _sending = false;
  String? _attachmentUrl;
  String? _error;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final path = '$uid/bid_attachments/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final url = await MediaUploadService(bucket: 'media').uploadBytesAtPath(
        bytes: file.bytes!,
        fileName: file.name,
        path: path,
        contentType: 'application/octet-stream',
      );
      if (mounted) setState(() => _attachmentUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل رفع الملف: $e');
    }
  }

  Future<void> _submit() async {
    if (_priceCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال سعر العرض');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(tendersControllerProvider.notifier).submitBid(
            tenderId: widget.tenderId,
            price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
            note: _noteCtrl.text.trim(),
            deliveryDays: int.tryParse(_timeCtrl.text.trim()),
            attachmentUrl: _attachmentUrl,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('✅ تم تقديم عرضك بنجاح'),
            backgroundColor: Color(0xFF2D7A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('📨 تقديم عرض',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'سعر العرض (\$) *',
              labelStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.attach_money, color: Color(0xFFFFD700)),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _timeCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مدة التنفيذ (أيام)',
              labelStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.timer_outlined, color: Colors.white38),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'ملاحظات العرض',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _pickAttachment,
            icon: Icon(
              _attachmentUrl != null ? Icons.check_circle : Icons.attach_file,
              color: _attachmentUrl != null
                  ? const Color(0xFFFFD700)
                  : Colors.white54,
            ),
            label: Text(
              _attachmentUrl != null ? '✅ ملف مرفق' : 'إرفاق ملف (اختياري)',
              style: TextStyle(
                  color: _attachmentUrl != null
                      ? const Color(0xFFFFD700)
                      : Colors.white54),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'جارٍ التقديم...' : 'تقديم العرض'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ورقة نشر مناقصة جديدة ──────────────────────────────────────────────────
class _PostTenderSheet extends ConsumerStatefulWidget {
  const _PostTenderSheet();

  @override
  ConsumerState<_PostTenderSheet> createState() => _PostTenderSheetState();
}

class _PostTenderSheetState extends ConsumerState<_PostTenderSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _budMinCtrl = TextEditingController();
  final _budMaxCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  DateTime? _deadline;
  final String _category = 'garment';
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _reqCtrl,
      _budMinCtrl,
      _budMaxCtrl,
      _locationCtrl,
      _qtyCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          children: [
            const Text('🏗️ نشر مناقصة جديدة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _InputField(
                ctrl: _titleCtrl,
                label: 'عنوان المناقصة *',
                maxLength: 80),
            _InputField(
                ctrl: _descCtrl,
                label: 'وصف المناقصة *',
                maxLines: 4,
                maxLength: 600),
            _InputField(
                ctrl: _reqCtrl,
                label: 'المتطلبات التفصيلية',
                maxLines: 3,
                maxLength: 400),
            Row(
              children: [
                Expanded(
                    child: _InputField(
                        ctrl: _budMinCtrl,
                        label: 'الحد الأدنى (\$)',
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: _InputField(
                        ctrl: _budMaxCtrl,
                        label: 'الحد الأعلى (\$)',
                        keyboardType: TextInputType.number)),
              ],
            ),
            _InputField(ctrl: _locationCtrl, label: 'الموقع / المدينة'),
            _InputField(
                ctrl: _qtyCtrl,
                label: 'الكمية المطلوبة',
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today,
                  color: Color(0xFFFFD700)),
              title: Text(
                _deadline == null
                    ? 'تحديد آخر موعد للتقديم'
                    : 'الموعد النهائي: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _deadline = picked);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _posting ? null : _post,
              icon: _posting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.publish_rounded),
              label: Text(_posting ? 'جارٍ النشر...' : 'نشر المناقصة'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'العنوان والوصف مطلوبان');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await ref.read(tendersControllerProvider.notifier).postTender(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            requirements: _reqCtrl.text.trim(),
            budgetMin:
                double.tryParse(_budMinCtrl.text.trim()),
            budgetMax:
                double.tryParse(_budMaxCtrl.text.trim()),
            location: _locationCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim(),
            category: _category,
            deadline: _deadline,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('✅ تم نشر المناقصة بنجاح'),
            backgroundColor: Color(0xFF2D7A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

// ─── قائمة تقديماتي ──────────────────────────────────────────────────────────
class _MySubmissionsList extends ConsumerWidget {
  const _MySubmissionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(myBidsProvider);
    return subsAsync.when(
      data: (bids) {
        if (bids.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📨', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('لم تقدّم أي عروض بعد',
                    style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: bids.length,
          itemBuilder: (context, i) {
            final b = bids[i];
            return Card(
              color: const Color(0xFF12122A),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(b['status']?.toString())
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _statusIcon(b['status']?.toString()),
                    color: _statusColor(b['status']?.toString()),
                    size: 20,
                  ),
                ),
                title: Text(
                  b['tender_title']?.toString() ?? 'مناقصة',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  'عرضك: \$${b['price']} • ${_statusLabel(b['status']?.toString())}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => Center(
          child: Text('خطأ: $e',
              style: const TextStyle(color: Colors.white38))),
    );
  }

  Color _statusColor(String? s) {
    return switch (s) {
      'accepted' => const Color(0xFF4CAF50),
      'rejected' => Colors.red,
      'pending' => Colors.orange,
      _ => Colors.white38,
    };
  }

  IconData _statusIcon(String? s) {
    return switch (s) {
      'accepted' => Icons.check_circle_outline,
      'rejected' => Icons.cancel_outlined,
      'pending' => Icons.hourglass_top_outlined,
      _ => Icons.info_outline,
    };
  }

  String _statusLabel(String? s) {
    return switch (s) {
      'accepted' => 'مقبول ✅',
      'rejected' => 'مرفوض ❌',
      'pending' => 'قيد المراجعة ⏳',
      _ => 'غير محدد',
    };
  }
}

// ─── إعدادات مالك المنصة ─────────────────────────────────────────────────────
class _TenderOwnerSettingsSheet extends ConsumerWidget {
  const _TenderOwnerSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('⚙️ إعدادات المناقصات',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings,
                color: Color(0xFFFFD700)),
            title: const Text('عروض المناقصات',
                style: TextStyle(color: Colors.white)),

            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _AllSubmissionsAdminPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.toggle_on_outlined,
                color: Color(0xFFFFD700)),
            title: const Text('تفعيل/إيقاف المناقصات',
                style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AllSubmissionsAdminPage extends ConsumerWidget {
  const _AllSubmissionsAdminPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(allSubmissionsAdminProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D22),
        foregroundColor: Colors.white,
        title: const Text('📨 إدارة العروض'),
      ),
      body: subsAsync.when(
        data: (subs) => ListView.builder(
          itemCount: subs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, i) {
            final s = subs[i];
            return Card(
              color: const Color(0xFF12122A),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${s['username'] ?? 'مستخدم'} — \$${s['price']}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(s['note']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50)),
                      onPressed: () =>
                          ref.read(tendersControllerProvider.notifier)
                              .moderateBid(
                                  bidId: s['id']?.toString() ?? '',
                                  accept: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () =>
                          ref.read(tendersControllerProvider.notifier)
                              .moderateBid(
                                  bidId: s['id']?.toString() ?? '',
                                  accept: false),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white38))),
      ),
    );
  }
}

// ─── أدوات مشتركة ─────────────────────────────────────────────────────────────
class _OwnerTenderMenu extends ConsumerWidget {
  final Map<String, dynamic> tender;
  const _OwnerTenderMenu({required this.tender});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.close_rounded, color: Colors.orange),
            title: const Text('إغلاق المناقصة',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              ref
                  .read(tendersControllerProvider.notifier)
                  .closeTender(tender['id']?.toString() ?? '');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('حذف المناقصة',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              ref
                  .read(tendersControllerProvider.notifier)
                  .deleteTender(tender['id']?.toString() ?? '');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A6A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(category),
        style: const TextStyle(
            color: Color(0xFFB39DDB),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  String _label(String c) {
    const map = {
      'garment': 'ألبسة 👗',
      'fabric': 'أقمشة 🧵',
      'packaging': 'أمبلاج 📦',
      'printing': 'طباعة 🖨️',
      'other': 'أخرى',
    };
    return map[c] ?? c;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  const _InputField({
    required this.ctrl,
    required this.label,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white12)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFD700))),
          counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ),
    );
  }
}
