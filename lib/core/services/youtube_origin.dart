/// هوية المضمِّن (Embedder) لمشغّل يوتيوب داخل WebView أندرويد.
/// يوتيوب يرفض التضمين بخطأ "152-4" (EMBEDDER_IDENTITY_DENIED) إن لم يصله
/// Referer/origin يعرّف التطبيق. في youtube_player_iframe ≥ 6 قيمة origin
/// تُستعمل كـbaseUrl للصفحة (فتصبح الـReferer) وكـplayerVars.origin، بينما
/// host (youtube-nocookie) يبقى نطاق المشغّل الحقيقي — فلا يتكرر خطأ المحاولة
/// القديمة التي كسرت التحميل حين كانت القيمة نفسها تُستعمل كـhost في الإصدار 5.
const String kYoutubeEmbedOrigin = 'https://com.mashareena.mashareena';
