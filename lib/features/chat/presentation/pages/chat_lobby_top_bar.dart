part of 'chat_lobby_page.dart';

// الشريط العلوي للوبي الدردشة
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _TopBar extends ConsumerWidget {
  final VoidCallback onMenu;
  final VoidCallback onVip;
  final VoidCallback onPrinces;
  final VoidCallback onMessages;
  final VoidCallback onRequest;
  final VoidCallback onNotifications;
  final VoidCallback onReport;
  final VoidCallback onSettings;
  final VoidCallback onThemes;
  final VoidCallback onBroadcastSuggestion;
  final bool canManageBroadcast;
  final String? avatarUrl;

  const _TopBar({
    required this.onMenu,
    required this.onVip,
    required this.onPrinces,
    required this.onMessages,
    required this.onRequest,
    required this.onNotifications,
    required this.onReport,
    required this.onSettings,
    required this.onThemes,
    required this.onBroadcastSuggestion,
    required this.canManageBroadcast,
    required this.avatarUrl,
  });

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool legendary = false,
    Widget? iconChild,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.003)
                ..rotateX(-0.10)
                ..rotateY(0.045),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: legendary
                        ? const [
                            Color(0xFFFFF3A3),
                            Color(0xFFFFD45C),
                            Color(0xFF8A5A00)
                          ]
                        // البند 15: كان بنفسجيًا. صار برونزًا داكنًا لا ذهبًا
                        // لامعًا، كي يزول البنفسجي دون أن تضيع التفرقة بين
                        // الفئة العادية والأسطورية (الذهب اللامع للأسطورية
                        // وحدها).
                        : const [Color(0xFF6B5320), Color(0xFF3A2A0E)],
                  ),
                  border: Border.all(
                    color: legendary
                        ? const Color(0xAAFFE58A)
                        : Colors.white.withValues(alpha: .20),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: legendary
                          ? const Color(0x77FFD45C)
                          : Colors.black.withValues(alpha: .35),
                      blurRadius: legendary ? 14 : 8,
                      offset: const Offset(1.5, 2.5),
                    ),
                    const BoxShadow(
                      color: Colors.white24,
                      blurRadius: 2,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: iconChild ??
                    Icon(
                      icon,
                      color: legendary ? const Color(0xFF2B1400) : Colors.white,
                      size: 14,
                    ),
              ),
            ),
            const SizedBox(height: 0),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: legendary ? const Color(0xFFFFD45C) : Colors.white,
                fontSize: 6.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withBadge(Widget child, int count) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 1,
          right: 1,
          child: Container(
            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppNotificationEntity> notifications =
        ref.watch(notificationsProvider).valueOrNull ??
            const <AppNotificationEntity>[];
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ??
            notifications.where((n) => !n.isRead).length;
    // من المحادثات الخاصة نفسها، لا من الإشعارات (انظر unread_dm_provider).
    final messageCount = ref.watch(unreadDmCountProvider).valueOrNull ?? 0;
    final reportCount = notifications
        .where((n) => n.type == AppNotificationType.report && !n.isRead)
        .length;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final requestCount = uid == null
        ? 0
        : (ref.watch(pendingFriendRequestsProvider(uid)).valueOrNull?.length ??
            0);

    // الترتيب RTL: «ملفي» في الزاوية الأولى، والقائمة في الزاوية الثانية.
    // الأزرار المهمة تبقى مرئية دائماً ولا تُنقل إلى القائمة المنسدلة.
    final actions = <Widget>[
      _action(
        icon: Icons.person_rounded,
        label: 'ملفـي',
        onTap: onSettings,
        iconChild: avatarUrl == null || avatarUrl!.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
            : ClipOval(
                child: Image.network(
                  avatarUrl!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
      ),
      _withBadge(
        _action(icon: Icons.mail_rounded, label: 'رسالة', onTap: onMessages),
        messageCount,
      ),
      _withBadge(
        _action(
            icon: Icons.person_add_alt_1_rounded,
            label: 'طلبات',
            onTap: onRequest),
        requestCount,
      ),
      _withBadge(
        _action(
            icon: Icons.notifications_rounded,
            label: 'إشعارات',
            onTap: onNotifications),
        unreadNotifications,
      ),
      _action(
          icon: Icons.workspace_premium_rounded,
          label: 'العضويات',
          onTap: onVip,
          legendary: true),
      _action(
          icon: Icons.emoji_events_rounded,
          label: 'الأمراء',
          onTap: onPrinces,
          legendary: true),
      _withBadge(
        _action(icon: Icons.flag_rounded, label: 'ابلاغ', onTap: onReport),
        reportCount,
      ),
      if (canManageBroadcast)
        _action(
          icon: Icons.campaign_rounded,
          label: 'بث المنصة',
          onTap: onBroadcastSuggestion,
        ),
      _action(icon: Icons.menu_rounded, label: 'القائـمة', onTap: onMenu),
    ];

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: Container(
        width: double.infinity,
        height: 38,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFF3A2C0A), Color(0xFF8A6D1C), Color(0xFF2A1F06)],
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final actionWidth = width >= 900
                  ? 78.0
                  : width >= 650
                      ? 66.0
                      : 58.0;
              return Row(
                children: [
                  for (final action in actions)
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: actionWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: action,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
