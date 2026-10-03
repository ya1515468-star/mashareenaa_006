import 'package:flutter_test/flutter_test.dart';

import 'test_reporter.dart';

/// `reportedTest` بديل `test` يشحن النتيجة للخادم تلقائيًا.
///
/// السبب: الحلّ الساذج هو كتابة try/catch في كل اختبار — تكرار ممل
/// يُنسى في اختبار أو اثنين فتضيع نتيجتهما بصمت. اللفّ هنا يضمن أن
/// كل اختبار يُبلَّغ عنه، نجح أو فشل، بلا استثناء.
void reportedTest(
  String suite,
  String name,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets('$suite › $name', (tester) async {
    final sw = Stopwatch()..start();
    try {
      await body(tester);
      sw.stop();
      await TestReporter.record(
        suite: suite,
        testName: name,
        passed: true,
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e, st) {
      sw.stop();
      // نفكّك رسالة TestFailure لاستخراج المتوقَّع والفعلي، فالخادم
      // يخزّنهما منفصلين ويصيران قابلين للقراءة بلا تحليل نصّي لاحق.
      String? expected, actual;
      final msg = e.toString();
      final mExp = RegExp(r'Expected:\s*(.+)').firstMatch(msg);
      final mAct = RegExp(r'Actual:\s*(.+)').firstMatch(msg);
      if (mExp != null) expected = mExp.group(1)?.trim();
      if (mAct != null) actual = mAct.group(1)?.trim();

      await TestReporter.record(
        suite: suite,
        testName: name,
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        expected: expected,
        actual: actual,
        failure: msg.split('\n').take(6).join('\n'),
        stack: st.toString(),
      );
      rethrow; // الاختبار يبقى فاشلًا في الطرفية أيضًا
    }
  });
}

/// نسخة لا تحتاج WidgetTester — لاختبارات المنطق النقي
void reportedUnit(String suite, String name, Future<void> Function() body) {
  test('$suite › $name', () async {
    final sw = Stopwatch()..start();
    try {
      await body();
      sw.stop();
      await TestReporter.record(
          suite: suite,
          testName: name,
          passed: true,
          durationMs: sw.elapsedMilliseconds);
    } catch (e, st) {
      sw.stop();
      await TestReporter.record(
        suite: suite,
        testName: name,
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        failure: e.toString().split('\n').take(6).join('\n'),
        stack: st.toString(),
      );
      rethrow;
    }
  });
}
