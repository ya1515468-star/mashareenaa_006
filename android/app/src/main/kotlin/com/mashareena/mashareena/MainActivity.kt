package com.mashareena.mashareena

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * قناة Play Integrity.
 *
 * تُستخدم مكتبة Google الرسمية مباشرة بدل حزمة pub من طرف ثالث: الاعتماد
 * الأمني يجب أن يكون على مصدر أوّلي، وإضافة حزمة وسيطة تزيد سطح الثقة بلا
 * مقابل.
 *
 * الرمز الناتج **لا يُفكّ هنا**. العميل لا يستطيع قراءة الحكم ولا تزويره؛
 * يُرسَل كما هو إلى دالة play-integrity في الخادم، وهي وحدها تملك مفتاح
 * حساب الخدمة الذي يفكّه عند Google.
 */
class MainActivity : FlutterActivity() {

    private val channel = "mashareena/integrity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestToken" -> requestToken(call.argument<String>("nonce"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestToken(nonce: String?, result: MethodChannel.Result) {
        if (nonce.isNullOrBlank()) {
            result.error("NONCE_REQUIRED", "nonce مطلوب من الخادم", null)
            return
        }
        try {
            val manager = IntegrityManagerFactory.create(applicationContext)
            manager.requestIntegrityToken(
                IntegrityTokenRequest.builder().setNonce(nonce).build()
            ).addOnSuccessListener { response ->
                result.success(response.token())
            }.addOnFailureListener { e ->
                // الفشل شائع ومتوقّع خارج Google Play (نسخة جانبية، محاكٍ،
                // خدمات Play غائبة). يُبلَّغ كخطأ ويقرّر الخادم ما يفعله.
                result.error("INTEGRITY_FAILED", e.message ?: "تعذّر طلب رمز النزاهة", null)
            }
        } catch (e: Throwable) {
            result.error("INTEGRITY_UNAVAILABLE", e.message ?: "Play Integrity غير متاح", null)
        }
    }
}
