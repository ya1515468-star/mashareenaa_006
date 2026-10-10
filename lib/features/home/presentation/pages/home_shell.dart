import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/server_sounds.dart';
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
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _roomRetryTimer;
  Timer? _guardTimer;
  bool _guardBusy = false;
  bool _guardDialogOpen = false;

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
    // "تعذّر فتح الشات" كان غالبًا سباقًا عابرًا مع الجلسة لا انقطاعًا
    // حقيقيًا: أول نداء RPC لحظة فتح الشاشة قد يسبق تحديث توكن منتهٍ
    // لحظيًا (خصوصًا على الويب)، فيفشل مرة واحدة ويُعلَّق المستخدم إلى
    // الأبد بانتظار نقرة "إعادة المحاولة" اليدوية. الآن: أي signedIn أو
    // tokenRefreshed لاحق يُعيد المحاولة تلقائيًا ما دامت الشاشة عالقة
    // على خطأ — اتصال "لا ينقطع" حقيقيًا بدل محاولة واحدة فقط.
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      final relevant = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed;
      if (relevant && _roomError != null && !_roomLoading) {
        unawaited(_loadCurrentRoom());
      }
    });
    _loadCurrentRoom();
    // إعادة محاولة تلقائية صامتة: أول دخول بعد تسجيل الدخول قد يفشل لحظيًا
    // (الجلسة لم تُجهَّز بعد) ثم ينجح بعد ثوانٍ؛ لا نترك المستخدم أمام
    // «تعذّر فتح الشات» بانتظار نقرة يدوية.
    _roomRetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_currentRoomId == null && !_roomLoading) {
        unawaited(_loadCurrentRoom());
      }
    });
    // حارس العقوبات: المقبرة = إخراج كامل من التطبيق، والطرد/الحظر = إخراج
    // من تلك الغرفة فقط. الفحص خادمي كل 6 ثوانٍ.
    _guardTimer = Timer.periodic(const Duration(seconds: 6), (_) => unawaited(_runGuard()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialCall = ref.read(incomingRingingCallProvider).valueOrNull;
      if (initialCall != null) _handleIncomingCall(initialCall);
    });
  }

  Future<void> _notifyBlocked(String title, String body) async {
    if (!mounted || _guardDialogOpen) return;
    _guardDialogOpen = true;
    playServerSound('moderation');
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body, textDirection: TextDirection.rtl),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('حسنًا'))],
        ),
      );
    } finally {
      _guardDialogOpen = false;
    }
  }

  Future<void> _runGuard() async {
    if (_guardBusy || !mounted) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;
    _guardBusy = true;
    try {
      final st = await client.rpc('get_my_security_state');
      if (st is Map && st['blocked'] == true) {
        final reason = (st['reason'] ?? '').toString().trim();
        if (!mounted) return;
        unawaited(client.auth.signOut());
        await _notifyBlocked('تم عزلك إلى المقبرة',
            'تم إخراجك من التطبيق ولا يمكنك الدخول.${reason.isEmpty ? '' : '\nالسبب: $reason'}');
        return;
      }
      final rid = _currentRoomId;
      if (rid != null) {
        final msg = await client.rpc('my_room_block_message', params: {'p_room_id': rid});
        if (msg is String && msg.isNotEmpty) {
          setState(() => _currentRoomId = null);
          unawaited(_loadCurrentRoom());
          await _notifyBlocked('إخراج من الغرفة', msg);
        }
      }
    } catch (_) {
    } finally {
      _guardBusy = false;
    }
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
    if (!mounted || _roomLoading) return;
    setState(() {
      _roomLoading = true;
      _roomError = null;
    });
    // كانت محاولة واحدة فقط بمهلة 8 ثوانٍ: أي سباق عابر (توكن يُحدَّث،
    // انقطاع شبكي لحظي) يُعلِّق المستخدم على شاشة الخطأ إلى الأبد بانتظار
    // نقرة يدوية. الآن محاولات متتالية بتأخير متصاعد قبل الاستسلام
    // لخط الدفاع الثاني — تنفيذ فعلي لـ"اتصال دائم لحظي لاينقطع" في أول
    // نقطة دخول للشات، لا فقط في قنوات Realtime بعد فتحه.
    Object? lastError;
    // لا نستدعي الخادم قبل جاهزية الجلسة (سبب الفشل العابر بعد الدخول).
    for (var i = 0;
        i < 10 && Supabase.instance.client.auth.currentSession == null;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
    for (final delay in const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
    ]) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        // كانت تجلب الغرفة الأقدم تاريخ إنشاء دائمًا، بلا أي قرار من المالك
        // وبلا أي ذاكرة لآخر غرفة دخلها المستخدم فعليًا — نفس الغرفة
        // للجميع بالصدفة. get_entry_room تُرجع آخر غرفة صالحة للعضو العائد،
        // وإلا الغرفة التي عيّنها المالك "افتراضية"، وإلا الأقدم كخط أخير.
        final roomId = (await Supabase.instance.client
                .rpc('get_entry_room')
                .timeout(const Duration(seconds: 8)))
            ?.toString();
        if (roomId != null && roomId.isNotEmpty) {
          setState(() {
            _currentRoomId = roomId;
            _roomError = null;
            _roomLoading = false;
          });
          return;
        }
        // نجح النداء لكن بلا أي غرفة — نتيجة قاطعة من الخادم لا خطأ عابر،
        // فلا قيمة لإعادة محاولتها؛ ينتقل مباشرة لخط الدفاع الثاني.
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
      }
    }
    if (!mounted) return;
    await _fallbackToLiveRoom(lastError == null
        ? 'تعذّر العثور على غرفة عامة نشطة حالياً.'
        : 'تعذّر فتح الشات. تحقق من الاتصال.');
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
        _roomLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _roomError = errorMessage;
          _roomLoading = false;
        });
      }
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
    _roomRetryTimer?.cancel();
    _guardTimer?.cancel();
    _incomingCallSubscription?.close();
    unawaited(_authSubscription?.cancel());
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
