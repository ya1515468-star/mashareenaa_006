# MASHAREENA — قواعد R8 لنسخة الإصدار.
#
# R8 يُعتّم ويُقلّص شيفرة Kotlin/Java. أمّا منطق التطبيق فبـDart ويُعتَّم
# بـ`flutter build --obfuscate` في ملف البناء، لا هنا.

# ── إبقاء ما يُكتشف عبر الانعكاس أو قنوات المنصّة ──
# إضافات Flutter تُسجَّل بالاسم عبر GeneratedPluginRegistrant.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Agora: مكتبة أصلية تُنادى عبر JNI؛ تغيير الأسماء يكسر الربط.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Play Core/Deferred Components: مراجع اختيارية قد لا تكون موجودة.
-dontwarn com.google.android.play.core.**

# تسجيل الدخول عبر Google ومكتبات خدمات Play.
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.**

# ── تحذيرات معروفة غير مؤثّرة ──
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ── تقليل ما يُسرّبه الثنائي ──
# حذف نداءات السجلّ في الإصدار: كانت تطبع مسارات وبيانات تشخيصية يمكن
# قراءتها عبر logcat على أي جهاز، بما فيها معرّفات ومسارات داخلية.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# إبقاء أسماء الملفات وأرقام الأسطر في آثار الأعطال مع إخفاء المصدر.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
