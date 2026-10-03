import 'dart:async';

import '../data/supabase_document_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/broadcasts/domain/repositories/broadcast_repository.dart';
import '../../features/broadcasts/presentation/widgets/broadcast_banner.dart';
import '../../features/chat/domain/usecases/chat_interaction_usecases.dart';
import '../../features/chat/data/services/chat_sound_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/gifts/domain/repositories/gift_repository.dart';
import '../constants/app_constants.dart';
import '../di/injection_container.dart';
import 'dragon_bootstrap_service.dart';

/// يضبط presence/{uid}.isOnline = true عند دخول المستخدم المصادَق
/// للتطبيق أو عودته من الخلفية، ويضبطه false عند الانتقال للخلفية
/// أو إغلاق التطبيق — يُستهلك عبر [WatchPresenceUseCase] في رأس
/// شاشة المحادثة لعرض "متصل الآن" أو "آخر ظهور".
class PresenceLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const PresenceLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<PresenceLifecycleObserver> createState() =>
      _PresenceLifecycleObserverState();
}

class _PresenceLifecycleObserverState
    extends ConsumerState<PresenceLifecycleObserver>
    with WidgetsBindingObserver {
  StreamSubscription? _giftSubscription;
  String? _giftSubscriptionUid;
  StreamSubscription? _broadcastSubscription;
  bool _broadcastListenerActive = false;
  StreamSubscription? _notificationSoundSubscription;
  StreamSubscription? _friendSoundSubscription;
  StreamSubscription? _callSoundSubscription;
  ProviderSubscription<AsyncValue<UserEntity?>>? _authSubscription;
  Set<String> _knownNotificationIds = <String>{};
  Set<String> _knownFriendRequestIds = <String>{};
  Set<String> _knownCallIds = <String>{};
  late final ChatSoundService _chatSound =
      ChatSoundService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = ref.listenManual<AsyncValue<UserEntity?>>(
      authControllerProvider,
      (previous, next) {
        if (!mounted) return;

        final user = next.valueOrNull;
        if (user != null) {
          // onAuthStateChange يُطلق أيضًا عند تجديد التوكن (كل ساعة) وتحديث
          // بيانات المستخدم. كان كل إطلاق يعيد إنشاء قنوات الهدايا والتحويلات
          // والإشعارات والمكالمات — وإعادة الانضمام المتكررة للقنوات تنتج
          // channelError/timedOut. الربط يتم مرة واحدة لكل مستخدم مسجّل.
          if (user.uid != _boundUid) _handleAuthenticatedUser(user);
        } else {
          _boundUid = null;
          _updatePresence(false);
        }
      },
    );
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser != null) {
      _handleAuthenticatedUser(currentUser);
    }
    // يُستدعى مرة واحدة هنا (وليس داخل build()) — تسجيل مستمعين
    // (listeners) ذوي أثر جانبي دائم ينتمي إلى initState لا إلى
    // build، حتى لو كان هناك حارس تكرار (guard)؛ استدعاؤه من build
    // كان يعمل بالصدفة بفضل الحارس لكنه ممارسة خاطئة قد تسبب سلوكًا
    // غير متوقَّع مع أي تغيير مستقبلي في شجرة الودجت.
    _listenForBroadcasts();
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _authSubscription = null;

    _giftSubscription?.cancel();
    _giftSubscription = null;

    _transferSubscription?.cancel();
    _transferSubscription = null;

    _missedCallTimer?.cancel();
    _missedCallTimer = null;

    _broadcastSubscription?.cancel();
    _broadcastSubscription = null;

    _notificationSoundSubscription?.cancel();
    _notificationSoundSubscription = null;

    _friendSoundSubscription?.cancel();
    _friendSoundSubscription = null;

    _callSoundSubscription?.cancel();
    _callSoundSubscription = null;

    WidgetsBinding.instance.removeObserver(this);

    _updatePresence(false);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updatePresence(state == AppLifecycleState.resumed);
  }

  void _updatePresence(bool isOnline) async {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;

    // ميزة 10 من القائمة الإضافية: من فعّل "إخفاء حالة الاتصال"
    // (متاحة لمن يملك canHideOnlineStatus في عضويته) يبقى isOnline
    // مضبوطًا على false دائمًا بصرف النظر عن حالته الفعلية — بهذا
    // لا يظهر في "المتصلون الآن" ولا في حالة "متصل الآن" لأي محادثة.
    bool effectiveOnline = isOnline;
    if (isOnline) {
      try {
        final doc = await sl<SupabaseDocumentStore>()
            .collection(BackendCollections.accounts)
            .doc(uid)
            .get();
        if (doc.data()?['appearOffline'] == true) effectiveOnline = false;
      } catch (_) {
        // لا يمنع تحديث الحضور العادي عند فشل هذا الفحص الإضافي.
      }
    }

    sl<SetPresenceUseCase>().call(uid: uid, isOnline: effectiveOnline);

    // Records profiles.last_seen_at and captures the client IP SERVER-SIDE
    // (from the request headers inside the RPC) — the app never sends an IP
    // itself, because a client-supplied address is trivially spoofed. This
    // is deliberately independent of "appear offline": the true value is
    // stored, and it is only ever exposed to the platform owner (or an
    // account the owner explicitly granted), never to ordinary viewers.
    if (isOnline) {
      try {
        await Supabase.instance.client.rpc('touch_my_presence');
      } catch (_) {
        // Presence is best-effort and must never block the app.
      }
    }
  }

  /// يستمع لهدايا هذا المستخدم الواردة من أي محادثة (وليس فقط
  /// المحادثة المفتوحة حاليًا) ويشغّل [GiftAnimationOverlay] بملء
  /// الشاشة فورًا — بهذا تظهر رسوم الهدايا الكبيرة حتى لو كان
  /// المستخدم في شاشة أخرى من التطبيق.
  void _listenForGifts(String uid) {
    if (_giftSubscriptionUid == uid) return;
    _giftSubscription?.cancel();
    _giftSubscriptionUid = uid;
    _giftSubscription =
        sl<GiftRepository>().watchIncomingGifts(uid).listen((tx) async {
      if (!mounted) return;
      unawaited(_chatSound.play(ChatSoundEvent.gift));
      // الرسالة/واجهة الشات هي المصدر المرئي الوحيد للهدية؛
      // لا نعرض Overlay عالميًا هنا حتى لا تظهر الهدية مرتين داخل الخاص.
    });
  }

  StreamSubscription<List<Map<String, dynamic>>>? _transferSubscription;
  String? _transferSubscriptionUid;

  /// يستمع لأي تحويل نقاط/جواهر/شام‑كاش واردة من طرف آخر (لا من عملية
  /// ذاتية كالتبادل أو الشراء)، ويُشغّل صوت "تحويل" فورًا بصرف النظر
  /// عن الشاشة المفتوحة حاليًا — نفس نمط الاستماع للهدايا بالضبط، لكن
  /// مصدره سجل wallet_transactions الحقيقي على الخادم مباشرة.
  void _listenForTransfers(String uid) {
    if (_transferSubscriptionUid == uid) return;
    _transferSubscription?.cancel();
    _transferSubscriptionUid = uid;
    _transferSubscription = Supabase.instance.client
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final latest = rows.last;
      final amount = (latest['amount'] as num?) ?? 0;
      final createdBy = latest['created_by']?.toString();
      final createdAt = DateTime.tryParse(latest['created_at']?.toString() ?? '');
      final isFresh = createdAt != null &&
          DateTime.now().difference(createdAt) < const Duration(seconds: 10);
      if (amount > 0 && createdBy != null && createdBy != uid && isFresh) {
        unawaited(_chatSound.play(ChatSoundEvent.transfer));
      }
    });
  }

  /// يستمع لآخر بث من DRAGON (بصرف النظر عن تسجيل الدخول من عدمه —
  /// أي زائر يفتح التطبيق يرى البث أيضًا) ويعرض [BroadcastBanner]
  /// مرة واحدة فقط لكل بث جديد.
  void _listenForBroadcasts() {
    if (_broadcastListenerActive) return;
    _broadcastListenerActive = true;

    _broadcastSubscription =
        sl<BroadcastRepository>().watchLatestBroadcast().listen((broadcast) {
      if (broadcast == null || !mounted) return;

      final user = ref.read(authControllerProvider).valueOrNull;

      if (user == null) return;

      unawaited(_showBroadcastForUser(broadcast, user));
    });
  }

  Future<void> _showBroadcastForUser(
    dynamic broadcast,
    UserEntity user,
  ) async {
    try {
      final result = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (!mounted) return;
      BroadcastBanner.showIfVisible(
        context,
        broadcast,
        currentUserUid: user.uid,
        currentUserIsPlatformOwner: result == true,
      );
    } catch (_) {
      if (!mounted) return;
      BroadcastBanner.showIfVisible(
        context,
        broadcast,
        currentUserUid: user.uid,
        currentUserIsPlatformOwner: false,
      );
    }
  }

  void _listenForNotificationSounds(String uid) {
    _notificationSoundSubscription?.cancel();
    _notificationSoundSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('uid', uid)
        .listen((rows) {
          final ids = rows.map((r) => r['id'].toString()).toSet();
          if (_knownNotificationIds.isEmpty) {
            _knownNotificationIds = ids;
            return;
          }
          if (ids.difference(_knownNotificationIds).isNotEmpty) {
            unawaited(_chatSound.play(ChatSoundEvent.notification));
          }
          _knownNotificationIds = ids;
        });

    _friendSoundSubscription?.cancel();
    _callSoundSubscription?.cancel();
    _friendSoundSubscription = Supabase.instance.client
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .eq('to_uid', uid)
        .listen((rows) {
          final pending = rows
              .where((r) => r['status']?.toString() == 'pending')
              .map((r) => r['id'].toString())
              .toSet();
          if (_knownFriendRequestIds.isEmpty) {
            _knownFriendRequestIds = pending;
            return;
          }
          if (pending.difference(_knownFriendRequestIds).isNotEmpty) {
            unawaited(_chatSound.play(ChatSoundEvent.friendRequest));
          }
          _knownFriendRequestIds = pending;
        });
  }

  String? _boundUid;

  void _handleAuthenticatedUser(UserEntity user) {
    _boundUid = user.uid;
    _updatePresence(true);
    DragonBootstrapService.ensureDragonRole(user);
    _listenForGifts(user.uid);
    _listenForTransfers(user.uid);
    _listenForNotificationSounds(user.uid);
    _listenForCallSounds(user.uid);
    _startMissedCallSweep();
  }

  Timer? _missedCallTimer;

  /// المكالمة التي لا يردّ عليها أحد كانت تبقى "ترنّ" للأبد بلا أي نتيجة:
  /// حالة 'missed' لها إشعار جاهز على الخادم منذ البداية، لكن لا شيء كان
  /// يضع هذه الحالة إطلاقًا. هذا النبض يطلب من الخادم إنهاء المكالمات
  /// المعلّقة وإشعار أصحابها — القرار والتوقيت كلاهما على الخادم، والتطبيق
  /// يطلب التنفيذ فقط.
  void _startMissedCallSweep() {
    _missedCallTimer?.cancel();
    Future<void> sweep() async {
      try {
        await Supabase.instance.client.rpc('expire_stale_ringing_calls');
      } catch (_) {
        // فشل عابر (شبكة) لا يستدعي أي إزعاج للمستخدم؛ النبضة التالية تكفي.
      }
    }

    unawaited(sweep());
    _missedCallTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sweep()));
  }

  void _listenForCallSounds(String uid) {
    _callSoundSubscription?.cancel();
    _callSoundSubscription = Supabase.instance.client
        .from('app_documents')
        .stream(primaryKey: ['id'])
        .eq('collection_path', 'calls')
        .listen((rows) {
          final ringing = <String>{};
          for (final row in rows) {
            final data = row['data'] is Map
                ? Map<String, dynamic>.from(row['data'] as Map)
                : const <String, dynamic>{};
            if (data['calleeUid']?.toString() == uid &&
                data['status']?.toString() == 'ringing') {
              ringing.add(
                  row['doc_id']?.toString() ?? row['id']?.toString() ?? '');
            }
          }
          if (_knownCallIds.isEmpty) {
            _knownCallIds = ringing;
            return;
          }
          if (ringing.difference(_knownCallIds).isNotEmpty) {
            unawaited(_chatSound.play(ChatSoundEvent.call));
          }
          _knownCallIds = ringing;
        });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
