# اختبارات MASHAREEN

## التشغيل

```bash
# كل الاختبارات
flutter test

# مجموعة واحدة
flutter test test/chat/name_effects_render_test.dart

# مع تقرير JSON للأرشفة
flutter test --reporter json > test_results.json
```

## أين تُسجَّل النتائج

**ثلاثة أماكن، كلٌّ لغرض:**

1. **الطرفية** — فوري أثناء التشغيل
2. **`test_results` على الخادم** — يُقرأ بـ`SELECT public.latest_test_run()`
3. **`test_results.json`** — أرشيف محلي إن استُعمل `--reporter json`

الشحن للخادم يعمل فقط في اختبارات التكامل (حيث Supabase مهيّأ).
اختبارات الوحدة تكتفي بالطرفية — لهذا تستدعي `TestReporter.disableRemote()`.

## البنية

```
test_support/                        ← خارج test/ عمدًا (انظر أدناه)
├── test_reporter.dart               ← يشحن النتائج للخادم
└── reported_test.dart               ← reportedTest / reportedUnit

test/
└── chat/
    ├── name_effects_render_test.dart   ← لغز المؤثرات (85 اختبارًا)
    └── message_style_logic_test.dart   ← منطق اللون والتنسيق
```

**لماذا `test_support/` خارج `test/`:** `flutter test` بلا مسار محدَّد
يفحص **كل** ملف `.dart` تحت `test/` ويحاول تشغيله كاختبار مستقل —
بصرف النظر عن اسمه أو المجلد الذي يقع فيه. ملف دعم بلا `main()` كان
تحت `test/support/` فرفضه الأمر بـ"Missing definition of `main`
method" وأوقف التشغيل بالكامل. الحل المعياري هو إخراج ملفات الدعم من
شجرة `test/` كليًا؛ لا نقلها إلى مجلد آخر تحتها.

## قراءة النتيجة من الخادم

```sql
SELECT jsonb_pretty(public.latest_test_run());
```

يُرجع: معرّف التشغيل، عدد النجاح والفشل، وتفاصيل كل فشل
(المتوقَّع، الفعلي، رسالة الخطأ).

## لماذا `reportedTest` بدل `testWidgets` مباشرة

اللفّ يضمن شحن نتيجة **كل** اختبار بلا استثناء. الحلّ البديل —
try/catch في كل اختبار — يُنسى في واحد أو اثنين فتضيع نتيجتهما بصمت.

## ما لا تكشفه هذه الاختبارات

- تشغيل الفيديو الفعلي (المحاكي لا يشغّل الكوديك)
- الأحكام الجمالية ("هذا يبدو كبيرًا")
- سلوك الشبكة الضعيفة والأجهزة البطيئة

للأولين: اللقطة الذهبية (`matchesGoldenFile`) تكشف **التغيّر** لا القبح.
