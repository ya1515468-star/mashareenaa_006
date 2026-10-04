import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/pages/active_call_page.dart';
import '../../../calls/presentation/providers/call_provider.dart';
import 'home_dashboard_page.dart';
import '../../../chat/presentation/pages/chat_lobby_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../producers_market/presentation/pages/producers_market_page.dart';
import '../../../admin/presentation/pages/error_monitor_page.dart';

/// نقطة الدخول الوحيدة للمستخدم المسجَّل دخوله.
/// ─── هيكل التنقل ─────────────────────────────────────────────────────────────
/// BottomNav:
///   0  الشات (الغرفة العامة)
///   1  المنصة (dashboard: مناقصات + طلبات خارجية + كل الأقسام)
///   2  سوق المنتجين (ريلات TikTok-style) ← في الأسفل بجانب المنصة
///   3* المراقبة (مالك المنصة فقط)
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // كان هنا معرّف غرفة مكتوب يدويًا كاحتياط — تحققت منه فوجدته لا يطابق
  // أي غرفة حقيقية في قاعدة البيانات إطلاقًا (صفر صفوف)، وكان الحقل
  // أدناه يُهيَّأ به منذ البداية، فجملة "??=" في معالج الاستثناء كانت
  // بلا أثر فعلي أبدًا — أي استثناء عابر أثناء جلب الغرفة الحقيقية
  // يُبقي المستخدم عالقًا على غرفة غير موجودة بلا أي تعافٍ. لا قيمة
  // ميتة بعد الآن؛ أي احتياط يُستعلَم من البيانات الحيّة مباشرة.

  int _index = 0;
  bool _isOwner = false;
  String? _currentRoomId;
  String? _roomError;
  bool _roomLoading = false;
  String? _handledCallId;
  ProviderSubscription<AsyncValue<CallEntity?>>? _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOwnerFlag());
    _incomingCallSubscription = ref.listenManual<AsyncValue<CallEntity?>>(
      incomingRingingCallProvider,
      (_, next) {
        if (!mounted) return;
        final call = next.valueOrNull;
        if (call != null) _handleIncomingCall(call);
      },
    );
    _loadCurrentRoom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialCall = ref.read(incomingRingingCallProvider).valueOrNull;
      if (initialCall != null) _handleIncomingCall(initialCall);
    });
  }

  Future<void> _loadOwnerFlag() async {
    try {
      final owner = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (!mounted) return;
      setState(() {
        _isOwner = owner == true;
        if (_index >= _pages.length) _index = 0;
      });
    } catch (_) {}
  }

  Future<void> _loadCurrentRoom() async {
    if (!mounted) return;
    setState(() {
      _roomLoading = false;
      _roomError = null;
    });
    try {
      // كانت تجلب الغرفة الأقدم تاريخ إنشاء دائمًا، بلا أي قرار من المالك
      // وبلا أي ذاكرة لآخر غرفة دخلها المستخدم فعليًا — نفس الغرفة
      // للجميع بالصدفة. get_entry_room تُرجع آخر غرفة صالحة للعضو العائد،
      // وإلا الغرفة التي عيّنها المالك "افتراضية"، وإلا الأقدم كخط أخير.
      final roomId = (await Supabase.instance.client
              .rpc('get_entry_room')
              .timeout(const Duration(seconds: 8)))
          ?.toString();
      if (roomId == null || roomId.isEmpty) {
        await _fallbackToLiveRoom('تعذّر العثور على غرفة عامة نشطة حالياً.');
        return;
      }
      setState(() {
        _currentRoomId = roomId;
        _roomError = null;
      });
    } catch (error) {
      if (!mounted) return;
      await _fallbackToLiveRoom('تعذّر فتح الشات. تحقق من الاتصال.');
    }
  }

  /// لا قيمة ميتة مكتوبة يدويًا بعد الآن؛ عند أي فشل في get_entry_room
  /// يُستعلَم مباشرة عن أقدم غرفة عامة نشطة فعلية — بيانات حيّة دائمًا،
  /// لا معرّف جامد قد يصبح غير موجود مع الوقت.
  Future<void> _fallbackToLiveRoom(String errorMessage) async {
    try {
      final row = await Supabase.instance.client
          .from('chat_rooms')
          .select('id')
          .eq('is_active', true)
          .eq('is_public', true)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      final liveId = row?['id']?.toString();
      if (!mounted) return;
      setState(() {
        _currentRoomId = (liveId != null && liveId.isNotEmpty) ? liveId : null;
        _roomError = errorMessage;
      });
    } catch (_) {
      if (mounted) setState(() => _roomError = errorMessage);
    }
  }

  Widget _chatEntryPage() {
    final roomId = _currentRoomId;
    if (roomId != null && roomId.isNotEmpty) return ChatLobbyPage(roomId: roomId);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_roomError ?? 'تعذّر فتح الشات.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _roomLoading ? null : _loadCurrentRoom,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> get _pages => [
        _chatEntryPage(),                   // 0 الشات
        const HomeDashboardPage(),           // 1 المنصة
        const ProducersMarketPage(),         // 2 سوق المنتجين
        if (_isOwner) const ErrorMonitorPage(), // 3* (مالك فقط)
      ];

  // ─── عناصر الـ BottomNavigationBar ─────────────────────────────────────────
  List<BottomNavigationBarItem> get _navItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          activeIcon: Icon(Icons.chat_bubble_rounded),
          label: 'الشات',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view_rounded),
          label: 'المنصة',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.play_circle_outline_rounded),
          activeIcon: Icon(Icons.play_circle_rounded),
          label: 'سوق المنتجين',
        ),
        if (_isOwner)
          const BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            activeIcon: Icon(Icons.monitor_heart_rounded),
            label: 'المراقبة',
          ),
      ];

  void _handleIncomingCall(CallEntity call) {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (!mounted || myUid == null || call.id == _handledCallId) return;
    _handledCallId = call.id;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(call.type == CallType.video
            ? '📹 مكالمة فيديو واردة'
            : '📞 مكالمة صوتية واردة'),
        content: const Text(
            'لديك مكالمة واردة. يمكنك القبول أو الرفض.'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(callControllerProvider.notifier).updateStatus(
                    callId: call.id,
                    status: CallStatus.declined,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(callControllerProvider.notifier).updateStatus(
                    callId: call.id,
                    status: CallStatus.accepted,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ActiveCallPage(
                  callId: call.id,
                  otherUid: call.callerUid,
                  type: call.type,
                  isCaller: false,
                ),
              ));
            },
            child: const Text('قبول'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _incomingCallSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack يُبقي كل التبويبات حيّة دون أن يُعلمها أنها مخفية،
      // فكان فيديو سوق المنتجين يستمر بالصوت أثناء التصفح في الشات.
      // TickerMode يعطّل التبويبات غير الظاهرة، والمشغّل يستمع له فيوقف.
      body: IndexedStack(index: _index, children: [
        for (var i = 0; i < _pages.length; i++)
          TickerMode(enabled: i == _index, child: _pages[i]),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index.clamp(0, _navItems.length - 1),
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0C0714),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 9),
        items: _navItems,
      ),
    );
  }
}
