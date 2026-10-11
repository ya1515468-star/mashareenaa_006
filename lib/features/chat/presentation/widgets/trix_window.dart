part of 'trix_game.dart';

/// أوضاع نافذة اللعب: ملء الشاشة، نافذة عائمة قابلة للسحب، أو أيقونة صغيرة.
enum TrixWindowMode { full, float, mini }

/// حالة نافذة التركس العامة — مركّبة فوق التطبيق كله (Overlay في main.dart)
/// فتبقى المباراة حيّة أثناء التنقّل في الشات، ويمكن تصغيرها أو تكبيرها.
class TrixWindow {
  TrixWindow._();
  static final TrixWindow instance = TrixWindow._();

  final ValueNotifier<String?> gameId = ValueNotifier<String?>(null);
  final ValueNotifier<TrixWindowMode> mode = ValueNotifier<TrixWindowMode>(TrixWindowMode.full);
  final ValueNotifier<Offset> floatPos = ValueNotifier<Offset>(const Offset(10, 80));
  final ValueNotifier<Offset> miniPos = ValueNotifier<Offset>(const Offset(14, 150));
  final ValueNotifier<bool> myTurn = ValueNotifier<bool>(false);

  void openGame(String id) {
    gameId.value = id;
    mode.value = TrixWindowMode.full;
  }

  void setMode(TrixWindowMode m) => mode.value = m;

  /// إخفاء النافذة فقط — المباراة مستمرة في الخادم ويمكن العودة لها من مركز التركس.
  void close() {
    gameId.value = null;
    myTurn.value = false;
  }
}

/// المضيف العام للنافذة + مستمع دعوات الطاولات (يظهر طلب الدعوة أينما كان المستخدم).
class TrixFloatingHost extends StatefulWidget {
  const TrixFloatingHost({super.key});
  @override
  State<TrixFloatingHost> createState() => _TrixFloatingHostState();
}

class _TrixFloatingHostState extends State<TrixFloatingHost> {
  final GlobalKey _screenKey = GlobalKey();
  StreamSubscription<List<Map<String, dynamic>>>? _invSub;
  StreamSubscription<AuthState>? _authSub;
  final Set<String> _seenInvites = <String>{};
  Map<String, dynamic>? _prompt;
  String? _waitTable;
  Timer? _waitTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bindInvites();
    _authSub = _tdb.auth.onAuthStateChange.listen((_) => _bindInvites());
  }

  @override
  void dispose() {
    _invSub?.cancel();
    _authSub?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  void _bindInvites() {
    _invSub?.cancel();
    final uid = _tdb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      _invSub = _tdb
          .from('trix_table_invites')
          .stream(primaryKey: ['id'])
          .eq('to_uid', uid)
          .listen((rows) {
        for (final r in rows) {
          final id = r['id']?.toString();
          if (id == null || r['status'] != 'pending' || !_seenInvites.add(id)) continue;
          final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
          if (created != null && DateTime.now().toUtc().difference(created.toUtc()) > const Duration(minutes: 10)) continue;
          unawaited(_showInvite(id));
          break;
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _showInvite(String inviteId) async {
    try {
      final raw = await _tdb.rpc('trix_my_table_invites');
      if (raw is! List) return;
      for (final e in raw) {
        final m = Map<String, dynamic>.from(e as Map);
        if (m['id']?.toString() == inviteId && mounted) {
          playServerSound('game_request');
          setState(() => _prompt = m);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _respond(bool accept) async {
    final p = _prompt;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final tid = await _tdb.rpc('trix_table_respond', params: {'p_invite': p['id'], 'p_accept': accept});
      if (accept && tid != null) _watchTable(tid.toString());
      if (mounted) setState(() => _prompt = null);
    } catch (e) {
      if (mounted) {
        setState(() => _prompt = null);
        _toast(trixErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _watchTable(String tableId) {
    _waitTimer?.cancel();
    setState(() => _waitTable = tableId);
    _waitTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final raw = await _tdb.rpc('trix_table_view', params: {'p_table': tableId});
        if (raw is! Map) return;
        if (raw['status'] == 'started' && raw['game_id'] != null) {
          _waitTimer?.cancel();
          if (mounted) setState(() => _waitTable = null);
          playServerSound('game_start');
          TrixWindow.instance.openGame(raw['game_id'].toString());
        } else if (raw['status'] == 'cancelled') {
          _waitTimer?.cancel();
          if (mounted) setState(() => _waitTable = null);
          _toast('ألغى المضيف الطاولة واسترددت رهانك.');
        }
      } catch (_) {}
    });
  }

  String? _toastText;
  void _toast(String t) {
    setState(() => _toastText = t);
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(children: [
        ValueListenableBuilder<String?>(
          valueListenable: TrixWindow.instance.gameId,
          builder: (context, gid, _) {
            if (gid == null) return const SizedBox.shrink();
            return ValueListenableBuilder<TrixWindowMode>(
              valueListenable: TrixWindow.instance.mode,
              builder: (context, mode, _) => _window(context, gid, mode),
            );
          },
        ),
        if (_prompt != null) _invitePrompt(),
        if (_waitTable != null && _prompt == null) _waitingPill(),
        if (_toastText != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: IgnorePointer(
              child: Material(
                color: const Color(0xEE222222),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_toastText!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _window(BuildContext context, String gid, TrixWindowMode mode) {
    final size = MediaQuery.sizeOf(context);
    final screen = TrixScreen(key: _screenKey, gameId: gid, mode: mode);
    switch (mode) {
      case TrixWindowMode.full:
        return Positioned.fill(
          child: Material(color: const Color(0xFF0E0A18), child: SafeArea(child: screen)),
        );
      case TrixWindowMode.float:
        final w = math.min(size.width - 16, 370.0);
        final h = math.min(size.height * 0.68, w * 1.82);
        return ValueListenableBuilder<Offset>(
          valueListenable: TrixWindow.instance.floatPos,
          builder: (context, pos, _) {
            final left = pos.dx.clamp(0.0, math.max(0.0, size.width - w));
            final top = pos.dy.clamp(0.0, math.max(0.0, size.height - h));
            return Positioned(
              left: left,
              top: top,
              width: w,
              height: h,
              child: Material(
                elevation: 18,
                color: const Color(0xFF0E0A18),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => TrixWindow.instance.floatPos.value = Offset(left + d.delta.dx, top + d.delta.dy),
                    child: Container(
                      height: 22,
                      width: double.infinity,
                      color: const Color(0xFF231A38),
                      alignment: Alignment.center,
                      child: Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(width: 400, height: 760, child: screen),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      case TrixWindowMode.mini:
        return ValueListenableBuilder<Offset>(
          valueListenable: TrixWindow.instance.miniPos,
          builder: (context, pos, _) {
            final left = pos.dx.clamp(0.0, size.width - 64);
            final top = pos.dy.clamp(0.0, size.height - 64);
            return Stack(children: [
              // تبقى الشاشة مركّبة (مخفية) فتستمر المزامنة والأصوات.
              Offstage(child: SizedBox(width: 400, height: 760, child: screen)),
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onPanUpdate: (d) => TrixWindow.instance.miniPos.value = Offset(left + d.delta.dx, top + d.delta.dy),
                  onTap: () => TrixWindow.instance.setMode(TrixWindowMode.float),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: TrixWindow.instance.myTurn,
                    builder: (_, turn, __) => _MiniChip(myTurn: turn),
                  ),
                ),
              ),
            ]);
          },
        );
    }
  }

  Widget _invitePrompt() {
    final p = _prompt!;
    final partner = p['mode'] == 'partner';
    final seat = (p['seat'] as num?)?.toInt() ?? 1;
    return Positioned(
      left: 12,
      right: 12,
      top: 70,
      child: Material(
        color: const Color(0xFF241A3A),
        elevation: 16,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🃏 دعوة إلى طاولة تركس', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              '${p['from_name']} يدعوك ${partner ? (seat == 2 ? 'شريكًا له' : 'خصمًا له') : 'للعب فردي'} • ${trixVariantName[p['variant']] ?? ''}'
              '${((p['stake'] as num?) ?? 0) > 0 ? ' • رهان ${p['stake']} نقطة' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _respond(false), child: const Text('رفض'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: _busy ? null : () => _respond(true), child: const Text('قبول والجلوس'))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _waitingPill() {
    return Positioned(
      top: 70,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: const Color(0xEE241A3A),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              const Text('جالس على طاولة تركس — بانتظار المضيف', style: TextStyle(color: Colors.white, fontSize: 12.5)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                onPressed: () async {
                  final t = _waitTable;
                  _waitTimer?.cancel();
                  setState(() => _waitTable = null);
                  if (t != null) {
                    try {
                      await _tdb.rpc('trix_table_leave', params: {'p_table': t});
                    } catch (_) {}
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatefulWidget {
  final bool myTurn;
  const _MiniChip({required this.myTurn});
  @override
  State<_MiniChip> createState() => _MiniChipState();
}

class _MiniChipState extends State<_MiniChip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final glow = widget.myTurn ? 6 + 10 * _c.value : 4.0;
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF2E7D4F), Color(0xFF14522F)]),
            border: Border.all(color: widget.myTurn ? const Color(0xFFFFC107) : const Color(0xFF8D6E63), width: 3),
            boxShadow: [BoxShadow(color: (widget.myTurn ? const Color(0xFFFFC107) : Colors.black).withAlpha(140), blurRadius: glow)],
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🃏', style: TextStyle(fontSize: 22)),
            if (widget.myTurn) const Text('دورك', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
        );
      },
    );
  }
}
