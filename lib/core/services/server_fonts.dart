import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../monitoring/error_monitor.dart';

/// خطوط عربية محفوظة في الخادم (جدول server_fonts + حاوية fonts) وليست في
/// المشروع. تُنزَّل عند أول استخدام وتُسجَّل عبر FontLoader.
class ServerFonts {
  ServerFonts._();
  static final Set<String> _loaded = {};
  static final Map<String, Future<void>> _pending = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String family(String key) => 'srv_$key';
  static bool isLoaded(String key) => _loaded.contains(key);

  static Future<List<Map<String, dynamic>>> list() async {
    final rows = await Supabase.instance.client
        .from('server_fonts')
        .select('font_key,name_ar,url')
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> ensure(String key) {
    if (_loaded.contains(key)) return Future.value();
    return _pending[key] ??= _load(key);
  }

  static Future<void> _load(String key) async {
    // كان كل فشل هنا يُكتَم صامتًا (`catch (_) {}`)، فإن تعذّر الصف أو
    // التنزيل أو التسجيل بقي الخط افتراضيًا بلا أي أثر يُعرَف منه السبب —
    // وهذا ما جعل تشخيص «الخط لا يظهر» تخمينًا. كل مرحلة الآن تُبلِّغ
    // الخادم بسببها الحقيقي عبر مراقب الأخطاء.
    try {
      final row = await Supabase.instance.client
          .from('server_fonts')
          .select('url')
          .eq('font_key', key)
          .maybeSingle();
      final url = row?['url']?.toString();
      if (url == null || url.isEmpty) {
        unawaited(ErrorMonitor.report(
          'FONT_NO_ROW key=$key (لا صف في server_fonts أو url فارغ)',
          source: 'server_fonts',
          severity: 'warning',
        ));
        return;
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        unawaited(ErrorMonitor.report(
          'FONT_HTTP_FAIL key=$key status=${res.statusCode} '
          'bytes=${res.bodyBytes.length} url=$url',
          source: 'server_fonts',
          severity: 'warning',
        ));
        return;
      }
      final loader = FontLoader(family(key))
        ..addFont(Future<ByteData>.value(ByteData.view(Uint8List.fromList(res.bodyBytes).buffer)));
      await loader.load();
      _loaded.add(key);
      revision.value++;
      // نجاح صريح أيضًا: بدونه لا نعرف أبدًا إن كان الخط وصل ثم لم يُطبَّق
      // (علّة عرض) أم لم يصل أصلًا (علّة تنزيل) — وهذا هو الفرق الذي كان
      // يُضيّع الوقت.
      unawaited(ErrorMonitor.report(
        'FONT_LOADED key=$key family=${family(key)} bytes=${res.bodyBytes.length}',
        source: 'server_fonts',
        severity: 'info',
      ));
    } catch (e, st) {
      unawaited(ErrorMonitor.report(
        'FONT_EXCEPTION key=$key $e',
        stack: st,
        source: 'server_fonts',
        severity: 'warning',
      ));
    } finally {
      _pending.remove(key);
    }
  }
}
