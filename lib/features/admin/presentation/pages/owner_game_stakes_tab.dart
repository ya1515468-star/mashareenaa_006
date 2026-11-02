import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_text.dart';
import '../../../../core/services/snack_sfx.dart';
import '../../../../core/theme/app_theme.dart';

/// تبويب المالك/السوبر أدمن: حدود الرهان في الألعاب.
///
/// كانت قائمة الرهان ثابتة مكتوبة في التطبيق **وفي الخادم** معًا، فتغييرها
/// يستلزم إصدارًا جديدًا وهجرة. الآن الحدّان صفّ في `game_stake_settings`
/// يُعدَّل من هنا، والخادم يفرضه عبر `validate_game_stake` في
/// `send_game_challenge` و`trix_start_game`.
class OwnerGameStakesTab extends ConsumerStatefulWidget {
  const OwnerGameStakesTab({super.key});

  @override
  ConsumerState<OwnerGameStakesTab> createState() => _OwnerGameStakesTabState();
}

class _OwnerGameStakesTabState extends ConsumerState<OwnerGameStakesTab> {
  final _db = Supabase.instance.client;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _quickController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _canManage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _quickController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // نفس فحص الصلاحية الذي تستعمله الدالة الخادمية: المالك أو
      // السوبر أدمن. (اسمها تاريخيًا `can_manage_guest_settings` لأنها
      // وُضعت لصلاحيات الزائر، ثم صارت الفحص المشترك لإعدادات المنصة.)
      final can = await _db.rpc('can_manage_guest_settings');
      final limits = await _db.rpc('my_game_stake_limits');
      if (!mounted) return;
      final map = limits is Map ? Map<String, dynamic>.from(limits) : const {};
      final quick = (map['quick'] as List?)
              ?.map((e) => (e as num).toInt().toString())
              .join('، ') ??
          '';
      setState(() {
        _canManage = can == true;
        _minController.text = '${(map['min'] as num?)?.toInt() ?? 0}';
        _maxController.text = '${(map['max'] as num?)?.toInt() ?? 1000000}';
        _quickController.text = quick;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureText.of(e, subject: 'حدود الرهان');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final min = int.tryParse(_minController.text.trim());
    final max = int.tryParse(_maxController.text.trim());
    if (min == null || max == null) {
      _toast('اكتب رقمين صحيحين.');
      return;
    }
    if (min < 0) {
      _toast('الحدّ الأدنى لا يكون سالبًا.');
      return;
    }
    if (max <= 0) {
      _toast('الحدّ الأقصى يجب أن يكون أكبر من صفر.');
      return;
    }
    if (min > max) {
      _toast('الحدّ الأدنى أكبر من الأقصى.');
      return;
    }

    // الاختصارات: أرقام مفصولة بفاصلة. تُنقَّى وتُرتَّب وتُزال تكراراتها،
    // وتُستبعَد ما خرج عن الحدّين حتى لا يُعرض اختصار يرفضه الخادم.
    final quick = _quickController.text
        .split(RegExp(r'[,،\s]+'))
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((v) => v == 0 || (v >= min && v <= max))
        .toSet()
        .toList()
      ..sort();

    setState(() => _saving = true);
    try {
      await _db.rpc('owner_set_game_stake_limits', params: {
        'p_min': min,
        'p_max': max,
        if (quick.isNotEmpty) 'p_quick': quick,
      });
      await _load();
      if (!mounted) return;
      _toast('حُفظت الحدود ✓');
    } catch (e) {
      if (!mounted) return;
      _toast(FailureText.of(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBarSfx(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_loading) return const Center(child: CircularProgressIndicator());
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
          padding: const EdgeInsets.all(16),
          children: [
            if (!_canManage)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'أنت تشاهد الإعدادات فقط. التعديل مقصور على مالك المنصة '
                  'والسوبر أدمن.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                ),
              ),
            Text('حدود الرهان في الألعاب',
                style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'اللاعب يكتب أي مبلغ بين الحدّين. والخادم يفرضهما ويتحقق من '
              'رصيده قبل أن تبدأ اللعبة — فلا يُراهن بما لا يملك.',
              style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _minController,
              enabled: _canManage,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'أقل رهان',
                helperText: 'الرهان الودّي (صفر) يبقى مسموحًا دائمًا مهما رفعته',
                prefixIcon: Icon(Icons.south_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxController,
              enabled: _canManage,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'أعلى رهان',
                helperText: 'سقفٌ يحمي من خسارة ضخمة بضغطة خاطئة',
                prefixIcon: Icon(Icons.north_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quickController,
              enabled: _canManage,
              keyboardType: TextInputType.text,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'الاختصارات السريعة',
                helperText: 'أرقام مفصولة بفاصلة، تظهر كأزرار جاهزة للاعب',
                prefixIcon: Icon(Icons.bolt_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_canManage && !_saving) ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('حفظ'),
            ),
            const SizedBox(height: 10),
            Text(
              'كل تعديل يُسجَّل في سجل التدقيق مع من غيّره ومتى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
