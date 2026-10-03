import 'package:flutter/material.dart';
import '../../rbac/presentation/widgets/server_username_display.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/presentation/pages/user_profile_view_page.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../domain/leaderboard_service.dart';

final topPointsProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  return LeaderboardService.topPoints();
});

final topGiftersProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  return LeaderboardService.topGiftersThisWeek();
});

final topGemsProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>(
    (ref) => LeaderboardService.topGems());
final topInteractionsProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>(
        (ref) => LeaderboardService.topInteractions());
final topPresenceProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>(
    (ref) => LeaderboardService.topPresence());

/// ميزة 2+3 من القائمة الإضافية: لوائح صدارة تحفّزان التنافس
/// الودّي بين الأعضاء — الأعلى نقاطًا تراكميًا، والأعلى إهداءً هذا
/// الأسبوع تحديدًا (تُصفَّر أسبوعيًا تلقائيًا لأنها تُحسَب من
/// آخر 7 أيام فقط، فرصة جديدة كل أسبوع للجميع)، إضافةً إلى "ملوك
/// الجواهر" (العنصر 7 من قائمة الشات الجانبية). [initialTabIndex]
/// يفتح الصفحة مباشرة على تبويب محدد — "ملوك النقاط" و"ملوك
/// الجواهر" في قائمة الشات يفتحان نفس الصفحة على تبويبين مختلفين
/// بدل تكرار شاشتين متطابقتين تقريبًا.
class LeaderboardPage extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const LeaderboardPage({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late final TabController _controller = TabController(
    length: 5,
    vsync: this,
    initialIndex: widget.initialTabIndex.clamp(0, 4),
  );

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.invalidate(topPointsProvider);
      ref.invalidate(topGiftersProvider);
      ref.invalidate(topGemsProvider);
      ref.invalidate(topInteractionsProvider);
      ref.invalidate(topPresenceProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الصدارة 🏆'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'الأعلى نقاطًا'),
            Tab(text: 'الأعلى إهداءً هذا الأسبوع'),
            Tab(text: 'ملوك الجواهر'),
            Tab(text: 'الأعلى تفاعلًا'),
            Tab(text: 'الأكثر تواجدًا'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          _LeaderboardList(
              providerRef: _kPointsRef, icon: Icons.stars, unit: 'نقطة'),
          _LeaderboardList(
              providerRef: _kGiftersRef,
              icon: Icons.card_giftcard,
              unit: 'نقطة أُهديت'),
          _LeaderboardList(
              providerRef: _kGemsRef,
              icon: Icons.diamond_outlined,
              unit: 'جوهرة'),
          _LeaderboardList(
              providerRef: _kInteractionsRef,
              icon: Icons.favorite_rounded,
              unit: 'إعجاب'),
          _LeaderboardList(
              providerRef: _kPresenceRef,
              icon: Icons.schedule_rounded,
              unit: 'ثانية تواجد'),
        ],
      ),
    );
  }
}

const _kPointsRef = 0;
const _kGiftersRef = 1;
const _kGemsRef = 2;
const _kInteractionsRef = 3;
const _kPresenceRef = 4;

class _LeaderboardList extends ConsumerWidget {
  final int providerRef;
  final IconData icon;
  final String unit;
  const _LeaderboardList(
      {required this.providerRef, required this.icon, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch (providerRef) {
      _kPointsRef => ref.watch(topPointsProvider),
      _kGemsRef => ref.watch(topGemsProvider),
      _kInteractionsRef => ref.watch(topInteractionsProvider),
      _kPresenceRef => ref.watch(topPresenceProvider),
      _ => ref.watch(topGiftersProvider),
    };
    final p = context.palette;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذّر تحميل اللائحة: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
              child: Text('لا توجد بيانات كافية بعد',
                  style: TextStyle(color: p.textSecondary)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final medal = index == 0
                ? '🥇'
                : (index == 1 ? '🥈' : (index == 2 ? '🥉' : '${index + 1}'));
            return RepaintBoundary(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => UserProfileViewPage(uid: entry.uid)),
                ),
                leading: CircleAvatar(
                    child: Text(medal, style: const TextStyle(fontSize: 13))),
                // 🔧 Consumer الآن يلفّ فقط النص المتفاعل (الاسم)، وليس
                // كامل ListTile المسؤول عن الإيماءة (onTap) — إعادة
                // بناء الاسم عند تحديث بيانات البروفايل لا تعيد بناء
                // كاشف اللمس نفسه، ما يقلّل احتمال تعارض hit-test مع
                // إيماءة قيد التنفيذ (نفس فئة الخطأ المُبلَّغ عنه عند
                // فتح الملفات الشخصية من قوائم متفاعلة).
                title: Consumer(
                  builder: (context, ref, _) {
                    final profileAsync =
                        ref.watch(profileByIdProvider(entry.uid));
                    final name = profileAsync.valueOrNull?.displayName ?? 'عضو';
                    return ServerUsernameDisplay(uid: entry.uid, fallbackName: name, fallbackFontSize: 14);
                  },
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: p.accent),
                    const SizedBox(width: 4),
                    Text('${entry.value} $unit',
                        style: TextStyle(
                            color: p.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
