import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ui/ambient_gif_world.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../pattern_studio/presentation/pages/submit_pattern_request_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../rbac/presentation/providers/rbac_provider.dart';
import '../../../rbac/presentation/widgets/permission_gate.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';
import '../../../tenders/presentation/pages/tenders_page.dart';
import '../../../external_requests/presentation/pages/external_requests_page.dart';
import '../../../factories/presentation/pages/garment_sector_page.dart';
import '../widgets/quick_link_card.dart';

/// الشاشة الرئيسية — المنصة
/// تضمّ: الترحيب، المناقصات، الطلبات الخارجية، أقسام الألبسة، وكل الوحدات
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        title: const Text(
          'مشاريعنا',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.8)),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread =
                  ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: Icon(Icons.notifications_outlined,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
                onPressed: () => NotificationsPage.showSheet(context),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── بطاقة الترحيب ──────────────────────────────────────
            SizedBox(
              height: 170,
              child: AmbientGifWorld(
                asset: 'assets/store_gifs/background/background_50.gif',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Color(0xE3140B22), Color(0xB3090713)],
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: profileAsync.when(
                    data: (profile) {
                      if (profile == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الاسم كما كان، وتحته فقاعة رسالة من الخادم: ذكر،
                          // حكمة، نصيحة، أو سرّ من أسرار الخياطة
                          // (platform_tips، يديرها المالك). الفقاعة بحجم
                          // نصّها لا بعرض البطاقة.
                          ServerUsernameDisplay(
                            uid: profile.uid,
                            fallbackName: profile.displayName,
                            fallbackFontSize: 22,
                          ),
                          const SizedBox(height: 6),
                          const _PlatformTipCard(),
                          const SizedBox(height: 6),
                          roleAsync.when(
                            data: (role) => role == null
                                ? const SizedBox.shrink()
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xFFFFD700)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      role.name,
                                      style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── أقسام قطاع الألبسة (بطاقات بارزة) ─────────────────
            const _SectionHeader(
              title: 'قطاع الألبسة',
              emoji: '🧵',
              subtitle: '24 قطاعًا • منشآت • إعلانات خدمات',
            ),
            const SizedBox(height: 12),
            _GarmentSectorsRow(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const GarmentSectorPage())),
            ),

            const SizedBox(height: 24),

            // ─── المناقصات والطلبات الخارجية ────────────────────────
            const _SectionHeader(
              title: 'التجارة والمناقصات',
              emoji: '📋',
              subtitle: 'مناقصات محلية وطلبات تصدير',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BigCard(
                    icon: Icons.gavel_rounded,
                    emoji: '🏗️',
                    title: 'المناقصات',
                    subtitle: 'تعاقدات محلية',
                    gradientColors: const [
                      Color(0xFF1A3A5C),
                      Color(0xFF0D1F35),
                    ],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TendersPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigCard(
                    icon: Icons.flight_rounded,
                    emoji: '🌍',
                    title: 'الطلبات الخارجية',
                    subtitle: 'تصدير دولي',
                    gradientColors: const [
                      Color(0xFF1A4A2A),
                      Color(0xFF0D2515),
                    ],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ExternalRequestsPage())),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── الوصول السريع ───────────────────────────────────────
            const _SectionHeader(
              title: 'الوصول السريع',
              emoji: '⚡',
            ),
            const SizedBox(height: 12),
            GridView.count(
              // 4 أعمدة بنسبة عرضية 1.15 بدل 3 أعمدة مربّعة (0.95):
              // البطاقة صارت أوسع من ارتفاعها فتناسب شاشة الموبايل.
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: [
                QuickLinkCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'المحفظة',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletPage())),
                ),
                // كان يفتح GarmentHubPage القديمة المكرّرة (بلا نشر ولا
                // منشآتي) — مدخل ثانٍ للقطاع نفسه. صار يفتح الصفحة الموحّدة.
                QuickLinkCard(
                  icon: Icons.factory_outlined,
                  label: 'قطاع الألبسة',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GarmentSectorPage())),
                ),
                QuickLinkCard(
                  icon: Icons.checkroom_outlined,
                  label: 'باترون',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SubmitPatternRequestPage())),
                ),
                PermissionGate(
                  permission: 'view_admin_dashboard',
                  child: QuickLinkCard(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'الإدارة',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AdminDashboardPage())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── رأس القسم ───────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    required this.emoji,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── صف أقسام الألبسة ────────────────────────────────────────────────────────
class _GarmentSectorsRow extends StatelessWidget {
  final VoidCallback onTap;
  const _GarmentSectorsRow({required this.onTap});

  static const _sectors = [
    ('📦', 'أمبلاج', Color(0xFF1A3A5C)),
    ('✂️', 'قطاعة', Color(0xFF5C1A1A)),
    ('🫧', 'غسيل', Color(0xFF1A3C5C)),
    ('🎨', 'صباغة', Color(0xFF3C1A5C)),
    ('🪡', 'تطريز', Color(0xFF5C4A1A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // صف الفئات القصير
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _sectors.length + 1, // +1 لـ "عرض الكل"
            itemBuilder: (context, i) {
              if (i == _sectors.length) {
                return GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      color:
                          const Color(0xFFFFD700).withValues(alpha: 0.06),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded,
                            color: Color(0xFFFFD700), size: 22),
                        SizedBox(height: 6),
                        Text(
                          'الكل',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final (emoji, name, color) = _sectors[i];
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 80,
                  margin: EdgeInsets.only(
                      left: i == 0 ? 0 : 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.4)],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── بطاقة كبيرة ─────────────────────────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _BigCard({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.4), size: 14),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PlatformTipCard extends StatefulWidget {
  const _PlatformTipCard();
  @override
  State<_PlatformTipCard> createState() => _PlatformTipCardState();
}

class _PlatformTipCardState extends State<_PlatformTipCard> {
  static const _meta = {
    'dhikr': ('🤲', 'ذكر'),
    'wisdom': ('💡', 'حكمة'),
    'advice': ('📌', 'نصيحة'),
    'tailoring': ('🧵', 'من أسرار الخياطة'),
  };
  Map<String, dynamic>? _tip;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _next();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _next());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _next() async {
    try {
      final r = await Supabase.instance.client.rpc('get_platform_tip');
      if (mounted && r is Map) setState(() => _tip = Map<String, dynamic>.from(r));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tip;
    if (tip == null) return const SizedBox(height: 4);
    final meta = _meta[tip['category']] ?? ('✨', '');
    // فقاعة رسالة: عرضها بحجم نصّها (Align+IntrinsicWidth)، لا عرض البطاقة
    // كاملة، وتحت الاسم مباشرة — كما كانت الرسالة التوضيحية السابقة تمامًا.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: _next,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Container(
            key: ValueKey(tip['id']),
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${meta.$1}  ${meta.$2}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                const SizedBox(height: 3),
                Text(tip['body']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
