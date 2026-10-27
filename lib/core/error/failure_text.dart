/// ترجمة أيّ عطل إلى سبب يفهمه المستخدم، بالعربية، بلا أي تفصيل تقني.
///
/// لماذا مركزيًّا: كان كل سطح يعرض `'$e'` كما هو، فيظهر للمستخدم رابط
/// قاعدة البيانات ورمز الحالة واسم الجدول — وهو كشفٌ لبنية الخادم بلا
/// فائدة له، ولا يدلّه على ما يفعل. والرسالة المكرّرة في عشرين موضعًا
/// تعني أنّ تحسينها يستلزم تعديل عشرين موضعًا.
///
/// القاعدة: لا يُعرَض نصّ الاستثناء إطلاقًا. يُصنَّف السبب، وتُقال
/// الجملة المناسبة له، ويُقال معها ما يفعله المستخدم.
library;

/// تصنيف العطل — يُستعمل كذلك لتحديد خطورته في المراقبة.
enum FailureKind {
  offline,
  timeout,
  server,
  forbidden,
  auth,
  insufficient,
  validation,
  notFound,
  duplicate,
  unknown,
}

class FailureText {
  const FailureText._();

  /// جملة عربية واحدة تصف السبب وتقول ما يُفعَل.
  ///
  /// [subject] ما كان يُحاول تحميله، ليُدمَج في الجملة: «خلفيات
  /// الإطارات»، «الرسائل». تركه فارغًا يعطي جملة عامّة سليمة.
  static String of(Object? error, {String? subject}) {
    final kind = classify(error);
    final what =
        (subject == null || subject.trim().isEmpty) ? null : subject.trim();

    switch (kind) {
      case FailureKind.offline:
        return what == null
            ? 'لا يوجد اتصال بالإنترنت — تحقّق من الاتصال وأعد المحاولة'
            : 'تعذّر تحميل $what — تحقّق من الإنترنت وأعد المحاولة';
      case FailureKind.timeout:
        return what == null
            ? 'الاتصال بطيء ولم يكتمل الطلب — أعد المحاولة'
            : 'تعذّر تحميل $what: الاتصال بطيء — أعد المحاولة';
      case FailureKind.server:
        return what == null
            ? 'تعذّر إكمال الطلب الآن — أعد المحاولة بعد قليل'
            : 'تعذّر تحميل $what الآن — أعد المحاولة بعد قليل';
      case FailureKind.forbidden:
        return 'لا تملك صلاحية لهذا الإجراء';
      case FailureKind.auth:
        return 'انتهت الجلسة — أعد تسجيل الدخول';
      case FailureKind.insufficient:
        return 'رصيدك لا يكفي لهذا الإجراء';
      case FailureKind.validation:
        return 'تحقّق من البيانات المُدخَلة ثم أعد المحاولة';
      case FailureKind.notFound:
        return what == null ? 'العنصر غير موجود' : 'لم يُعثر على $what';
      case FailureKind.duplicate:
        return 'هذا الإجراء نُفِّذ بالفعل';
      case FailureKind.unknown:
        return what == null
            ? 'حدث خطأ غير متوقّع — أعد المحاولة'
            : 'تعذّر تحميل $what — أعد المحاولة';
    }
  }

  /// رسالة فعلٍ فشل (حفظ، نشر، شراء) لا تحميلٍ فشل.
  static String action(Object? error, {required String action}) {
    switch (classify(error)) {
      case FailureKind.offline:
        return 'تعذّر $action — لا يوجد اتصال بالإنترنت';
      case FailureKind.timeout:
        return 'تعذّر $action — الاتصال بطيء، أعد المحاولة';
      case FailureKind.forbidden:
        return 'لا تملك صلاحية $action';
      case FailureKind.auth:
        return 'انتهت الجلسة — أعد تسجيل الدخول ثم أعد المحاولة';
      case FailureKind.insufficient:
        return 'رصيدك لا يكفي';
      case FailureKind.validation:
        return 'تحقّق من البيانات ثم أعد $action';
      case FailureKind.notFound:
        return 'العنصر غير موجود';
      case FailureKind.duplicate:
        return 'نُفِّذ بالفعل';
      case FailureKind.server:
      case FailureKind.unknown:
        return 'تعذّر $action — أعد المحاولة بعد قليل';
    }
  }

  /// هل العطل عارض من الشبكة؟ تُستعمل في المراقبة: عطل شبكة عابر ليس
  /// خللًا في التطبيق، وتسجيله fatal يُغرق تقرير الأخطاء الحقيقية.
  static bool isTransient(Object? error) {
    final k = classify(error);
    return k == FailureKind.offline || k == FailureKind.timeout;
  }

  static FailureKind classify(Object? error) {
    if (error == null) return FailureKind.unknown;
    final s = error.toString();
    final l = s.toLowerCase();

    // رموز الخادم الصريحة أوّلًا: أدقّ من أي استنتاج من نصّ الاستثناء.
    if (s.contains('AUTH_REQUIRED') ||
        l.contains('jwt expired') ||
        l.contains('invalid refresh token') ||
        l.contains('not authenticated')) {
      return FailureKind.auth;
    }
    if (s.contains('FORBIDDEN') ||
        s.contains('OWNER_ONLY') ||
        s.contains('ACCESS_REVOKED') ||
        s.contains('NOT_OWNED') ||
        s.contains('TOO_HIGH') ||
        l.contains('permission denied') ||
        l.contains('row-level security') ||
        l.contains('violates row level')) {
      return FailureKind.forbidden;
    }
    if (s.contains('INSUFFICIENT')) return FailureKind.insufficient;
    if (s.contains('DUPLICATE') || s.contains('ALREADY_')) {
      return FailureKind.duplicate;
    }
    if (s.contains('NOT_FOUND') || s.contains('_MISSING')) {
      return FailureKind.notFound;
    }
    if (s.contains('INVALID_') ||
        s.contains('_REQUIRED') ||
        s.contains('TOO_LONG') ||
        s.contains('TOO_MANY')) {
      return FailureKind.validation;
    }

    // انقطاع الشبكة بكل أشكاله التي تُنتجها حزم Dart فعليًّا.
    if (l.contains('socketexception') ||
        l.contains('failed host lookup') ||
        l.contains('network is unreachable') ||
        l.contains('connection refused') ||
        l.contains('connection reset') ||
        l.contains('connection closed') ||
        l.contains('handshakeexception') ||
        l.contains('clientexception') ||
        l.contains('xmlhttprequest') ||
        l.contains('no internet') ||
        l.contains('realtimesubscribeexception') ||
        l.contains('channelerror') ||
        l.contains('realtimecloseevent')) {
      return FailureKind.offline;
    }
    if (l.contains('timeoutexception') ||
        l.contains('timed out') ||
        l.contains('timedout') ||
        l.contains('deadline exceeded')) {
      return FailureKind.timeout;
    }

    // ردود HTTP.
    final code = RegExp(r'statusCode:\s*(\d{3})').firstMatch(s)?.group(1);
    if (code != null) {
      final n = int.tryParse(code) ?? 0;
      if (n == 401) return FailureKind.auth;
      if (n == 403) return FailureKind.forbidden;
      if (n == 404) return FailureKind.notFound;
      if (n == 408 || n == 504) return FailureKind.timeout;
      if (n >= 500) return FailureKind.server;
      if (n >= 400) return FailureKind.validation;
    }

    if (l.contains('postgrest') || l.contains('supabase')) {
      return FailureKind.server;
    }
    return FailureKind.unknown;
  }
}
