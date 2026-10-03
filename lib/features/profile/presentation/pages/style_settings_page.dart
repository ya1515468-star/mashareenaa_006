import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/account_setting_tiles.dart';

/// "إعدادات الستايل" — تخصيص لمسة شخصية فوق ثيم Dark Luxury الموحّد
/// (لون تمييز مفضّل للفقاعات/الأزرار الخاصة بحسابك)، وليس استبدالًا
/// للثيم العام للتطبيق الذي يبقى داكنًا وفاخرًا للجميع.
class StyleSettingsPage extends StatefulWidget {
  final String uid;
  const StyleSettingsPage({super.key, required this.uid});

  @override
  State<StyleSettingsPage> createState() => _StyleSettingsPageState();
}

class _StyleSettingsPageState extends State<StyleSettingsPage> {
  int? _accentColor;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await AccountSettingsStore.readField(widget.uid, 'accentColor');
    if (!mounted) return;
    setState(() {
      _accentColor = raw as int?;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الستايل')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('ثيم التطبيق الرسمي هو Dark Luxury لكل المستخدمين',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 20),
                Text('لون التمييز الخاص بك',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: kProfileColorSwatches
                      .map((c) => GestureDetector(
                            onTap: () async {
                              setState(() => _accentColor = c.toARGB32());
                              await AccountSettingsStore.writeField(
                                  widget.uid, 'accentColor', c.toARGB32());
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accentColor == c.toARGB32()
                                      ? Colors.white
                                      : AppColors.divider,
                                  width: _accentColor == c.toARGB32() ? 2.5 : 1,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
