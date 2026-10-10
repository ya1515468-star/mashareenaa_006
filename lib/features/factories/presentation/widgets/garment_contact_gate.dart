import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../chat/presentation/widgets/mini_chat_overlay.dart';

String _dmThreadIdFor(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

/// معلومات التواصل (الهاتف، العنوان، واتساب) تصل من الخادم مخفية (null)
/// لغير صاحب العلاقة ومن لم يدفع. هذه البطاقة تعرضها إن وصلت، وإلا زر دفع
/// يفتح التواصل خادميًا (unlock_garment_contact) ثم محادثة خاصة فورية.
class GarmentContactGate extends ConsumerStatefulWidget {
  /// 'business' أو 'service_ad' — يطابق target_type على الخادم.
  final String targetType;
  final String targetId;
  final String ownerUid;
  final String ownerName;
  final String? ownerAvatar;
  final Map<String, dynamic> detail;
  const GarmentContactGate({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.ownerUid,
    required this.ownerName,
    this.ownerAvatar,
    required this.detail,
  });

  @override
  ConsumerState<GarmentContactGate> createState() => _GarmentContactGateState();
}

class _GarmentContactGateState extends ConsumerState<GarmentContactGate> {
  bool _busy = false;
  Map<String, dynamic>? _fee;

  @override
  void initState() {
    super.initState();
    _loadFee();
  }

  Future<void> _loadFee() async {
    try {
      final row = await Supabase.instance.client
          .from('garment_contact_fee_rules')
          .select()
          .eq('target_type', widget.targetType)
          .maybeSingle();
      if (mounted) setState(() => _fee = row);
    } catch (_) {}
  }

  Future<void> _unlock() async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) return;
    if (myUid == widget.ownerUid) return;

    final gems = (_fee?['gems_cost'] as num?)?.toInt() ?? 0;
    final points = (_fee?['points_cost'] as num?)?.toInt() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('فتح التواصل'),
        content: Text(gems > 0
            ? 'سيُخصم $gems جوهرة من رصيدك لإظهار رقم الهاتف والعنوان وفتح محادثة مباشرة مع صاحب العلاقة.'
            : 'سيُخصم $points نقطة من رصيدك لإظهار رقم الهاتف والعنوان وفتح محادثة مباشرة مع صاحب العلاقة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('ادفع وتواصل')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('unlock_garment_contact', params: {
        'p_target_type': widget.targetType,
        'p_target_id': widget.targetId,
      });
      if (!mounted) return;
      openPrivateChat(
        context,
        ref,
        threadId: _dmThreadIdFor(myUid, widget.ownerUid),
        peerUid: widget.ownerUid,
        peerName: widget.ownerName,
        peerAvatar: widget.ownerAvatar,
      );
    } catch (e) {
      final t = e.toString();
      m?.showSnackBarSfx(SnackBar(content: Text(
        t.contains('INSUFFICIENT_GEMS') ? 'رصيدك من الجواهر لا يكفي.'
        : t.contains('INSUFFICIENT_POINTS') ? 'رصيدك من النقاط لا يكفي.'
        : t.contains('CANNOT_UNLOCK_OWN') ? 'هذا منشورك أنت.'
        : t.contains('CONTACT_UNLOCK_DISABLED') ? 'التواصل المدفوع متوقف حاليًا.'
        : 'تعذّر فتح التواصل: $e',
      )));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final unlocked = d['contact_unlocked'] == true;
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = myUid == widget.ownerUid;

    if (unlocked || isOwner) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((d['phone'] as String?)?.isNotEmpty == true)
          _row(Icons.phone_rounded, d['phone'].toString()),
        if ((d['whatsapp'] as String?)?.isNotEmpty == true)
          _row(Icons.chat_rounded, d['whatsapp'].toString()),
        if ((d['address'] as String?)?.isNotEmpty == true)
          _row(Icons.location_on_rounded, d['address'].toString()),
        if ((d['city'] as String?)?.isNotEmpty == true)
          _row(Icons.map_rounded, d['city'].toString()),
        if (!isOwner) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              final myUid2 = Supabase.instance.client.auth.currentUser?.id;
              if (myUid2 == null) return;
              openPrivateChat(context, ref,
                  threadId: _dmThreadIdFor(myUid2, widget.ownerUid),
                  peerUid: widget.ownerUid,
                  peerName: widget.ownerName,
                  peerAvatar: widget.ownerAvatar);
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('محادثة'),
          ),
        ],
      ]);
    }

    final gems = (_fee?['gems_cost'] as num?)?.toInt() ?? 0;
    final points = (_fee?['points_cost'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: .35)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('الهاتف والعنوان مخفيان — ادفع لفتح التواصل المباشر',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
          onPressed: _busy ? null : _unlock,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(gems > 0 ? '💎 $gems' : '⭐ $points',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      );
}
