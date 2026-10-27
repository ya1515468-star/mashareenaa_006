import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/account_setting_tiles.dart';
import '../widgets/my_location_section.dart';

/// "اللغة / الموقع" — اختيار لغة الواجهة ومشاركة الموقع الجغرافي
/// (يُستخدم لعرض المستخدمين القريبين ولا يعني تتبعًا مستمرًا).
class LanguageLocationPage extends StatefulWidget {
  final String uid;

  const LanguageLocationPage({
    super.key,
    required this.uid,
  });

  @override
  State<LanguageLocationPage> createState() => _LanguageLocationPageState();
}

class _LanguageLocationPageState extends State<LanguageLocationPage> {
  String _language = 'ar';
  bool _loaded = false;

  static const Map<String, String> _languages = {
    'ar': 'العربية',
    'en': 'English',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await AccountSettingsStore.readField(
      widget.uid,
      'appLanguage',
    );

    if (!mounted) return;

    setState(() {
      _language = raw as String? ?? 'ar';
      _loaded = true;
    });
  }

  Future<void> _changeLanguage(String value) async {
    setState(() {
      _language = value;
    });

    await AccountSettingsStore.writeField(
      widget.uid,
      'appLanguage',
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اللغة والموقع'),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'لغة التطبيق',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RadioGroup<String>(
                  groupValue: _language,
                  onChanged: (value) {
                    if (value == null) return;
                    _changeLanguage(value);
                  },
                  child: Column(
                    children: _languages.entries.map(
                      (entry) {
                        return RadioListTile<String>(
                          value: entry.key,
                          activeColor: AppColors.gold,
                          title: Text(entry.value),
                        );
                      },
                    ).toList(),
                  ),
                ),
                const Divider(
                  color: AppColors.divider,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('📍 الموقع والحيّ',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                // القسم كامل: تحديد الحيّ، تصحيحه يدويًّا، ومفتاح إظهاره.
                // المفتاح القديم كان يكتب في accounts التي لا يقرأها شيء.
                const MyLocationSection(),
              ],
            ),
    );
  }
}
