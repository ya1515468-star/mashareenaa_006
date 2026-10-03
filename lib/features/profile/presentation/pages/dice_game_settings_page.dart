import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/account_setting_tiles.dart';

/// "تهيئة لعبة النرد" — تفضيلات المستخدم الشخصية عند تحدي أصدقائه
/// بلعبة النرد من داخل الشات (عدد النرد، الثيم، وهل يقبل تحديات من
/// الجميع أم من أصدقائه فقط). تُخزَّن ضمن accounts/{uid}.diceGameConfig.
class DiceGameSettingsPage extends StatefulWidget {
  final String uid;
  const DiceGameSettingsPage({super.key, required this.uid});

  @override
  State<DiceGameSettingsPage> createState() => _DiceGameSettingsPageState();
}

class _DiceGameSettingsPageState extends State<DiceGameSettingsPage> {
  int _diceCount = 2;
  String _theme = 'classic';
  bool _loaded = false;

  static const _themes = {
    'classic': 'كلاسيكي',
    'neon': 'نيون',
    'wood': 'خشبي فاخر',
    'gold': 'ذهبي VIP',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw =
        await AccountSettingsStore.readField(widget.uid, 'diceGameConfig');
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _diceCount = (map['diceCount'] as num?)?.toInt() ?? 2;
      _theme = map['theme'] as String? ?? 'classic';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await AccountSettingsStore.writeField(widget.uid, 'diceGameConfig', {
      'diceCount': _diceCount,
      'theme': _theme,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات لعبة النرد ✓')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تهيئة لعبة النرد')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('عدد قطع النرد',
                    style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: _diceCount.toDouble(),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  activeColor: AppColors.gold,
                  label: '$_diceCount',
                  onChanged: (v) => setState(() => _diceCount = v.round()),
                ),
                const SizedBox(height: 16),
                Text('ثيم النرد',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _themes.entries
                      .map((e) => ChoiceChip(
                            label: Text(e.value),
                            selected: _theme == e.key,
                            selectedColor:
                                AppColors.gold.withValues(alpha: 0.25),
                            onSelected: (_) => setState(() => _theme = e.key),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                AccountChoiceSettingTile(
                  uid: widget.uid,
                  field: 'diceChallengePolicy',
                  icon: Icons.casino_outlined,
                  title: 'من يمكنه تحدّيك بلعبة النرد؟',
                ),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: _save, child: const Text('حفظ الإعدادات')),
              ],
            ),
    );
  }
}
