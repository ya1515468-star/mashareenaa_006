import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/points_gems_exchange_service.dart';
import '../providers/gamification_provider.dart';

/// معدّل الصرف الحقيقي الحالي من gamification_config — لم يعد ثابتًا
/// في التطبيق، فيُعرض للمستخدم قبل التحويل بالضبط كما سيُطبَّق فعليًا
/// على الخادم، ويتحدّث تلقائيًا إن غيّره المالك مستقبلًا.
final pointsGemsRateProvider =
    FutureProvider.autoDispose<({int pointsPerGem, int pointsReturnedPerGem})>((ref) async {
  final row = await Supabase.instance.client
      .from('gamification_config')
      .select('points_per_gem, points_returned_per_gem')
      .eq('id', true)
      .maybeSingle();
  return (
    pointsPerGem: (row?['points_per_gem'] as num?)?.toInt() ?? 100,
    pointsReturnedPerGem: (row?['points_returned_per_gem'] as num?)?.toInt() ?? 80,
  );
});

/// "تحويل نقاط الزد (لجواهر)" و"تحويل الجواهر (لنقاط الزد)" —
/// صفحة تحويل ثنائية الاتجاه واحدة، تُفتح من أي من التبويبين.
class PointsGemsExchangePage extends ConsumerStatefulWidget {
  final bool startWithPointsToGems;
  const PointsGemsExchangePage({super.key, this.startWithPointsToGems = true});

  @override
  ConsumerState<PointsGemsExchangePage> createState() =>
      _PointsGemsExchangePageState();
}

class _PointsGemsExchangePageState
    extends ConsumerState<PointsGemsExchangePage> {
  late bool _pointsToGems = widget.startWithPointsToGems;
  final _amountController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (uid == null) return;
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أدخل رقمًا صحيحًا')));
      return;
    }
    final unlimited =
        ref.read(isUnlimitedResourcesProvider).valueOrNull ?? false;
    setState(() => _busy = true);
    final service = PointsGemsExchangeService();
    final result = _pointsToGems
        ? await service.convertPointsToGems(
            uid: uid, points: amount, unlimited: unlimited)
        : await service.convertGemsToPoints(
            uid: uid, gems: amount, unlimited: unlimited);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (converted) {
        _amountController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_pointsToGems
                ? 'تم تحويلها إلى $converted جوهرة ✓'
                : 'تم تحويلها إلى $converted نقطة ✓')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(currentGamificationStatsProvider);
    final stats = statsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل النقاط والجواهر')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Chip(
                  avatar: const Icon(Icons.stars, size: 16),
                  label: Text('نقاطي: ${stats?.points ?? 0}'),
                ),
                Chip(
                  avatar: const Icon(Icons.diamond_outlined, size: 16),
                  label: Text('جواهري: ${stats?.gems ?? 0}'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('نقاط ← جواهر')),
                ButtonSegment(value: false, label: Text('جواهر ← نقاط')),
              ],
              selected: {_pointsToGems},
              onSelectionChanged: (s) =>
                  setState(() => _pointsToGems = s.first),
            ),
            const SizedBox(height: 20),
            Consumer(builder: (context, ref, _) {
              final rate = ref.watch(pointsGemsRateProvider);
              return Text(
                rate.when(
                  data: (r) => _pointsToGems
                      ? 'كل ${r.pointsPerGem} نقطة = جوهرة واحدة'
                      : 'الجوهرة الواحدة = ${r.pointsReturnedPerGem} نقطة',
                  loading: () => '...',
                  error: (e, _) => 'تعذّر تحميل معدّل الصرف',
                ),
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              );
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: _pointsToGems ? 'عدد النقاط' : 'عدد الجواهر',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _convert,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تحويل'),
            ),
          ],
        ),
      ),
    );
  }
}
