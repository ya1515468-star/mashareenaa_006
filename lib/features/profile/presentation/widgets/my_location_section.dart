import 'dart:async';
import '../../../../core/error/failure_text.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// موقعي إلى مستوى الحيّ.
///
/// كان في الملف «مدينة» نصًّا مكتوبًا باليد، ومفتاح «مشاركة موقعي»
/// يكتب في مجموعة لا يقرأها شيء — فلا حيّ ولا قُرب ولا استهداف.
///
/// الترتيب هنا: الجهاز يُعطي الإحداثية، والخادم يحوّلها إلى حيّ
/// (دالّة reverse-geocode بذاكرتها)، والعضو يستطيع تصحيح الحيّ بنفسه
/// متى أخطأ الاستنتاج. والإحداثية تُحفَظ مقرَّبة إلى ~110 أمتار: تكفي
/// للحيّ ولا تدلّ على باب بيت.
class MyLocationSection extends StatefulWidget {
  const MyLocationSection({super.key});

  @override
  State<MyLocationSection> createState() => _MyLocationSectionState();
}

class _MyLocationSectionState extends State<MyLocationSection> {
  final _db = Supabase.instance.client;
  Map<String, dynamic> _loc = const {};
  bool _loading = true;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final raw = await _db.rpc('get_my_location');
      if (!mounted) return;
      setState(() {
        _loc = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _label {
    final parts = [
      _loc['neighborhood'],
      _loc['district'],
      _loc['city'],
    ].map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'لم يُحدَّد بعد' : parts.join('، ');
  }

  void _say(String msg, {bool ok = false}) {
    if (!mounted) return;
    setState(() => _status = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF16A34A) : null,
    ));
  }

  /// يأخذ الإحداثية بأعلى دقّة يسمح بها الجهاز ثم يسلّمها للخادم.
  ///
  /// الدقّة العالية مطلوبة **للاستنتاج** لا للحفظ: الحيّ لا يُعرَف من
  /// إحداثية تقريبية، والخادم هو من يقرّب قبل الحفظ.
  Future<void> _detect() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'خدمة الموقع مغلقة في الجهاز — شغّلها ثم أعد المحاولة';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw 'إذن الموقع مرفوض دائمًا — افتح إعدادات التطبيق وامنحه الإذن';
      }
      if (perm == LocationPermission.denied) throw 'لم يُمنح إذن الموقع';

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      // الاستنتاج والحفظ على الخادم: اختيار خدمة الترميز ومفتاحها
      // وذاكرتها يبقى في مكان واحد لا موزَّعًا على كل نسخة مُثبَّتة.
      final res = await _db.functions.invoke('reverse-geocode', body: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'save': true,
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      await _load();

      if (data['resolved'] == true) {
        _say('حُدِّد حيّك: ${data['neighborhood']} ✓', ok: true);
      } else {
        // لا يُفقَد الموقع لأنّ الاستنتاج فشل؛ يُطلَب الحيّ كتابةً.
        _say('حُفظ موقعك، لكن تعذّر معرفة الحيّ تلقائيًّا — اكتبه بنفسك');
        if (mounted) await _editNeighborhood();
      }
    } catch (e) {
      _say(FailureText.of(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNeighborhood() async {
    final hood =
        TextEditingController(text: _loc['neighborhood']?.toString() ?? '');
    final city = TextEditingController(text: _loc['city']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('🏘️ الحيّ والمدينة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: city,
              decoration: const InputDecoration(
                  labelText: 'المدينة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hood,
              decoration: const InputDecoration(
                  labelText: 'الحيّ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text(
              'ما تكتبه هنا يتقدّم على الموقع المستنتَج تلقائيًّا.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _db.rpc('set_my_location', params: {
        'p_neighborhood': hood.text.trim().isEmpty ? null : hood.text.trim(),
        'p_city': city.text.trim().isEmpty ? null : city.text.trim(),
      });
      await _load();
      _say('تم الحفظ ✓', ok: true);
    } catch (e) {
      _say(FailureText.action(e, action: 'الحفظ'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setSharing(bool v) async {
    setState(() => _busy = true);
    try {
      await _db.rpc('set_my_location', params: {'p_sharing': v});
      await _load();
    } catch (e) {
      _say(FailureText.action(e, action: 'الحفظ'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final sharing = _loc['sharing'] == true;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        leading: const Icon(Icons.location_city_outlined, color: AppColors.gold),
        title: const Text('موقعي'),
        subtitle: Text(_label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.edit_outlined,
                color: AppColors.textMuted, size: 18),
        onTap: _busy ? null : _editNeighborhood,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _detect,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('تحديد حيّي تلقائيًّا'),
            ),
          ),
        ]),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.share_location_rounded,
            color: AppColors.gold),
        title: const Text('إظهار حيّي للأعضاء'),
        subtitle: const Text(
          'مطفأً: يبقى حيّك محفوظًا لك وحدك ولا يُعرض إلّا المدينة.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
        value: sharing,
        activeThumbColor: AppColors.gold,
        onChanged: _busy ? null : _setSharing,
      ),
      if (_status != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('ℹ️ $_status',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted)),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(
          '🔐 يُحفَظ موقعك مقرَّبًا إلى نحو 110 أمتار — يكفي لمعرفة الحيّ '
          'ولا يدلّ على منزلك. ولا يُتتبَّع موقعك في الخلفية إطلاقًا.',
          style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.6),
        ),
      ),
    ]);
  }
}
