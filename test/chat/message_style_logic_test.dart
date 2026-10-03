import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/gamification/domain/entities/username_effect.dart';

import '../../test_support/reported_test.dart';
import '../../test_support/test_reporter.dart';

/// منطق تحويل ما يرسله الخادم إلى قيم رسم.
///
/// هذه الطبقة هي الأكثر عرضة للانكسار الصامت: خطأ هنا لا يرمي
/// استثناءً — يعطي لونًا خاطئًا أو مؤثرًا مفقودًا فيبدو كأن الميزة
/// "لا تعمل" بلا أي أثر في السجل. لذلك تُختبر بالقيم الحقيقية
/// المأخوذة من قاعدة البيانات نفسها لا بقيم مخترعة.
void main() {
  TestReporter.disableRemote();

  /// نسخة طبق الأصل من منطق التحويل في chat_lobby_page
  Color? colorFromIdentity(Map<String, dynamic> identity) {
    final hex =
        (identity['message_color_1'] ?? '').toString().replaceAll('#', '').trim();
    final legacy = int.tryParse(identity['message_color']?.toString() ?? '');
    if (hex.length == 6) {
      final n = int.tryParse('FF$hex', radix: 16);
      if (n != null) return Color(n);
    } else if (legacy != null && legacy != 4294967295) {
      return Color(legacy);
    }
    return null;
  }

  // ─── لون الرسالة ──────────────────────────────────────────────
  reportedUnit('color', 'hex من الكتالوج يُحوَّل صحيحًا', () async {
    // #39FF14 هو لون dragon الفعلي على الخادم
    final c = colorFromIdentity({'message_color_1': '#39FF14'});
    expect(c, isNotNull, reason: 'لم يُحوَّل اللون إطلاقًا');
    expect(c!.toARGB32(), 0xFF39FF14);
  });

  reportedUnit('color', 'hex بلا # يُقبل أيضًا', () async {
    expect(colorFromIdentity({'message_color_1': '39FF14'})?.toARGB32(),
        0xFF39FF14);
  });

  reportedUnit('color', 'الأبيض الافتراضي يعني "بلا اختيار"', () async {
    // 4294967295 = 0xFFFFFFFF: قيمة العمود الافتراضية، ليست اختيارًا
    // فعليًا للعضو، فيجب أن تُترك ليأخذ لون الغرفة الأساسي.
    expect(colorFromIdentity({'message_color': '4294967295'}), isNull);
  });

  reportedUnit('color', 'bigint قديم يُستعمل حين لا hex', () async {
    expect(colorFromIdentity({'message_color': '4281990932'}), isNotNull);
  });

  reportedUnit('color', 'hex تالف لا يُسقط شيئًا', () async {
    expect(colorFromIdentity({'message_color_1': 'ZZZZZZ'}), isNull);
    expect(colorFromIdentity({'message_color_1': '#12'}), isNull);
    expect(colorFromIdentity({}), isNull);
  });

  reportedUnit('color', 'hex يسبق bigint عند وجودهما', () async {
    final c = colorFromIdentity(
        {'message_color_1': '#FF0000', 'message_color': '4281990932'});
    expect(c!.toARGB32(), 0xFFFF0000,
        reason: 'message_color_1 هو ما تكتبه set_my_message_color فعليًا، '
            'فيجب أن يسبق العمود القديم');
  });

  // ─── تنسيق الخط ───────────────────────────────────────────────
  double clampScale(dynamic raw) {
    final v = double.tryParse(raw?.toString() ?? '') ?? 1.0;
    return (14.0 * v).clamp(11.0, 22.0);
  }

  reportedUnit('style', 'مقياس الخط ضمن الحدود', () async {
    expect(clampScale('1.0'), 14.0);
    expect(clampScale('1.25'), 17.5);
    // closeTo لا == : 14.0 * 0.80 يعطي 11.200000000000001 في الفاصلة
    // العائمة ثنائية الأساس. المقارنة الحرفية هنا كانت خطأ في
    // الاختبار نفسه لا في الكود المُختبَر.
    expect(clampScale('0.80'), closeTo(11.2, 0.0001));
  });

  reportedUnit('style', 'مقياس شاذ يُحجَّم', () async {
    // الخادم يحدّ بين 0.80 و1.60، لكن العميل لا يثق: قيمة تالفة
    // قادمة من أي مسار يجب ألا تفجّر تخطيط الغرفة على الجميع.
    expect(clampScale('99'), 22.0);
    expect(clampScale('-5'), 11.0);
    expect(clampScale('نص'), 14.0);
    expect(clampScale(null), 14.0);
  });

  // ─── سجل المؤثرات ─────────────────────────────────────────────
  reportedUnit('effects', 'fromWire يطابق galaxy', () async {
    expect(UsernameEffectX.fromWire('galaxy'), UsernameEffect.galaxy);
  });

  reportedUnit('effects', 'مؤثر مجهول يعود none لا يرمي', () async {
    expect(UsernameEffectX.fromWire('لا_وجود_له'), UsernameEffect.none);
    expect(UsernameEffectX.fromWire(null), UsernameEffect.none);
    expect(UsernameEffectX.fromWire(''), UsernameEffect.none);
  });

  reportedUnit('effects', 'كل مؤثر له wire فريد', () async {
    final wires = UsernameEffect.values.map((e) => e.wire).toList();
    expect(wires.toSet().length, wires.length,
        reason: 'wire مكرر يعني أن مؤثرين يتنازعان المفتاح نفسه، '
            'فيظهر أحدهما دائمًا مكان الآخر');
  });

  reportedUnit('effects', 'كل wire يعود لمؤثره', () async {
    // ذهابًا وإيابًا: أي انكسار هنا يعني مؤثرًا مشتراة ولا تظهر
    for (final e in UsernameEffect.values) {
      expect(UsernameEffectX.fromWire(e.wire), e,
          reason: 'المؤثر ${e.name} لا يعود من wire الخاص به');
    }
  });

  tearDownAll(() => TestReporter.summary());
}
