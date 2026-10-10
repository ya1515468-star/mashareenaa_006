import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/media_upload_service.dart';
import '../providers/external_requests_provider.dart';

/// ═══════════════════════════════════════════════════════════════
/// الطلبات الخارجية — مخصصة لطلبات خارج سوريا
/// نفس منطق المناقصات لكن موجهة للسوق الدولي
/// خادمي بالكامل، المالك يتحكم في كل شيء
/// ═══════════════════════════════════════════════════════════════
class ExternalRequestsPage extends ConsumerStatefulWidget {
  const ExternalRequestsPage({super.key});

  @override
  ConsumerState<ExternalRequestsPage> createState() =>
      _ExternalRequestsPageState();
}

class _ExternalRequestsPageState extends ConsumerState<ExternalRequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _isOwner = false;

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
      backgroundColor: const Color(0xFF060814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1E),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🌍', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الطلبات الخارجية',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('طلبات خارج سوريا',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: _showOwnerSettings,
              tooltip: 'إعدادات المالك',
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showPostSheet(),
            tooltip: 'نشر طلب',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF64B5F6),
          labelColor: const Color(0xFF64B5F6),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '🌐 نشطة'),
            Tab(text: '✅ منجزة'),
            Tab(text: '📋 طلباتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ExternalRequestList(status: 'active', isOwner: _isOwner),
          _ExternalRequestList(status: 'completed', isOwner: _isOwner),
          const _MyExternalRequestsList(),
        ],
      ),
    );
  }

  void _showPostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0D1E),
      builder: (_) => const _PostExternalRequestSheet(),
    );
  }

  void _showOwnerSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0D1E),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚙️ إعدادات الطلبات الخارجية',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) => ListTile(
                leading:
                    const Icon(Icons.list_alt, color: Color(0xFF64B5F6)),
                title: const Text('مراجعة الطلبات والردود',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const _AllExternalBidsAdminPage()),
                  );
                },
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.security, color: Color(0xFF64B5F6)),
              title: const Text('إعدادات الأهلية والعضوية',
                  style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

// ─── قائمة الطلبات ───────────────────────────────────────────────────────────
class _ExternalRequestList extends ConsumerWidget {
  final String status;
  final bool isOwner;
  const _ExternalRequestList(
      {required this.status, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqAsync = ref.watch(externalRequestsProvider(status));

    return reqAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌍', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  status == 'active'
                      ? 'لا توجد طلبات خارجية نشطة'
                      : 'لا توجد طلبات منجزة',
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, i) => _ExternalRequestCard(
            request: requests[i],
            isOwner: isOwner,
          ),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF64B5F6))),
      error: (e, _) => Center(
          child: Text('$e',
              style: const TextStyle(color: Colors.white38))),
    );
  }
}

// ─── بطاقة الطلب الخارجي ─────────────────────────────────────────────────────
class _ExternalRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isOwner;
  const _ExternalRequestCard(
      {required this.request, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final targetCountry = request['target_country']?.toString() ?? '';
    final deliveryPort = request['delivery_port']?.toString() ?? '';
    final incoterms = request['incoterms']?.toString() ?? '';
    final paymentTerms = request['payment_terms']?.toString() ?? '';

    return Card(
      color: const Color(0xFF0E1228),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── رأس البطاقة ─────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A5A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🌍 $targetCountry',
                    style: const TextStyle(
                        color: Color(0xFF64B5F6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (incoterms.isNotEmpty)
                  Text(
                    incoterms,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── صاحب الطلب ───────────────────────────────────
            // مكوّن الاسم الموحّد نفسه المستخدم في غرف الشات.
            if (request['uid'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: ServerUsernameDisplay(
                        uid: request['uid'].toString(),
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
              request['title']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // ─── الوصف ────────────────────────────────────────
            Text(
              request['description']?.toString() ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // ─── التفاصيل التجارية الدولية ────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (request['quantity'] != null)
                  _ExtInfoChip(
                      label: '📦 ${request['quantity']}',
                      color: Colors.white60),
                if (request['unit'] != null)
                  _ExtInfoChip(
                      label: '⚖️ ${request['unit']}',
                      color: Colors.white60),
                if (deliveryPort.isNotEmpty)
                  _ExtInfoChip(
                      label: '🚢 $deliveryPort',
                      color: const Color(0xFF64B5F6)),
                if (paymentTerms.isNotEmpty)
                  _ExtInfoChip(
                      label: '💳 $paymentTerms',
                      color: const Color(0xFF81C784)),
                if (request['certification'] != null)
                  _ExtInfoChip(
                      label: '📜 ${request['certification']}',
                      color: const Color(0xFFFFD700)),
              ],
            ),

            if (request['sample_required'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Text('⚠️ يتطلب عينة قبل الطلب',
                    style: TextStyle(color: Colors.orange, fontSize: 11)),
              ),
            ],

            const SizedBox(height: 12),

            // ─── أزرار ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDetails(context, request),
                    icon: const Icon(Icons.info_outline, size: 15),
                    label: const Text('التفاصيل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: request['status'] == 'active'
                        ? () => _showRespondSheet(context, request)
                        : null,
                    icon: const Icon(Icons.send_outlined, size: 15),
                    label: const Text('تقديم عرض'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5276),
                      foregroundColor: Colors.white,
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

  void _showDetails(BuildContext context, Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0D1E),
      builder: (_) => _ExternalRequestDetails(request: req),
    );
  }

  void _showRespondSheet(
      BuildContext context, Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0D1E),
      builder: (_) => _RespondToExternalRequestSheet(
          requestId: req['id']?.toString() ?? ''),
    );
  }
}

// ─── تفاصيل الطلب الخارجي ────────────────────────────────────────────────────
class _ExternalRequestDetails extends StatelessWidget {
  final Map<String, dynamic> request;
  const _ExternalRequestDetails({required this.request});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0D1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              request['title']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('🌍 تفاصيل الطلب الخارجي',
                style: TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white12, height: 24),
            _ExtDetailRow('الدولة المستهدفة',
                request['target_country']?.toString() ?? '—'),
            _ExtDetailRow('ميناء التسليم',
                request['delivery_port']?.toString() ?? '—'),
            _ExtDetailRow(
                'شروط التسليم (Incoterms)',
                request['incoterms']?.toString() ?? '—'),
            _ExtDetailRow('شروط الدفع',
                request['payment_terms']?.toString() ?? '—'),
            _ExtDetailRow(
                'الكمية', request['quantity']?.toString() ?? '—'),
            _ExtDetailRow('الوحدة', request['unit']?.toString() ?? '—'),
            _ExtDetailRow('الشهادات المطلوبة',
                request['certification']?.toString() ?? '—'),
            _ExtDetailRow(
                'يتطلب عينة',
                request['sample_required'] == true
                    ? 'نعم ⚠️'
                    : 'لا'),
            const SizedBox(height: 16),
            const Text('📝 المواصفات:',
                style: TextStyle(
                    color: Color(0xFF64B5F6),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              request['description']?.toString() ?? '—',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.6),
            ),
            if (request['additional_notes'] != null) ...[
              const SizedBox(height: 12),
              const Text('💬 ملاحظات إضافية:',
                  style: TextStyle(
                      color: Color(0xFF64B5F6),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                request['additional_notes'].toString(),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExtDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _ExtDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text('$label:',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── ورقة تقديم رد على الطلب الخارجي ────────────────────────────────────────
class _RespondToExternalRequestSheet extends ConsumerStatefulWidget {
  final String requestId;
  const _RespondToExternalRequestSheet({required this.requestId});

  @override
  ConsumerState<_RespondToExternalRequestSheet> createState() =>
      _RespondState();
}

class _RespondState
    extends ConsumerState<_RespondToExternalRequestSheet> {
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String? _attachmentUrl;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final path = '$uid/ext_req_bids/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
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
      setState(() => _error = 'يرجى إدخال السعر المقترح');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(externalRequestsControllerProvider.notifier)
          .respondToRequest(
            requestId: widget.requestId,
            price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
            note: _noteCtrl.text.trim(),
            deliveryDays: int.tryParse(_timeCtrl.text.trim()),
            attachmentUrl: _attachmentUrl,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('✅ تم إرسال عرضك للمراجعة'),
            backgroundColor: Color(0xFF1A5276),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
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
          const Text('🌍 تقديم عرض تصدير',
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
              labelText: 'سعر الوحدة / الكمية الكاملة (\$) *',
              labelStyle: TextStyle(color: Colors.white54),
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
              labelText: 'زمن التوريد (أيام)',
              labelStyle: TextStyle(color: Colors.white54),
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
            maxLength: 600,
            decoration: const InputDecoration(
              labelText: 'مواصفات العرض والشروط',
              hintText: 'المواد المستخدمة، خيارات الشحن، ضمانات الجودة...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              counterStyle:
                  TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickFile,
            icon: Icon(
              _attachmentUrl != null ? Icons.check_circle : Icons.attach_file,
              color: _attachmentUrl != null
                  ? const Color(0xFF64B5F6)
                  : Colors.white54,
            ),
            label: Text(
              _attachmentUrl != null
                  ? '✅ تم إرفاق الملف'
                  : 'إرفاق شهادات / كتالوج (PDF)',
              style: TextStyle(
                  color: _attachmentUrl != null
                      ? const Color(0xFF64B5F6)
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
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال العرض'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── طلباتي الخارجية ──────────────────────────────────────────────────────────
class _MyExternalRequestsList extends ConsumerWidget {
  const _MyExternalRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAsync = ref.watch(myExternalBidsProvider);
    return myAsync.when(
      data: (bids) {
        if (bids.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌍', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('لم تقدّم أي عروض خارجية بعد',
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
              color: const Color(0xFF0E1228),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A2A5A),
                  child: Text('🌍'),
                ),
                title: Text(
                  b['request_title']?.toString() ?? 'طلب خارجي',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  'سعرك: \$${b['price']} • ${_statusLabel(b['status']?.toString())}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF64B5F6))),
      error: (e, _) => Center(
          child: Text('$e',
              style: const TextStyle(color: Colors.white38))),
    );
  }

  String _statusLabel(String? s) {
    return switch (s) {
      'accepted' => 'مقبول ✅',
      'rejected' => 'مرفوض ❌',
      'pending' => 'قيد المراجعة ⏳',
      _ => '—',
    };
  }
}

// ─── صفحة إدارة كل العروض (للمالك) ─────────────────────────────────────────
class _AllExternalBidsAdminPage extends ConsumerWidget {
  const _AllExternalBidsAdminPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(allExternalBidsAdminProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF060814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1E),
        foregroundColor: Colors.white,
        title: const Text('🌍 إدارة العروض الخارجية'),
      ),
      body: bidsAsync.when(
        data: (bids) => ListView.builder(
          itemCount: bids.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, i) {
            final b = bids[i];
            return Card(
              color: const Color(0xFF0E1228),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${b['username'] ?? 'مستخدم'} — \$${b['price']}',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(b['note']?.toString() ?? '',
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
                      onPressed: () => ref
                          .read(externalRequestsControllerProvider.notifier)
                          .moderateBid(
                              bidId: b['id']?.toString() ?? '',
                              accept: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => ref
                          .read(externalRequestsControllerProvider.notifier)
                          .moderateBid(
                              bidId: b['id']?.toString() ?? '',
                              accept: false),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF64B5F6))),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: Colors.white38))),
      ),
    );
  }
}

// ─── ورقة نشر طلب خارجي ─────────────────────────────────────────────────────
class _PostExternalRequestSheet extends ConsumerStatefulWidget {
  const _PostExternalRequestSheet();

  @override
  ConsumerState<_PostExternalRequestSheet> createState() =>
      _PostExtReqSheetState();
}

class _PostExtReqSheetState
    extends ConsumerState<_PostExternalRequestSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  String _incoterms = 'FOB';
  bool _sampleRequired = false;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _countryCtrl,
      _portCtrl,
      _qtyCtrl,
      _unitCtrl,
      _paymentCtrl,
      _certCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0D1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          children: [
            const Text('🌍 نشر طلب خارجي',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'هذا القسم مخصص للمشترين من خارج سوريا',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _ExtField(ctrl: _titleCtrl, label: 'عنوان الطلب *'),
            _ExtField(
                ctrl: _descCtrl,
                label: 'المواصفات التفصيلية *',
                maxLines: 5),
            _ExtField(ctrl: _countryCtrl, label: 'الدولة المستهدفة *'),
            _ExtField(ctrl: _portCtrl, label: 'ميناء التسليم'),
            Row(
              children: [
                Expanded(
                    child: _ExtField(
                        ctrl: _qtyCtrl,
                        label: 'الكمية',
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: _ExtField(ctrl: _unitCtrl, label: 'الوحدة')),
              ],
            ),
            // شروط التسليم
            const Text('Incoterms:',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['FOB', 'CIF', 'EXW', 'DDP', 'CFR']
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: _incoterms == t,
                        onSelected: (_) =>
                            setState(() => _incoterms = t),
                        selectedColor: const Color(0xFF1A5276),
                        labelStyle: TextStyle(
                          color: _incoterms == t
                              ? const Color(0xFF64B5F6)
                              : Colors.white38,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            _ExtField(ctrl: _paymentCtrl, label: 'شروط الدفع (مثال: L/C, T/T 30 days)'),
            _ExtField(ctrl: _certCtrl, label: 'الشهادات المطلوبة (مثال: CE, ISO)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _sampleRequired,
              onChanged: (v) => setState(() => _sampleRequired = v),
              title: const Text('يتطلب عينة قبل الطلب',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              activeThumbColor: const Color(0xFF64B5F6),
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
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.public_rounded),
              label: Text(_posting ? 'جارٍ النشر...' : 'نشر الطلب الخارجي'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _countryCtrl.text.trim().isEmpty) {
      setState(() => _error = 'العنوان والوصف والدولة مطلوبة');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await ref
          .read(externalRequestsControllerProvider.notifier)
          .postExternalRequest(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            targetCountry: _countryCtrl.text.trim(),
            deliveryPort: _portCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim(),
            unit: _unitCtrl.text.trim(),
            incoterms: _incoterms,
            paymentTerms: _paymentCtrl.text.trim(),
            certification: _certCtrl.text.trim(),
            sampleRequired: _sampleRequired,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('✅ تم نشر الطلب الخارجي بنجاح'),
            backgroundColor: Color(0xFF1A5276),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

class _ExtField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  const _ExtField(
      {required this.ctrl,
      required this.label,
      this.maxLines = 1,
      this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white12)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF64B5F6))),
        ),
      ),
    );
  }
}

class _ExtInfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ExtInfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
