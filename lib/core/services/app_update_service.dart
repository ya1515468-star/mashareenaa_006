import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// فحص التحديث داخل التطبيق.
///
/// لماذا هذا موجود: التطبيق يُوزَّع خارج Google Play، فلا تحديث تلقائي.
/// بدون هذه الآلية يبقى كل مستخدم على النسخة التي ثبّتها أبدًا، وثغرة
/// تُكتشف غدًا تبقى مفتوحة لديه بلا أيّ سبيل لإغلاقها.
///
/// القرار كله خادمي: الخادم يقارن versionCode المثبَّت بأحدث إصدار منشور،
/// وهو وحده يقرّر إن كان التحديث إلزاميًّا. العميل لا يحسب شيئًا ولا
/// يستطيع إقناع نفسه بأنّه محدَّث.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.updateAvailable,
    required this.mandatory,
    this.versionName,
    this.versionCode,
    this.downloadUrl,
    this.sha256,
    this.sizeBytes,
    this.notes,
  });

  final bool updateAvailable;
  final bool mandatory;
  final String? versionName;
  final int? versionCode;
  final String? downloadUrl;
  final String? sha256;
  final int? sizeBytes;
  final String? notes;

  /// لا معنى لمطالبة المستخدم بتحديث بلا رابط يُنزّله منه.
  bool get isActionable => updateAvailable && (downloadUrl?.isNotEmpty ?? false);

  /// حجم تقريبي بالميغابايت لعرضه قبل التنزيل — مهم على اتصال محدود.
  String? get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return null;
    return '${(b / (1024 * 1024)).toStringAsFixed(0)} ميغابايت';
  }

  static const none = AppUpdateInfo(updateAvailable: false, mandatory: false);

  factory AppUpdateInfo.fromJson(Map<String, dynamic> j) => AppUpdateInfo(
        updateAvailable: j['update_available'] == true,
        mandatory: j['mandatory'] == true,
        versionName: j['version_name'] as String?,
        versionCode: (j['version_code'] as num?)?.toInt(),
        downloadUrl: j['download_url'] as String?,
        sha256: j['sha256'] as String?,
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        notes: j['notes'] as String?,
      );
}

class AppUpdateService {
  const AppUpdateService._();

  /// يُنفَّذ مرّة واحدة لكل تشغيل. يُخزَّن الناتج فلا يُثقَل بدء التطبيق
  /// بنداء شبكة متكرّر عند كل إعادة بناء للواجهة.
  static Future<AppUpdateInfo>? _inFlight;
  static AppUpdateInfo? _cached;

  static AppUpdateInfo? get cached => _cached;

  static Future<AppUpdateInfo> check({bool force = false}) {
    if (!force && _cached != null) return Future.value(_cached);
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<AppUpdateInfo> _run() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber) ?? 0;

      final res = await Supabase.instance.client.rpc(
        'check_app_update',
        params: {'p_version_code': code, 'p_platform': 'android'},
      );
      if (res is! Map) return _cached = AppUpdateInfo.none;
      return _cached = AppUpdateInfo.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      // الفشل يُمرَّر لا يُعطِّل: انقطاع شبكة أو عطل خادم يجب ألّا يمنع
      // المستخدم من فتح تطبيقه. المقابل أنّ تحديثًا إلزاميًّا قد يتأخّر
      // تطبيقه حتى أول فحص ناجح — وهذا أهون من تعطيل التطبيق بالكامل.
      return _cached = AppUpdateInfo.none;
    }
  }
}
