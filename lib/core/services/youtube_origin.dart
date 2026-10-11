/// هوية المضمِّن (Embedder) لمشغّل يوتيوب داخل WebView أندرويد.
/// يوتيوب يرفض التضمين بخطأ "152-4" (EMBEDDER_IDENTITY_DENIED) إن لم يصله
/// Referer/origin يعرّف التطبيق. في youtube_player_iframe ≥ 6 قيمة origin
/// تُستعمل كـbaseUrl للصفحة (فتصبح الـReferer) وكـplayerVars.origin، بينما
/// host (youtube-nocookie) يبقى نطاق المشغّل الحقيقي — فلا يتكرر خطأ المحاولة
/// القديمة التي كسرت التحميل حين كانت القيمة نفسها تُستعمل كـhost في الإصدار 5.
/// سجل المحاولات على هذه القيمة تحديدًا، حتى لا تُعاد دائرة فاشلة:
///   ١) بلا origin (افتراضي المكتبة) → "This video is unavailable 152-4".
///   ٢) 'https://com.mashareena.mashareena' → الصفحة لا تُحمَّل. وهذه ليست
///      مضيفًا صالحًا أصلًا: `com.mashareena.mashareena` اسم حزمة أندرويد
///      لا نطاقًا موجودًا في DNS، وفي الإصدار 6 تُستعمل هذه القيمة
///      baseUrl للصفحة — فأصل الصفحة نطاق وهمي، وواجهة iframe من يوتيوب
///      ترفض التهيئة فيبقى المشغّل صفحة فارغة (رمادية/فضية). ظهر هذا
///      صريحًا بعد تعطيل Impeller: صار سطح الـWebView يُركَّب فعليًا،
///      فرأينا محتواه الحقيقي — صفحة فارغة لا فيديو.
///   ٣) 'https://www.youtube.com' → كان خطأً: الفيديو لم يعمل إطلاقًا.
///
/// القيمة الصحيحة هي (٢) بنصّ شرط يوتيوب الرسمي (Required Minimum
/// Functionality → Embedder identity): تطبيقات أندرويد التي تحمّل ملف
/// HTML محليًا تضبط الهوية عبر baseUrl، ويجب أن يكون رابط HTTPS **نطاقه
/// معرّف التطبيق** بصيغة reverse-DNS، مثل https://com.google.android.youtube.
/// أي أن عدم وجود النطاق في DNS مقصود ولا يضرّ — ليس سبب غياب الصورة.
/// سبب الصورة في تركيب سطح الفيديو، لا في هذه القيمة؛ فلا تُغيَّر.
const String kYoutubeEmbedOrigin = 'https://com.mashareena.mashareena';
