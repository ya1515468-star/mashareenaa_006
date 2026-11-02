import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/snack_sfx.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/guest_provider.dart';

/// تبويب المالك/السوبر أدمن: صلاحيات حساب الزائر.
///
/// كل مفتاح هنا صفّ في `public.feature_flags`، والتبديل يمرّ بـ
/// `owner_set_guest_feature` التي ترفض غير المالك والسوبر أدمن، وترفض
/// أي مفتاح لا يبدأ بـ`guest_`، وتسجّل من غيّره ومتى في `audit_logs`.
///
/// والقرار يُنفَّذ خادميًا داخل الدوال والتريجرات نفسها، لا هنا. هذه
/// الشاشة تكتب القيمة لا أكثر.
class OwnerGuestControlTab extends ConsumerStatefulWidget {
  const OwnerGuestControlTab({super.key});

  @override
  ConsumerState<OwnerGuestControlTab> createState() =>
      _OwnerGuestControlTabState();
}

class _OwnerGuestControlTabState extends ConsumerState<OwnerGuestControlTab> {
  final _db = Supabase.instance.client;

  List<Map<String, dynamic>> _flags = const [];
  Map<String, dynamic> _stats = const {};
  bool _loading = true;
  bool _canManage = false;
  String? _error;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final can = await _db.rpc('can_manage_guest_settings');
      final rows = await _db.rpc('owner_get_guest_settings');
      final stats = await _db.rpc('owner_guest_stats');
      if (!mounted) return;
      setState(() {
        _canManage = can == true;
        _flags = (rows as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        _stats = stats is Map ? Map<String, dynamic>.from(stats) : const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل صلاحيات الزائر: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _busyKey = key);
    try {
      await _db.rpc('owner_set_guest_feature',
          params: {'p_flag_key': key, 'p_enabled': value});
      // تُرفع القيود عن الزوّار الحاليين فور التبديل.
      ref.invalidate(guestStateProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(value ? 'فُتحت للزائر.' : 'أُغلقت على الزائر.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تعذّر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _editMessage(Map<String, dynamic> flag) async {
    final controller =
        TextEditingController(text: flag['disabled_message_ar']?.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رسالة القفل'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'ما يراه الزائر حين يحاول استعمال هذه الميزة',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _db.rpc('owner_set_guest_feature', params: {
        'p_flag_key': flag['flag_key'],
        'p_enabled': flag['is_enabled'],
        'p_disabled_message_ar': controller.text.trim(),
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تعذّر الحفظ: $e')),
      );
    }
  }

  Future<void> _cleanup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الزوّار المهجورين'),
          content: Text(
            'سيُحذف كل زائر لم يُرقِّ حسابه ولم يعد منذ 30 يومًا '
            '(${_stats['abandoned_30d'] ?? 0} حسابًا). لا يمكن التراجع.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final deleted =
          await _db.rpc('cleanup_abandoned_guests', params: {'p_days': 30});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('حُذف $deleted حسابًا.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text('تعذّر الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _statsCard(p),
            const SizedBox(height: 14),
            if (!_canManage)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'أنت تشاهد الإعدادات فقط. التبديل مقصور على مالك المنصة '
                  'والسوبر أدمن.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                ),
              ),
            Text('ما يُسمح للزائر',
                style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'كل مفتاح يُنفَّذ خادميًا داخل الدوال والتريجرات. إغلاقه يعني '
              'رفض العملية من الخادم حتى لو عُدِّل التطبيق.',
              style: TextStyle(color: p.textMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 10),
            for (final flag in _flags) _flagTile(p, flag),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _canManage ? _cleanup : null,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('حذف الزوّار المهجورين (30 يومًا)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(dynamic p) {
    Widget cell(String label, Object? value) => Expanded(
          child: Column(children: [
            Text('${value ?? 0}',
                style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 11)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
      ),
      child: Row(children: [
        cell('زوّار', _stats['total_guests']),
        cell('نشِط 7 أيام', _stats['active_7d']),
        cell('مهجور 30 يومًا', _stats['abandoned_30d']),
        cell('رُقّي حسابه', _stats['upgraded']),
      ]),
    );
  }

  Widget _flagTile(dynamic p, Map<String, dynamic> flag) {
    final key = flag['flag_key']?.toString() ?? '';
    final enabled = flag['is_enabled'] == true;
    final name = flag['name_ar']?.toString() ?? key;
    final message = flag['disabled_message_ar']?.toString() ?? '';
    final busy = _busyKey == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      color: p.textPrimary, fontWeight: FontWeight.w700)),
              if (!enabled && message.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textMuted, fontSize: 11.5)),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'تعديل رسالة القفل',
          icon: Icon(Icons.edit_note_rounded, size: 20, color: p.textMuted),
          onPressed: _canManage ? () => _editMessage(flag) : null,
        ),
        busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: enabled,
                onChanged:
                    _canManage ? (v) => _toggle(key, v) : null,
              ),
      ]),
    );
  }
}
