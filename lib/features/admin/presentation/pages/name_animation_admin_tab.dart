import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../gamification/data/name_animation_upload_service.dart';
import '../../../gamification/presentation/providers/name_animation_providers.dart';
import '../../../gamification/domain/entities/name_animation.dart';

class NameAnimationAdminTab extends ConsumerStatefulWidget {
  const NameAnimationAdminTab({super.key});
  @override ConsumerState<NameAnimationAdminTab> createState() => _NameAnimationAdminTabState();
}

class _NameAnimationAdminTabState extends ConsumerState<NameAnimationAdminTab> {
  Uint8List? _bytes;
  String _filename = '';
  final _name = TextEditingController();
  final _points = TextEditingController(text: '5000');
  final _gems = TextEditingController(text: '50');
  bool _ownerFree = false;
  bool _busy = false;
  double? _uploadProgress; // 0..1 while sending; null when idle
  bool? _lastUploadOk; // null = no result shown yet
  String _lastUploadMessage = '';

  @override
  void dispose() {
    _name.dispose(); _points.dispose(); _gems.dispose(); super.dispose();
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['gif'], withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;
      if (f.bytes == null || f.bytes!.isEmpty) throw StateError('ANIMATION_EMPTY');
      if (f.bytes!.length > 8 * 1024 * 1024) throw StateError('ANIMATION_TOO_LARGE');
      if (!f.name.toLowerCase().endsWith('.gif')) throw StateError('GIF_REQUIRED');
      setState(() { _bytes = Uint8List.fromList(f.bytes!); _filename = f.name; _lastUploadOk = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _upload({String existingKey = ''}) async {
    final bytes = _bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر ملف GIF للحيوان أولًا.')));
      return;
    }
    final name = _name.text.trim().isEmpty ? _filename.replaceFirst(RegExp(r'\.gif$', caseSensitive: false), '') : _name.text.trim();
    final p = int.tryParse(_points.text.trim());
    final g = int.tryParse(_gems.text.trim());
    if (p == null || g == null || p < 0 || g < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('السعر غير صالح.')));
      return;
    }
    setState(() { _busy = true; _uploadProgress = 0; _lastUploadOk = null; _lastUploadMessage = ''; });
    try {
      await const NameAnimationUploadService().uploadAndCreate(
        NameAnimationUploadRequest(
          bytes: bytes, filename: _filename, key: existingKey, nameAr: name,
          category: 'animal', pricePoints: p, priceGems: g, ownerFree: _ownerFree,
        ),
        onSendProgress: (fraction) {
          if (!mounted) return;
          // Cap the network-send portion at 92% — the remaining slice covers
          // real server-side work (GIF validation, storage, DB) that happens
          // after every byte is already sent, so the bar never looks "done"
          // while the server might still reject the file.
          setState(() => _uploadProgress = (fraction * 0.92).clamp(0, 0.92));
        },
      );
      ref.invalidate(nameAnimationCatalogProvider);
      if (!mounted) return;
      setState(() {
        _uploadProgress = 1;
        _lastUploadOk = true;
        _lastUploadMessage = existingKey.isEmpty ? 'تم رفع الحيوان وإضافته للكتالوج ✓' : 'تم استبدال GIF الحيوان ✓';
        _bytes = null;
        _filename = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_lastUploadMessage), backgroundColor: Colors.green.shade700));
    } catch (e) {
      final message = _friendly(e);
      if (mounted) {
        setState(() { _uploadProgress = null; _lastUploadOk = false; _lastUploadMessage = message; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(NameAnimation item) async {
    final name = TextEditingController(text: item.nameAr);
    final points = TextEditingController(text: item.pricePoints.toString());
    final gems = TextEditingController(text: item.priceGems.toString());
    var active = item.isActive;
    var free = item.ownerFree;
    final order = TextEditingController(text: item.sortOrder.toString());
    var effect = item.renderEffect;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, setLocal) => AlertDialog(
          title: Text('إدارة ${item.nameAr}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الحيوان')),
            TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط')),
            TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الجواهر')),
            TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
            DropdownButtonFormField<String>(initialValue: effect, items: const [
              DropdownMenuItem(value: 'none', child: Text('بدون مؤثر')),
              DropdownMenuItem(value: 'float_glow', child: Text('حركة + توهج')),
              DropdownMenuItem(value: 'bounce_glow', child: Text('ارتداد + توهج')),
            ], onChanged: (v) => setLocal(() => effect = v ?? 'float_glow'), decoration: const InputDecoration(labelText: 'التأثير')),
            SwitchListTile(value: free, onChanged: (v) => setLocal(() => free = v), title: const Text('مجاني للمالك')),
            SwitchListTile(value: active, onChanged: (v) => setLocal(() => active = v), title: const Text('منشور/فعال')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
          ],
        )),
      );
      if (saved != true || !mounted) return;
      final p = int.tryParse(points.text.trim());
      final g = int.tryParse(gems.text.trim());
      final o = int.tryParse(order.text.trim());
      if (p == null || g == null || o == null || p < 0 || g < 0 || o < 0) throw StateError('INVALID_PRICE');
      await Supabase.instance.client.rpc('admin_update_name_animation', params: {
        'p_effect_key': item.key, 'p_name_ar': name.text.trim(), 'p_price_points': p, 'p_price_gems': g,
        'p_owner_free': free, 'p_is_active': active, 'p_sort_order': o, 'p_render_effect': effect,
        'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(nameAnimationCatalogProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    } finally {
      name.dispose(); points.dispose(); gems.dispose(); order.dispose();
    }
  }

  Future<void> _disable(NameAnimation item) async {
    try {
      await Supabase.instance.client.rpc('admin_set_name_animation_active', params: {
        'p_effect_key': item.key, 'p_is_active': false, 'p_request_id': const Uuid().v4(),
      });
      ref.invalidate(nameAnimationCatalogProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  /// Self-healing diagnostics (§32): reports VALID / BROKEN / MISSING_ASSET /
  /// INVALID_URL per catalog row, plus ORPHAN_STORAGE files with no catalog
  /// row referencing them, so a broken GIF pointer never fails silently.
  Future<void> _runDiagnostics() async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final rows = await Supabase.instance.client.rpc('admin_check_name_animals') as List;
      final orphans = await Supabase.instance.client.rpc('admin_check_name_animal_storage_orphans') as List;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      const labels = {
        'VALID': 'سليم', 'BROKEN': 'معطوب (لا يوجد ملف فعلي في التخزين)',
        'MISSING_ASSET': 'بدون مسار تخزين', 'INVALID_URL': 'رابط غير صالح',
      };
      await showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text('تشخيص حيوانات الاسم'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (rows.isEmpty) const Text('لا توجد حيوانات في الكتالوج بعد.'),
          for (final r in rows.cast<Map<String, dynamic>>())
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Icon(r['status'] == 'VALID' ? Icons.check_circle : Icons.error, size: 18, color: r['status'] == 'VALID' ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('${r['effect_key']} — ${labels[r['status']] ?? r['status']}')),
            ])),
          const Divider(height: 20),
          Text('ملفات بلا سجل في الكتالوج (Orphan Storage): ${orphans.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final o in orphans.cast<Map<String, dynamic>>())
            Text('• ${o['storage_path']}', style: const TextStyle(fontSize: 12)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))],
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    // Log the real exception internally before mapping it to a safe message.
    debugPrint('NAME_ANIMATION_ADMIN_ERROR: $s');
    const map = <String, String>{
      'ANIMATION_TOO_LARGE':'حجم GIF يتجاوز 8MB.', 'GIF_REQUIRED':'يجب اختيار ملف GIF فقط.', 'INVALID_GIF':'ملف GIF غير صالح أو تالف.',
      'INVALID_GIF_DIMENSIONS':'أبعاد GIF غير صالحة.', 'GIF_TOO_MANY_FRAMES':'عدد إطارات GIF كبير جدًا.', 'ANIMATION_EMPTY':'الملف فارغ.',
      'GIF_DECODED_TOO_LARGE':'أبعاد أو إطارات GIF تجعل حجمه بعد فك الضغط أكبر من المسموح.', 'GIF_TRUNCATED':'ملف GIF غير مكتمل أو تالف.',
      'INVALID_FRAME_COUNT':'عدد إطارات الحيوان كبير جدًا.', 'INVALID_ANIMATION_BOUNDS':'أبعاد عرض الحيوان غير مدعومة.',
      'FORBIDDEN':'لا تملك صلاحية تنفيذ هذه العملية.', 'OWNER_REQUIRED':'لا تملك صلاحية المالك.', 'OWNER_CHECK_FAILED':'تعذر التحقق من صلاحية المالك.',
      'NAME_REQUIRED':'اسم الحيوان مطلوب.', 'INVALID_PRICE':'السعر غير صالح.', 'INVALID_ANIMATION_TIMING':'مدة/FPS الحركة غير صالحة.',
      'STORAGE_UPLOAD_FAILED':'فشل رفع الملف إلى التخزين.', 'DATABASE_WRITE_FAILED':'تم رفض حفظ بيانات الحيوان في قاعدة البيانات.',
      'UPLOAD_VALIDATION_FAILED':'الملف لم يجتز فحص الخادم.', 'SERVER_ERROR':'حدث خطأ داخل الخادم وتم تسجيل السبب الحقيقي.',
      'SERVER_CONFIGURATION_ERROR':'خطأ في إعدادات الخادم. تم تسجيل التفاصيل.', 'METHOD_NOT_ALLOWED':'طريقة الطلب غير مدعومة من الخادم.',
      'NETWORK_ERROR':'تعذر الاتصال بالخادم.', 'AUTH_REQUIRED':'انتهت جلسة الدخول.', 'INVALID_SESSION':'انتهت جلسة الدخول.',
      'SESSION_EXPIRED':'انتهت الجلسة أثناء العملية. سجّل الدخول ثم أعد المحاولة.',
      'REQUEST_ID_REQUIRED':'تعذر تجهيز معرّف العملية. أعد المحاولة.', 'REQUEST_ID_REPLAY_FORBIDDEN':'تم رصد تكرار غير متطابق لعملية سابقة.',
      'INVALID_EFFECT_KEY':'مفتاح الحيوان غير صالح.', 'ANIMATION_NOT_FOUND':'الحيوان غير موجود.',
      'INVALID_ASSET_URL':'رابط الملف الناتج غير صالح.', 'INVALID_STORAGE_PATH':'مسار التخزين الناتج غير صالح.', 'INVALID_SIZE':'حجم الملف غير صالح.',
      'INVALID_SORT_ORDER':'قيمة الترتيب غير صالحة.', 'INVALID_RENDER_EFFECT':'نوع التأثير الحركي غير معروف.', 'USER_NOT_FOUND':'المستخدم غير موجود.',
      'USER_ID_REQUIRED':'معرّف المستخدم مطلوب.',
    };
    for (final entry in map.entries) { if (s.contains(entry.key)) return entry.value; }
    return 'فشل تنفيذ عملية حيوان الاسم. تم تسجيل الخطأ الحقيقي في سجل المطور.';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(nameAnimationCatalogProvider);
    return ListView(padding: const EdgeInsets.all(14), children: [
      const Text('إدارة حيوانات الاسم المتحركة', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('GIF فقط — رفع آمن، تخزين خادمي، شراء وتفعيل، وظهور مستقل فوق قالب الاسم.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _runDiagnostics, icon: const Icon(Icons.health_and_safety_outlined), label: const Text('فحص وتشخيص ذاتي'))),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.upload_file), label: Text(_bytes == null ? 'اختيار GIF الحيوان' : 'تم اختيار $_filename')),
      if (_uploadProgress != null) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: _uploadProgress, minHeight: 10, backgroundColor: Colors.white12),
        ),
        const SizedBox(height: 4),
        Text(
          _uploadProgress! >= 0.92 && _busy ? 'جاري المعالجة على الخادم…' : '${(_uploadProgress! * 100).round()}٪',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
      if (_lastUploadOk != null && !_busy) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (_lastUploadOk! ? Colors.green : Colors.red).withValues(alpha: 0.15),
            border: Border.all(color: _lastUploadOk! ? Colors.greenAccent : Colors.redAccent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(_lastUploadOk! ? Icons.check_circle : Icons.error, color: _lastUploadOk! ? Colors.greenAccent : Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_lastUploadOk! ? 'نجح: $_lastUploadMessage' : 'فشل: $_lastUploadMessage', style: const TextStyle(color: Colors.white))),
          ]),
        ),
      ],
      if (_bytes != null) ...[
        const SizedBox(height: 12),
        Container(height: 90, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.black12), child: Image.memory(_bytes!, width: 132, height: 72, fit: BoxFit.contain, gaplessPlayback: true)),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الحيوان')),
        Row(children: [Expanded(child: TextField(controller: _points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط'))), const SizedBox(width: 10), Expanded(child: TextField(controller: _gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الجواهر')))]),
        SwitchListTile(value: _ownerFree, onChanged: _busy ? null : (v) => setState(() => _ownerFree = v), title: const Text('مجاني للمالك'), contentPadding: EdgeInsets.zero),
        FilledButton.icon(onPressed: _busy ? null : () => _upload(), icon: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.cloud_upload), label: Text(_busy ? 'جاري الرفع...' : 'رفع وإضافة للكتالوج')),
      ],
      const SizedBox(height: 22),
      catalog.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (e, _) => Text('فشل تحميل الكتالوج: ${_friendly(e)}', textAlign: TextAlign.center),
        data: (items) => Column(children: [
          for (final item in items)
            Card(
              child: ListTile(
                leading: SizedBox(width: 52, height: 36, child: item.storagePath?.isNotEmpty == true ? FutureBuilder<Uint8List>(future: Supabase.instance.client.storage.from('name-animations').download(item.storagePath!), builder: (c,s) => s.data == null ? const Icon(Icons.pets) : Image.memory(s.data!, fit: BoxFit.contain, gaplessPlayback: true)) : const Icon(Icons.pets)),
                title: Text(item.nameAr),
                subtitle: Text('${item.pricePoints} نقطة • ${item.priceGems} جوهرة • ${item.isActive ? 'فعال' : 'معطل'} • #${item.sortOrder}'),
                trailing: Wrap(spacing: 2, children: [
                  IconButton(tooltip:'تعديل', onPressed: () => _edit(item), icon: const Icon(Icons.edit)),
                  IconButton(tooltip:'استبدال GIF', onPressed: _busy ? null : () async { await _pick(); if (_bytes != null) await _upload(existingKey: item.key); }, icon: const Icon(Icons.cached)),
                  if (item.isActive) IconButton(tooltip:'تعطيل', onPressed: () => _disable(item), icon: const Icon(Icons.visibility_off)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}
