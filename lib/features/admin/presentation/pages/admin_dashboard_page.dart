import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../pattern_studio/presentation/pages/admin_pattern_studio_tab.dart';
import '../../../rbac/presentation/widgets/permission_gate.dart';
import 'admin_audit_log_tab.dart';
import 'admin_broadcast_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_roles_tab.dart';
import 'admin_store_tab.dart';
import 'admin_users_tab.dart';
import 'owner_user_control_tab.dart';
import 'owner_reels_control_tab.dart';
import 'admin_virtual_presence_tab.dart';
import 'admin_platform_requests_tab.dart';
import 'profile_cosmetic_admin_tab.dart';
import 'admin_login_announcement_tab.dart';
import 'admin_chat_badges_tab.dart';
import 'admin_user_titles_tab.dart';
import 'name_animation_admin_tab.dart';
import 'dragon_control_tab.dart';
import 'admin_producers_market_tab.dart';

/// لوحة الإدارة — يجب ألا يصل إليها المستخدم إطلاقًا إلا عبر
/// [PermissionGate] الذي يغلّف زر الوصول إليها (انظر HomeDashboardPage)؛
/// وهنا أيضًا حماية مضاعفة على مستوى الشاشة نفسها في حال تم فتحها
/// بأي طريق آخر (رابط مباشر مثلًا).
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: 'view_admin_dashboard',
      fallback: const Scaffold(
        body: Center(
          child: Text('لا تملك صلاحية الوصول إلى لوحة الإدارة',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
      child: DefaultTabController(
        length: 19,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة الإدارة'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'البلاغات'),
                Tab(text: 'المستخدمون'),
                Tab(text: '🛡️ تحكّم المالك'),
                Tab(text: 'الأدوار والصلاحيات'),
                Tab(text: 'سجل التدقيق'),
                Tab(text: 'استوديو الباترون'),
                Tab(text: 'بث DRAGON'),
                Tab(text: 'اقتراحات الأعضاء'),
                Tab(text: 'متجر الميزات'),
                Tab(text: 'DRAGON / Platform Owner'),
                Tab(text: 'الحضور الافتراضي'),
                Tab(text: 'طلبات الأفكار والبث'),
                Tab(text: 'متجر الشات والأسعار'),
                Tab(text: 'إعلانات تسجيل الدخول'),
                Tab(text: 'شارة العضو'),
                Tab(text: 'ألقاب المستخدمين'),
                Tab(text: 'حيوانات فوق الاسم'),
                Tab(text: '🎬 سوق المنتجين'),
                Tab(text: '🎞️ تحكّم الريلز'),
              ],
            ),
          ),
          // TabBarView يبني كل أبنائه فور الإنشاء — 18 شاشة إدارية
          // تفتح استعلاماتها واشتراكاتها الحيّة معًا لحظة الدخول،
          // فتتجمّد اللوحة. _LazyTab يؤجّل بناء كل تبويب إلى أول
          // مرة يُفتح فيها فعلًا، ثم يحتفظ به.
          body: TabBarView(
            children: [
              _LazyTab(builder: () => const AdminReportsTab()),
              _LazyTab(builder: () => const AdminUsersTab()),
              _LazyTab(builder: () => const OwnerUserControlTab()),
              _LazyTab(builder: () => const AdminRolesTab()),
              _LazyTab(builder: () => const AdminAuditLogTab()),
              _LazyTab(builder: () => const AdminPatternStudioTab()),
              _LazyTab(builder: () => const AdminBroadcastTab()),
              _LazyTab(builder: () => const AdminFeedbackTab()),
              _LazyTab(builder: () => const AdminStoreTab()),
              _LazyTab(builder: () => const DragonControlTab()),
              _LazyTab(builder: () => const AdminVirtualPresenceTab()),
              _LazyTab(builder: () => const AdminPlatformRequestsTab()),
              _LazyTab(builder: () => const ProfileCosmeticAdminTab()),
              _LazyTab(builder: () => const AdminLoginAnnouncementTab()),
              _LazyTab(builder: () => const AdminChatBadgesTab()),
              _LazyTab(builder: () => const AdminUserTitlesTab()),
              _LazyTab(builder: () => const NameAnimationAdminTab()),
              _LazyTab(builder: () => const AdminProducersMarketTab()),
              _LazyTab(builder: () => const OwnerReelsControlTab()),
            ],
          ),
        ),
      ),
    );
  }
}

/// يؤجّل بناء محتوى التبويب حتى أول ظهور، ثم يُبقيه حيًّا.
///
/// بلا هذا تُبنى الشاشات الثمانية عشرة كلها عند فتح اللوحة، فتنطلق
/// عشرات الاستعلامات واشتراكات Realtime في اللحظة نفسها — وهو سبب
/// تجمّد لوحة المالك عند الدخول.
class _LazyTab extends StatefulWidget {
  final Widget Function() builder;
  const _LazyTab({required this.builder});

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab>
    with AutomaticKeepAliveClientMixin {
  Widget? _child;

  @override
  bool get wantKeepAlive => _child != null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _child ??= widget.builder();
    return _child!;
  }
}
