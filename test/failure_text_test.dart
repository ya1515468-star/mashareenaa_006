import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/core/error/failure_text.dart';

void main() {
  group('لا يظهر أي تفصيل تقني للمستخدم', () {
    // النصوص الفعلية التي كانت تُعرَض للمستخدم، منقولة كما هي من
    // سجلّ المراقبة ومن رسائل Supabase.
    final samples = <String, Object>{
      'رابط تخزين Supabase':
          'HTTP request failed, statusCode: 400, https://aknksnctyqjcsxcwnvdz.supabase.co/storage/v1/object/public/profile-avatars/7ebf9aa4/1790873598971000_hmt7z1',
      'استثناء Realtime':
          'RealtimeSubscribeException(status: channelError, details: null)',
      'انقطاع الشبكة':
          'SocketException: Failed host lookup: \'aknksnctyqjcsxcwnvdz.supabase.co\'',
      'خطأ PostgREST':
          'PostgrestException(message: relation "public.frames" does not exist, code: 42P01)',
      'سياسة الصفوف':
          'new row violates row-level security policy for table "profiles"',
    };

    for (final entry in samples.entries) {
      test('${entry.key}: لا رابط ولا اسم جدول', () {
        final msg = FailureText.of(entry.value, subject: 'خلفيات الإطارات');
        expect(msg, isNot(contains('http')));
        expect(msg, isNot(contains('supabase')));
        expect(msg, isNot(contains('Exception')));
        expect(msg, isNot(contains('statusCode')));
        expect(msg, isNot(contains('public.')));
        expect(msg, isNot(contains('42P01')));
        // عربية فعلًا
        expect(RegExp(r'[؀-ۿ]').hasMatch(msg), isTrue);
      });
    }
  });

  test('البند ٦ حرفيًّا: انقطاع الإنترنت داخل المتجر', () {
    final msg = FailureText.of(
        'SocketException: Failed host lookup: \'aknksnctyqjcsxcwnvdz.supabase.co\'',
        subject: 'خلفيات الإطارات');
    expect(msg, 'تعذّر تحميل خلفيات الإطارات — تحقّق من الإنترنت وأعد المحاولة');
  });

  test('كل سبب يُصنَّف إلى جملته', () {
    expect(FailureText.classify('AUTH_REQUIRED'), FailureKind.auth);
    expect(FailureText.classify('FORBIDDEN'), FailureKind.forbidden);
    expect(FailureText.classify('INSUFFICIENT_POINTS'), FailureKind.insufficient);
    expect(FailureText.classify('DUPLICATE_REQUEST'), FailureKind.duplicate);
    expect(FailureText.classify('REEL_NOT_FOUND'), FailureKind.notFound);
    expect(FailureText.classify('INVALID_CATEGORY'), FailureKind.validation);
    expect(FailureText.classify('TimeoutException after 0:00:20'), FailureKind.timeout);
    expect(
        FailureText.classify('RealtimeSubscribeException(status: timedOut)'),
        FailureKind.offline);
    expect(
        FailureText.classify('HTTP request failed, statusCode: 500, https://x'),
        FailureKind.server);
  });

  test('عطل الشبكة يُعَدّ عارضًا، وخطأ الصلاحية لا', () {
    expect(FailureText.isTransient('SocketException: x'), isTrue);
    expect(
        FailureText.isTransient('RealtimeSubscribeException(status: channelError)'),
        isTrue);
    expect(FailureText.isTransient('FORBIDDEN'), isFalse);
    expect(FailureText.isTransient('INVALID_PLAN'), isFalse);
  });

  test('رسالة فعلٍ فشل تذكر الفعل', () {
    expect(FailureText.action('SocketException: x', action: 'الحفظ'),
        'تعذّر الحفظ — لا يوجد اتصال بالإنترنت');
    expect(FailureText.action('INSUFFICIENT_GEMS', action: 'الشراء'),
        'رصيدك لا يكفي');
  });
}
