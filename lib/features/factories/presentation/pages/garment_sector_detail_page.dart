import 'package:flutter/material.dart';
import '../widgets/garment_contact_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/media_upload_service.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../providers/garment_sector_provider.dart';

/// صفحة القطاع: تُفتح بالضغط على أيقونته (مثل "الجلود"). تعرض منشآت القطاع
/// باسم صاحب كل منشأة كما يظهر في الغرفة، وتتيح "إضافة منشأة" مدفوعة
/// برسوم يحددها المالك. المالك يعدّل ويحذف ويُخفي أي منشأة خادميًا.
final _sectorBusinessesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, sectorKey) async {
  // بلا تحديد الأعمدة، يصل الهاتف والعنوان في استعلام القائمة العام نفسه
  // بصرف النظر عن أي قفل تعرضه الواجهة — القفل كان شكليًا فقط. استبعادهما
  // هنا يجبر كل وصول إليهما على المرور عبر get_garment_business_detail
  // المحروسة بالدفع؛ لا يظهران إلا بعد فتح التواصل فعليًا.
  final rows = await Supabase.instance.client
      .from('garment_businesses')
      .select(
          'id, owner_uid, business_name, sector_key, description, logo_url, cover_url, is_verified, is_published, created_at')
      .eq('sector_key', sectorKey)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

class GarmentSectorDetailPage extends ConsumerWidget {
  final String sectorKey;
  final String sectorName;
  final String emoji;
  final bool isOwner;
  const GarmentSectorDetailPage({
    super.key,
    required this.sectorKey,
    required this.sectorName,
    required this.emoji,
    this.isOwner = false,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final async = ref.watch(_sectorBusinessesProvider(sectorKey));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF07070F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          foregroundColor: Colors.white,
          title: Text('$emoji  $sectorName'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add_business_$sectorKey',
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('إضافة منشأة',
              style: TextStyle(fontWeight: FontWeight.w900)),
          onPressed: () async {
            final ok = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _AddBusinessSheet(sectorKey: sectorKey),
            );
            if (ok == true) ref.invalidate(_sectorBusinessesProvider(sectorKey));
          },
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
          error: (e, _) => Center(
              child: Text('تعذّر التحميل: $e',
                  style: const TextStyle(color: Colors.white70))),
          data: (all) {
            // العامة ترى المنشور فقط؛ صاحب المنشأة والمالك يريان المسودّات.
            final list = all
                .where((b) =>
                    b['is_published'] == true ||
                    isOwner ||
                    b['owner_uid']?.toString() == me)
                .toList();
            if (list.isEmpty) {
              return const Center(
                child: Text('لا منشآت في هذا القطاع بعد',
                    style: TextStyle(color: Colors.white54)),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_sectorBusinessesProvider(sectorKey)),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _BusinessTile(
                  b: list[i],
                  isOwner: isOwner,
                  isMine: list[i]['owner_uid']?.toString() == me,
                  onChanged: () => ref.invalidate(_sectorBusinessesProvider(sectorKey)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  final Map<String, dynamic> b;
  final bool isOwner;
  final bool isMine;
  final VoidCallback onChanged;
  const _BusinessTile(
      {required this.b,
      required this.isOwner,
      required this.isMine,
      required this.onChanged});

  Future<Map<String, dynamic>> _fetchBusinessDetail(String id) async {
    final r = await Supabase.instance.client
        .rpc('get_garment_business_detail', params: {'p_id': id});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> _ownerMenu(BuildContext context) async {
    // تحكّم شامل: كل حقل يقبله owner_manage_garment لمنشأة (الاسم، الوصف،
    // المدينة، الهاتف، التوثيق) صار قابلًا للتعديل من هنا، لا الاسم فقط.
    final name = TextEditingController(text: b['business_name']?.toString() ?? '');
    final desc = TextEditingController(text: b['description']?.toString() ?? '');
    final city = TextEditingController(text: b['city']?.toString() ?? '');
    final phone = TextEditingController(text: b['phone']?.toString() ?? '');
    final published = b['is_published'] == true;
    var verified = b['is_verified'] == true;
    final m = ScaffoldMessenger.maybeOf(context);
    final action = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: const Text('إدارة المنشأة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('موثّقة ✔️'),
                value: verified,
                onChanged: (v) => setLocal(() => verified = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, 'delete'),
                child: const Text('حذف', style: TextStyle(color: Colors.redAccent))),
            TextButton(
                onPressed: () => Navigator.pop(d, 'toggle'),
                child: Text(published ? 'إخفاء' : 'نشر')),
            FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    try {
      final id = b['id'].toString();
      switch (action) {
        case 'save':
          await GarmentActions.ownerManage('business', id, 'update', {
            'business_name': name.text.trim(),
            'description': desc.text.trim(),
            'city': city.text.trim(),
            'phone': phone.text.trim(),
            'is_verified': verified,
          });
        case 'toggle':
          await GarmentActions.ownerManage('business', id, 'update', {'is_published': !published});
        case 'delete':
          await GarmentActions.ownerManage('business', id, 'delete', {});
        default:
          return;
      }
      onChanged();
      m?.showSnackBar(const SnackBar(content: Text('تم التنفيذ')));
    } catch (e) {
      m?.showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    } finally {
      name.dispose();
      desc.dispose();
      city.dispose();
      phone.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = b['logo_url']?.toString() ?? '';
    final published = b['is_published'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)]),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: .2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 58,
            height: 58,
            child: logo.isEmpty
                ? Container(
                    color: Colors.white10,
                    child: const Icon(Icons.factory_rounded, color: Colors.white38))
                : Image.network(logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.white10)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(b['business_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              if (!published)
                const Text('مسودّة', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
              if (isOwner)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                  onPressed: () => _ownerMenu(context),
                ),
            ]),
            // اسم صاحب المنشأة كما يظهر في الغرفة (بمؤثراته وخلفيته).
            ServerUsernameDisplay(
              uid: b['owner_uid']?.toString() ?? '',
              fallbackName: 'عضو',
              fallbackFontSize: 12,
            ),
            if ((b['description']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(b['description'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            if (!isMine)
              FutureBuilder<Map<String, dynamic>>(
                future: _fetchBusinessDetail(b['id'].toString()),
                builder: (context, snap) {
                  final d = snap.data;
                  if (d == null) return const SizedBox.shrink();
                  return GarmentContactGate(
                    targetType: 'business',
                    targetId: b['id'].toString(),
                    ownerUid: b['owner_uid']?.toString() ?? '',
                    ownerName: 'صاحب المنشأة',
                    detail: d,
                  );
                },
              )
            else
              Wrap(spacing: 10, children: [
                if ((b['city']?.toString() ?? '').isNotEmpty)
                  Text('📍 ${b['city']}', style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                if ((b['phone']?.toString() ?? '').isNotEmpty)
                  Text('📞 ${b['phone']}', style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
              ]),
          ]),
        ),
      ]),
    );
  }
}

/// إضافة منشأة مدفوعة: الاسم، الوصف، المدينة، الهاتف، ولوغو المصنع. تُعرض
/// رسوم النشر التي حدّدها المالك ويُطلب التأكيد قبل الخصم؛ الخصم والنشر
/// يتمّان خادميًا في publish_garment_business، ولا تظهر المنشأة للعامة إلا بعده.
class _AddBusinessSheet extends ConsumerStatefulWidget {
  final String sectorKey;
  const _AddBusinessSheet({required this.sectorKey});
  @override
  ConsumerState<_AddBusinessSheet> createState() => _AddBusinessSheetState();
}

class _AddBusinessSheetState extends ConsumerState<_AddBusinessSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  XFile? _logo;
  String _currency = 'points';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final m = ScaffoldMessenger.maybeOf(context);
    if (_name.text.trim().isEmpty) {
      m?.showSnackBar(const SnackBar(content: Text('اكتب اسم المنشأة')));
      return;
    }
    final fees = await ref.read(garmentPublicationFeesProvider.future);
    final fee = fees.firstWhere((f) => f['content_type'] == 'garment_business',
        orElse: () => const <String, dynamic>{});
    final cost = _currency == 'gems' ? (fee['gems_cost'] ?? 0) : (fee['points_cost'] ?? 0);

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد رسوم النشر'),
        content: Text('سيُخصم $cost ${_currency == 'gems' ? 'جوهرة' : 'نقطة'} من رصيدك لنشر المنشأة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('ادفع وانشر')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me == null) throw StateError('AUTH_REQUIRED');
      String? logoUrl;
      if (_logo != null) {
        logoUrl = await MediaUploadService(bucket: 'media')
            .uploadFile(file: _logo!, folder: 'garment/logos', uid: me);
      }
      final id = await GarmentActions.upsertBusiness(
        businessName: _name.text.trim(),
        sectorKey: widget.sectorKey,
        description: _desc.text.trim(),
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        logoUrl: logoUrl,
      );
      if (id == null || id.isEmpty) throw StateError('BUSINESS_NOT_CREATED');
      await GarmentActions.publishBusiness(businessId: id, currency: _currency);
      if (mounted) Navigator.pop(context, true);
      m?.showSnackBar(const SnackBar(
          content: Text('خُصمت الرسوم ونُشرت المنشأة'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      final t = e.toString();
      m?.showSnackBar(SnackBar(
          content: Text(t.contains('INSUFFICIENT')
              ? 'رصيدك لا يكفي لرسوم النشر.'
              : 'تعذّر إنشاء المنشأة: $t'),
          backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF120A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('إضافة منشأة',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                GestureDetector(
                  onTap: _busy
                      ? null
                      : () async {
                          final f = await ImagePicker()
                              .pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (f != null) setState(() => _logo = f);
                        },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700)),
                    ),
                    child: Icon(_logo == null ? Icons.add_photo_alternate_outlined : Icons.check_circle,
                        color: const Color(0xFFFFD700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_logo == null ? 'رفع لوغو المصنع' : 'تم اختيار اللوغو',
                      style: const TextStyle(color: Colors.white70)),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المنشأة')),
              TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
              Row(children: [
                Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'المدينة'))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'الهاتف')),
                ),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'points', label: Text('نقاط ⭐')),
                  ButtonSegment(value: 'gems', label: Text('جواهر 💎')),
                ],
                selected: {_currency},
                onSelectionChanged: (s) => setState(() => _currency = s.first),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('متابعة للدفع',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
