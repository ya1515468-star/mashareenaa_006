import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// غلاف خفيف يجعل أي قناة Realtime "دائمة" بالمعنى الحقيقي: إن وصلت
/// حالتها إلى channelError أو timedOut (توكن منتهي، مشكلة شبكة لحظية،
/// إعادة تشغيل الخادم، ...) تُعاد بناء القناة من الصفر وإعادة الاشتراك
/// تلقائيًا بعد تأخير قصير، بدل أن تبقى القناة ميتة إلى الأبد وتصل كل
/// محاولة لاحقة (إرسال typing، استقبال رسالة) بلا أي أثر ظاهر للمستخدم.
///
/// هذا بالضبط نفس النمط المُطبَّق في globalServerRealtimeSyncProvider —
/// مُستخرَج هنا إلى غلاف واحد قابل لإعادة الاستخدام عبر كل قنوات الشات
/// (الغرفة العامة، الخاص، الكتابة، المقاعد الصوتية) بدل تكرار نفس منطق
/// إعادة المحاولة خمس أو ست مرات بشكل منفصل عرضة للاختلاف بينها.
///
/// كل محاولة إعادة اشتراك تبني قناة جديدة بالكامل عبر [build] لأن
/// RealtimeChannel يسمح بنداء subscribe() مرة واحدة فقط طوال عمر
/// الكائن — إعادة النداء على نفس الكائن القديم يرمي
/// "tried to subscribe multiple times".
class ResilientRealtimeChannel {
  ResilientRealtimeChannel({
    required SupabaseClient client,
    required RealtimeChannel Function(SupabaseClient client) build,
    this.retryDelay = const Duration(seconds: 5),
  })  : _client = client,
        _build = build {
    _subscribe();
  }

  final SupabaseClient _client;
  final RealtimeChannel Function(SupabaseClient client) _build;
  final Duration retryDelay;

  RealtimeChannel? _channel;
  Timer? _retryTimer;
  bool _disposed = false;

  /// القناة الحالية الحيّة — قد تتغيّر هويتها (كائن جديد) بعد كل إعادة
  /// اشتراك تلقائية، فلا يصح لأي مستدعٍ الاحتفاظ بمرجع قديم لها.
  RealtimeChannel? get channel => _channel;

  void _subscribe() {
    if (_disposed) return;
    final fresh = _build(_client);
    _channel = fresh.subscribe((status, error) {
      if (_disposed) return;
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        _retryTimer?.cancel();
        _retryTimer = Timer(retryDelay, () {
          if (_disposed) return;
          final dead = _channel;
          _channel = null;
          if (dead != null) unawaited(_client.removeChannel(dead));
          _subscribe();
        });
      }
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) await _client.removeChannel(ch);
  }
}

/// مُعين اشتراك بإعادة اتصال، لمواقع النداء التي تبني القناة سطريًّا.
///
/// لماذا وُجد: ستّ قنوات في التطبيق كانت تشترك بـ`(_, __) {}` — تبتلع
/// الخطأ ولا تُعيد الاتصال أبدًا. فإذا انقطعت الشبكة لحظةً أو انتهى
/// التوكن، تبقى القناة ميتة إلى أن يُعاد فتح الشاشة، والمستخدم يرى بيانات
/// قديمة ولا يفهم لماذا. وسابعة كانت `..subscribe()` بلا معالج أصلًا،
/// فيهرب RealtimeSubscribeException إلى المنطقة ويُسجَّل خطأً قاتلًا —
/// وهو أكثر خطأ تكرارًا في سجلّ المراقبة (38 مرّة على 6 مستخدمين).
///
/// [onRetry] تُستدعى لإعادة بناء القناة من الصفر، لأنّ RealtimeChannel
/// يقبل subscribe() مرّة واحدة في عمره.
void Function(RealtimeSubscribeStatus, Object?) retryOnChannelError(
  void Function() onRetry, {
  Duration delay = const Duration(seconds: 3),
  bool Function()? isAlive,
}) {
  var scheduled = false;
  return (status, error) {
    if (status != RealtimeSubscribeStatus.channelError &&
        status != RealtimeSubscribeStatus.timedOut) {
      return;
    }
    // مرّة واحدة لكل قناة: الحالة قد تتكرّر فلا تُجدوَل محاولات متراكمة.
    if (scheduled) return;
    scheduled = true;
    Timer(delay, () {
      if (isAlive != null && !isAlive()) return;
      onRetry();
    });
  };
}
