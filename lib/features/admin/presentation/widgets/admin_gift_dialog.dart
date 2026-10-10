import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Shared "gift item to a user" flow for platform-owner store management.
///
/// The owner types a username or a user ID, picks the matching account,
/// reviews a full read-only profile (identity, geographic location, and
/// every feature/service that account has purchased or currently has
/// active), then confirms handing this specific item to them for free.
///
/// This dialog is intentionally generic: [itemLabel] describes what is being
/// gifted and [onConfirmGift] performs the actual grant RPC for that item
/// type, so the same search + profile-viewer UI is reused for every store
/// section instead of rebuilding it per item type.
///
/// ROOT CAUSE OF THE FREEZE (confirmed live via the actual Flutter error,
/// not guessed): a non-scrollable `AlertDialog` wraps its whole `content` in
/// an internal `IntrinsicWidth` (see Flutter's material/dialog.dart). This
/// dialog's search row used to be `Row(children: [Expanded(TextField), ...,
/// FilledButton])` — `Expanded`/`Flexible` cannot be intrinsically measured,
/// so `IntrinsicWidth` threw "BoxConstraints forces an infinite width" the
/// moment the dialog first opened, before any network call. That single
/// layout exception is also what corrupted Flutter's mouse tracker
/// (`!_debugDuringDeviceUpdate`) and produced the endless repeating
/// "Another exception was thrown" spam that looked like the freeze itself —
/// the repeats were a side effect of this one exception, not a separate bug.
/// Fixed by removing every `Expanded`/`Flexible` from this dialog's content
/// (search row and the profile header both now stack instead of using
/// `Row`+`Expanded`). The 300ms pre-open delay below is an unrelated, purely
/// defensive precaution against opening any dialog synchronously from a
/// `PopupMenuButton.onSelected` (the popup's own route-removal animation);
/// it is harmless to keep but was not the actual fix for this crash.
Future<void> showAdminGiftDialog({
  required BuildContext context,
  required String itemLabel,
  required Future<void> Function(String userId, String requestId) onConfirmGift,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!context.mounted) return;
  return showDialog(
    context: context,
    builder: (_) => _AdminGiftDialog(itemLabel: itemLabel, onConfirmGift: onConfirmGift),
  );
}

class _AdminGiftDialog extends StatefulWidget {
  final String itemLabel;
  final Future<void> Function(String userId, String requestId) onConfirmGift;
  const _AdminGiftDialog({required this.itemLabel, required this.onConfirmGift});

  @override
  State<_AdminGiftDialog> createState() => _AdminGiftDialogState();
}

class _AdminGiftDialogState extends State<_AdminGiftDialog> {
  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _matches = [];
  Map<String, dynamic>? _fullProfile;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _looksLikeUid {
    final v = _query.text.trim();
    return RegExp(r'^[0-9a-fA-F-]{20,}$').hasMatch(v);
  }

  Future<void> _search() async {
    final v = _query.text.trim();
    if (v.isEmpty) return;
    setState(() { _busy = true; _error = null; _matches = []; _fullProfile = null; });
    try {
      final rows = await Supabase.instance.client.rpc('admin_lookup_user_by_identifier', params: {
        'p_identifier': v,
        'p_identifier_kind': _looksLikeUid ? 'UID' : 'NAME',
      }) as List;
      final list = rows.cast<Map<String, dynamic>>();
      if (list.length == 1) {
        await _openProfile(list.first['id'] as String);
      } else {
        setState(() => _matches = list);
      }
    } catch (e) {
      setState(() => _error = _friendlyLookupError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProfile(String userId) async {
    setState(() { _busy = true; _error = null; });
    try {
      final data = await Supabase.instance.client.rpc('admin_get_user_full_profile', params: {'p_user_id': userId}) as Map;
      setState(() { _fullProfile = data.cast<String, dynamic>(); _matches = []; });
    } catch (e) {
      setState(() => _error = _friendlyLookupError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmGift() async {
    final p = _fullProfile;
    if (p == null) return;
    final userId = p['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الإهداء'),
        content: Text('سيتم إهداء «${widget.itemLabel}» لهذا المستخدم مجانًا الآن. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إهداء')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onConfirmGift(userId, const Uuid().v4());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text('تم إهداء «${widget.itemLabel}» بنجاح ✓'), backgroundColor: Colors.green.shade700));
    } catch (e) {
      setState(() => _error = _friendlyLookupError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyLookupError(Object e) {
    final s = e.toString();
    debugPrint('ADMIN_GIFT_DIALOG_ERROR: $s');
    if (s.contains('USER_NOT_FOUND')) return 'لم يتم العثور على مستخدم بهذا الاسم أو المعرّف.';
    if (s.contains('FORBIDDEN')) return 'لا تملك صلاحية تنفيذ هذه العملية.';
    if (s.contains('AUTH_REQUIRED')) return 'انتهت جلسة الدخول.';
    if (s.contains('ANIMATION_NOT_AVAILABLE')) return 'هذا العنصر غير متاح للإهداء حاليًا.';
    if (s.contains('USER_ID_REQUIRED') || s.contains('IDENTIFIER_REQUIRED')) return 'أدخل اسم مستخدم أو معرّفًا صالحًا.';
    return 'تعذر تنفيذ العملية. تم تسجيل تفاصيل الخطأ الحقيقية لفريق التطوير.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إهداء: ${widget.itemLabel}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_fullProfile == null) ...[
              TextField(
                controller: _query,
                decoration: const InputDecoration(labelText: 'اسم المستخدم أو المعرّف (ID)'),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 8),
              // "لنفسي": المالك يمنح نفسه أي عنصر مباشرة بلا بحث عن اسمه.
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _busy ? null : _search, child: const Text('بحث')),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          final me = Supabase.instance.client.auth.currentUser?.id;
                          if (me != null) _openProfile(me);
                        },
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('لنفسي'),
                ),
              ]),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
              for (final m in _matches)
                ListTile(
                  leading: CircleAvatar(backgroundImage: (m['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(m['avatar_url'] as String) : null, child: (m['avatar_url'] as String?)?.isNotEmpty == true ? null : const Icon(Icons.person)),
                  title: Text((m['display_name'] as String?) ?? (m['username'] as String?) ?? '—'),
                  subtitle: Text('@${m['username'] ?? '-'} · ${m['id']}', style: const TextStyle(fontSize: 11)),
                  onTap: () => _openProfile(m['id'] as String),
                ),
            ] else
              _ProfileCard(profile: _fullProfile!, busy: _busy, error: _error, onConfirmGift: _confirmGift, onBack: () => setState(() => _fullProfile = null)),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool busy;
  final String? error;
  final VoidCallback onConfirmGift;
  final VoidCallback onBack;
  const _ProfileCard({required this.profile, required this.busy, required this.error, required this.onConfirmGift, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final avatar = (p['avatar_url'] as String?) ?? '';
    final lat = p['latitude'];
    final lon = p['longitude'];
    final vip = (p['vip_services'] as List? ?? const []).cast<Map<String, dynamic>>();
    final purchases = (p['profile_cosmetic_purchases'] as List? ?? const []).cast<Map<String, dynamic>>();
    final animations = (p['owned_name_animations'] as List? ?? const []).cast<Map<String, dynamic>>();
    final activeAnimal = p['active_name_animation'] as Map?;
    final activeBadge = p['active_member_badge'] as Map?;
    final activeTitle = p['active_title'] as Map?;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_forward), tooltip: 'رجوع للبحث'),
        CircleAvatar(radius: 24, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            (p['display_name'] as String?) ?? (p['username'] as String?) ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (p['verified'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.lightBlueAccent, size: 18)),
        if (p['is_suspended'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.block, color: Colors.redAccent, size: 18)),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 58),
        child: SelectableText('ID: ${p['id']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ),
      const Divider(height: 20),
      _row('الموقع الجغرافي', [p['country'], p['city']].where((e) => e != null && '$e'.isNotEmpty).join(' — ').isEmpty ? 'غير متوفر' : [p['country'], p['city']].where((e) => e != null && '$e'.isNotEmpty).join(' — ')),
      if (lat != null && lon != null) _row('الإحداثيات', '$lat, $lon'),
      _row('اللقب النشط', (activeTitle != null && activeTitle['name_ar'] != null) ? activeTitle['name_ar'] as String : 'لا يوجد'),
      _row('الشارة النشطة', (activeBadge != null && activeBadge['name_ar'] != null) ? activeBadge['name_ar'] as String : 'لا يوجد'),
      _row('تأثير اسم المستخدم', (p['active_username_effect'] as String?) ?? 'none'),
      _row('حيوان الاسم النشط', (activeAnimal != null && activeAnimal['name_ar'] != null) ? activeAnimal['name_ar'] as String : 'لا يوجد'),
      const SizedBox(height: 10),
      Text('حيوانات مملوكة (${animations.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (animations.isEmpty) const Text('لا يوجد', style: TextStyle(fontSize: 12, color: Colors.white60)),
      for (final a in animations) Text('• ${a['name_ar']}${a['is_active'] == true ? ' (مفعَّل)' : ''}', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 10),
      Text('خدمات VIP مفعَّلة (${vip.where((e) => e['enabled'] == true).length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      Wrap(spacing: 6, runSpacing: 4, children: [for (final v in vip.where((e) => e['enabled'] == true)) Chip(label: Text(v['name_ar'] as String? ?? '', style: const TextStyle(fontSize: 11)))]),
      const SizedBox(height: 10),
      Text('سجل المشتريات (${purchases.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      for (final o in purchases.take(8)) Text('• ${o['item_key']} — ${o['amount']} ${o['currency']}', style: const TextStyle(fontSize: 12)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: busy ? null : onConfirmGift,
        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.card_giftcard),
        label: const Text('إهداء هذا العنصر لهذا المستخدم'),
      ),
    ]);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ]),
      );
}
