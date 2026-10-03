import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// استنتاج موقع المستخدم تلقائيًا (الدولة/المدينة) من عنوان IP.
///
/// لماذا هكذا: عمودا `country`/`city` في profiles كانا فارغين لكل
/// المستخدمين، فبحث المالك بالموقع كان يعرض فراغًا. بدل إجبار العضو على
/// ملء حقل، نستنتجه مرة واحدة عند الدخول.
///
/// قواعد مقصودة:
///  • لا يُستدعى إلا مرة كل 7 أيام لكل جهاز — لا إرهاق للمزوّد ولا للخادم.
///  • الخادم هو الحَكَم: `resolve_my_location` ترفض الكتابة فوق أي موقع
///    اختاره العضو يدويًا، فالاستنتاج لا يمحو قراره أبدًا.
///  • الفشل صامت تمامًا. تعذّر الاستنتاج ليس خطأ يستحق إزعاج المستخدم،
///    والموقع ميزة إدارية لا وظيفة أساسية.
///  • مزوّدان بالتتابع: إن سقط الأول جُرِّب الثاني.
class GeoLocationService {
  GeoLocationService._();

  static const _minInterval = Duration(days: 7);
  static DateTime? _lastAttempt;
  static bool _running = false;

  /// المزوّدون بالترتيب. كلاهما مجاني وبلا مفتاح، ويعيدان JSON.
  static const _providers = <_GeoProvider>[
    _GeoProvider(
      url: 'https://ipwho.is/',
      country: 'country',
      city: 'city',
      code: 'country_code',
      lat: 'latitude',
      lng: 'longitude',
      okField: 'success',
    ),
    _GeoProvider(
      url: 'https://ipapi.co/json/',
      country: 'country_name',
      city: 'city',
      code: 'country_code',
      lat: 'latitude',
      lng: 'longitude',
    ),
  ];

  /// يُستدعى بعد تسجيل الدخول. لا يرمي أبدًا ولا يوقف أي تدفّق.
  static Future<void> resolveIfNeeded() async {
    if (_running) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < _minInterval) return;

    _running = true;
    _lastAttempt = DateTime.now();
    try {
      for (final p in _providers) {
        final data = await _fetch(p);
        if (data == null) continue;
        final country = data['country'];
        if (country == null || country.toString().trim().isEmpty) continue;

        await client.rpc('resolve_my_location', params: {
          'p_country': country,
          'p_city': data['city'],
          'p_country_code': data['code'],
          'p_latitude': data['lat'],
          'p_longitude': data['lng'],
        });
        return; // نجح مزوّد — لا داعي للبقية
      }
    } catch (_) {
      // صامت عمدًا — انظر التوثيق أعلاه
    } finally {
      _running = false;
    }
  }

  /// المالك يستنتج موقع عضو من IP المحفوظ عنده.
  ///
  /// resolveIfNeeded تعمل فقط حين يسجّل العضو نفسه دخولًا، فعضو لم
  /// يدخل منذ إضافة الخدمة يبقى بلا موقع مهما كان last_ip مسجّلًا —
  /// وهذا ما يراه المالك: IP بلا دولة ولا مدينة. هنا نستعلم المزوّد
  /// بذلك الـIP تحديدًا ونحفظ النتيجة خادميًا.
  static Future<String?> resolveForUser(String userId) async {
    final client = Supabase.instance.client;

    final ip = (await client
            .rpc('owner_get_user_ip', params: {'p_user_id': userId}))
        ?.toString()
        .trim();
    if (ip == null || ip.isEmpty) return 'لا يوجد IP مسجّل لهذا العضو';

    for (final p in _providers) {
      // ipwho.is و ipapi.co يقبلان الاستعلام عن IP محدّد بإلحاقه
      // بالمسار بدل الاستعلام عن IP المتصل الحالي.
      final url = p.url.endsWith('/json/')
          ? p.url.replaceFirst('/json/', '/$ip/json/')
          : '${p.url}$ip';
      final data = await _fetch(_GeoProvider(
        url: url,
        country: p.country,
        city: p.city,
        code: p.code,
        lat: p.lat,
        lng: p.lng,
        okField: p.okField,
      ));
      if (data == null) continue;
      final country = data['country'];
      if (country == null || country.toString().trim().isEmpty) continue;

      final res = await client.rpc('owner_resolve_user_location', params: {
        'p_user_id': userId,
        'p_country': country,
        'p_city': data['city'],
        'p_country_code': data['code'],
        'p_latitude': data['lat'],
        'p_longitude': data['lng'],
      });
      if (res is Map && res['updated'] == false) {
        return res['reason'] == 'MANUAL_SET'
            ? 'هذا العضو عيّن موقعه يدويًا — لم يُدهس'
            : 'تعذّر تحديد الموقع من هذا الـIP';
      }
      return null; // نجح
    }
    return 'لم يتعرّف أي مزوّد على هذا الـIP';
  }

  /// تعيين يدوي من صفحة الملف الشخصي. يقفل الموقع ضد الاستنتاج لاحقًا.
  static Future<void> setManual({
    required String country,
    String? city,
    String? address,
  }) async {
    await Supabase.instance.client.rpc('set_my_location_manual', params: {
      'p_country': country,
      'p_city': city,
      'p_address': address,
    });
  }

  static Future<Map<String, dynamic>?> _fetch(_GeoProvider p) async {
    try {
      final res = await http
          .get(Uri.parse(p.url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      if (p.okField != null && body[p.okField] == false) return null;

      return {
        'country': body[p.country]?.toString(),
        'city': body[p.city]?.toString(),
        'code': body[p.code]?.toString(),
        'lat': (body[p.lat] as num?)?.toDouble(),
        'lng': (body[p.lng] as num?)?.toDouble(),
      };
    } catch (_) {
      return null;
    }
  }
}

class _GeoProvider {
  final String url;
  final String country;
  final String city;
  final String code;
  final String lat;
  final String lng;
  final String? okField;

  const _GeoProvider({
    required this.url,
    required this.country,
    required this.city,
    required this.code,
    required this.lat,
    required this.lng,
    this.okField,
  });
}
