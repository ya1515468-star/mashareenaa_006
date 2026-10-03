import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/gamification/domain/entities/username_effect.dart';
import 'package:mashareena/features/gamification/presentation/widgets/username_cosmetic_name.dart';
import 'package:mashareena/features/gamification/presentation/widgets/username_effect_text.dart';

import '../../test_support/reported_test.dart';
import '../../test_support/test_reporter.dart';

/// يحسم لغز "المؤثرات تُطبَّق ولا تظهر".
///
/// تحقّقتُ خادميًا أن get_user_chat_identity تُرجع القيم صحيحة
/// (galaxy, name_template_01, namebg_custom_solid)، وأن كل حلقة في
/// سلسلة القراءة سليمة. يبقى احتمال واحد لم يُختبر: الرسم نفسه.
///
/// هذه المجموعة تبني الودجت بالقيم الحقيقية نفسها وتتحقق أنها
/// رُسمت فعلًا — فإن فشلت عرفنا المكان بالضبط، وإن نجحت نفينا
/// الرسم من قائمة المشتبهين نهائيًا.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // اختبارات وحدة نقية: لا Supabase مهيّأ، فنكتفي بالطباعة المحلية
  TestReporter.disableRemote();

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(child: child),
          ),
        ),
      );

  // ─── 1) المؤثر وحده ───────────────────────────────────────────
  reportedTest('effects', 'مؤثر galaxy يُرسم', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'dragon',
      effect: UsernameEffect.galaxy,
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('dragon'), findsWidgets,
        reason: 'الاسم نفسه لم يُرسم إطلاقًا');
    expect(find.byType(UsernameEffectText), findsWidgets,
        reason: 'UsernameEffectText غائب — المؤثر لم يصل طبقة الرسم');
  });

  // ─── 2) كل الـ76 مؤثرًا ───────────────────────────────────────
  // يدويًا يحتاج 76 محاولة؛ هنا ثوانٍ. يكشف المؤثر المعطوب تحديدًا
  // بدل "المؤثرات لا تعمل" المبهمة.
  for (final effect in UsernameEffect.values) {
    reportedTest('effects.all', 'يُرسم ${effect.name}', (tester) async {
      await tester.pumpWidget(wrap(UsernameCosmeticName(
        name: 'عضو',
        effect: effect,
      )));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull,
          reason: 'المؤثر ${effect.name} رمى استثناءً أثناء الرسم');
      expect(find.byType(UsernameCosmeticName), findsOneWidget);
    });
  }

  // ─── 3) القالب ────────────────────────────────────────────────
  reportedTest('effects', 'قالب name_template_01 يُرسم', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'dragon',
      effect: UsernameEffect.galaxy,
      templateKey: 'name_template_01',
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // القالب صورة خلفية؛ وجود Image يعني أن السجل طابق المفتاح
    expect(find.byType(Image), findsWidgets,
        reason: 'لا صورة — NameTemplateRegistry لم يطابق المفتاح، '
            'أو الأصل غير معلَن في pubspec');
  });

  reportedTest('effects', 'قالب غير موجود لا يُسقط الودجت', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'dragon',
      effect: UsernameEffect.none,
      templateKey: 'مفتاح_لا_وجود_له',
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('dragon'), findsWidgets,
        reason: 'قالب مجهول أخفى الاسم — يجب أن يتجاهله لا أن يحجبه');
  });

  // ─── 4) الخلفية ───────────────────────────────────────────────
  reportedTest('effects', 'خلفية الاسم تُرسم', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'dragon',
      effect: UsernameEffect.none,
      backgroundMode: 'solid',
      backgroundColor1: '#1B03A3',
      backgroundColor2: '#1B03A3',
    )));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.byType(DecoratedBox), findsWidgets,
        reason: 'لا DecoratedBox — الخلفية لم تُرسم');
  });

  reportedTest('effects', 'وضع dual يقبل لونين', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'عضو',
      effect: UsernameEffect.none,
      backgroundMode: 'dual',
      backgroundColor1: '#FF0000',
      backgroundColor2: '#0000FF',
    )));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  // ─── 5) التركيبة الكاملة — حالة dragon الحقيقية ────────────────
  reportedTest('effects', 'التركيبة الحقيقية لحساب dragon', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'dragon',
      effect: UsernameEffect.galaxy,
      templateKey: 'name_template_01',
      backgroundMode: 'solid',
      backgroundColor1: '#1B03A3',
      backgroundColor2: '#1B03A3',
      fontSize: 15,
    )));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'التركيبة الكاملة رمت استثناءً — وهذا سبب اختفاء كل شيء');
    expect(find.text('dragon'), findsWidgets);
  });

  // ─── 6) القيم الحدّية ─────────────────────────────────────────
  reportedTest('effects', 'اسم فارغ لا يُسقط الودجت', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: '',
      effect: UsernameEffect.galaxy,
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  reportedTest('effects', 'لون غير صالح لا يُسقط الودجت', (tester) async {
    await tester.pumpWidget(wrap(const UsernameCosmeticName(
      name: 'عضو',
      effect: UsernameEffect.none,
      backgroundMode: 'solid',
      backgroundColor1: 'ليس لونًا',
    )));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'لون تالف من الخادم يجب أن يُتجاهل لا أن يُسقط الاسم');
  });

  reportedTest('effects', 'اسم طويل جدًا لا يفيض', (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 120,
      child: UsernameCosmeticName(
        name: 'ا' * 120,
        effect: UsernameEffect.galaxy,
        templateKey: 'name_template_01',
      ),
    )));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull,
        reason: 'اسم طويل فجّر التخطيط — وهذا نمط BoxConstraints نفسه');
  });

  tearDownAll(() => debugPrint(TestReporter.summary()));
}
