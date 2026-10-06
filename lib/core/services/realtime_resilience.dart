import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مدير استعادة اتصال واحد للتطبيق كله.
///
/// المسؤوليات:
/// - تمرير أحدث JWT إلى Realtime بعد كل token refresh/sign-in.
/// - إعادة مزامنة Realtime عند عودة الإنترنت أو التطبيق من الخلفية.
/// - منع عمليات refresh المتوازية التي قد تستهلك refresh token الدوّار مرتين.
/// - ترك الـSDK يدير إعادة فتح WebSocket والقنوات القائمة تلقائيًا بعد تحديث auth.
class RealtimeResilience with WidgetsBindingObserver {
  RealtimeResilience._();

  static final instance = RealtimeResilience._();

  bool _installed = false;
  bool _recovering = false;
  String? _lastRealtimeToken;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void install() {
    if (_installed) return;
    _installed = true;

    WidgetsBinding.instance.addObserver(this);

    final client = Supabase.instance.client;

    // Auth errors must never become uncaught async exceptions. More
    // importantly, tokenRefreshed is the authoritative hand-off point for
    // the Realtime JWT.
    _authSubscription = client.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        if (session?.accessToken != null) {
          unawaited(_syncRealtimeAuth(session!.accessToken));
        }
      },
      onError: (_) {
        // Offline/refresh failures are transient; the next recovery point
        // (network restored, app resumed, or SDK retry) will retry safely.
      },
    );

    final connectivity = Connectivity();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          unawaited(_recover(forceRefreshIfNearExpiry: false));
        }
      },
      onError: (_) {},
    );

    final current = client.auth.currentSession;
    if (current?.accessToken != null) {
      unawaited(_syncRealtimeAuth(current!.accessToken));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recover(forceRefreshIfNearExpiry: true));
    }
  }

  Future<void> _syncRealtimeAuth(String token) async {
    if (token.isEmpty || token == _lastRealtimeToken) return;
    try {
      await Supabase.instance.client.realtime.setAuth(token);
      _lastRealtimeToken = token;
    } catch (_) {
      // Do not bring down the app for an auxiliary Realtime auth sync.
    }
  }

  Future<void> _recover({required bool forceRefreshIfNearExpiry}) async {
    if (_recovering) return;
    _recovering = true;

    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      if (session == null) return;

      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nearExpiry =
          expiresAt == null || expiresAt - now < 120;

      if (forceRefreshIfNearExpiry && nearExpiry) {
        try {
          // Exactly one in-flight refresh is allowed by this manager.
          final refreshed = await client.auth.refreshSession();
          session = refreshed.session ?? client.auth.currentSession ?? session;
        } catch (_) {
          // A temporary network failure must not sign the user out.
          session = client.auth.currentSession ?? session;
        }
      }

      final token = session.accessToken;
      await _syncRealtimeAuth(token);
    } finally {
      _recovering = false;
    }
  }

  void dispose() {
    if (!_installed) return;
    _installed = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    _authSubscription = null;
    _connectivitySubscription = null;
  }
}
