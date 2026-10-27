import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/sound_preferences.dart';

enum VisibilityChoice { everyone, friendsOnly, nobody }

extension VisibilityChoiceX on VisibilityChoice {
  String get wire => name;

  String get label => switch (this) {
        VisibilityChoice.everyone => 'الجميع',
        VisibilityChoice.friendsOnly => 'الأصدقاء فقط',
        VisibilityChoice.nobody => 'لا أحد',
      };

  static VisibilityChoice fromWire(String? s) =>
      VisibilityChoice.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => VisibilityChoice.everyone,
      );
}

class AccountSettingsStore {
  static Future<Map<String, dynamic>?> _readDoc(String uid) async {
    final doc = await sl<SupabaseDocumentStore>()
        .collection(BackendCollections.accounts)
        .doc(uid)
        .get();

    return doc.data();
  }

  static Future<dynamic> readField(String uid, String field) async {
    final data = await _readDoc(uid);
    return data?[field];
  }

  static Future<void> writeField(
    String uid,
    String field,
    dynamic value,
  ) async {
    await sl<SupabaseDocumentStore>()
        .collection(BackendCollections.accounts)
        .doc(uid)
        .set(
      {field: value},
      const SetOptions(merge: true),
    );
  }

  static Future<void> writeFields(
    String uid,
    Map<String, dynamic> values,
  ) async {
    await sl<SupabaseDocumentStore>()
        .collection(BackendCollections.accounts)
        .doc(uid)
        .set(
          values,
          const SetOptions(merge: true),
        );
  }
}

/// خيار خصوصية: الجميع / الأصدقاء فقط / لا أحد.
///
/// كانت هذه المفاتيح الخمسة (من يرى أصدقائي، نقاطي، من يراسلني خاصًّا،
/// من يطلب الحديث، من يتحدّاني بالنرد) تُكتَب في مجموعة `accounts`
/// التي لا يقرأها أيّ شيء في التطبيق — فيضبطها العضو وتُحفَظ ولا تحكم
/// شيئًا. وخصوصيةٌ تبدو مضبوطة وهي غير نافذة أسوأ من غيابها: يظنّ
/// صاحبها أنّه محميّ.
///
/// الآن تُحفَظ في أعمدة خادمية ويُفرَض القرار في الخادم.
class AccountChoiceSettingTile extends StatefulWidget {
  final String uid;
  final String field;
  final IconData icon;
  final String title;
  final String? subtitleHint;

  const AccountChoiceSettingTile({
    super.key,
    required this.uid,
    required this.field,
    required this.icon,
    required this.title,
    this.subtitleHint,
  });

  @override
  State<AccountChoiceSettingTile> createState() =>
      _AccountChoiceSettingTileState();
}

class _AccountChoiceSettingTileState extends State<AccountChoiceSettingTile> {
  VisibilityChoice _value = VisibilityChoice.everyone;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('get_my_privacy_preferences');
      final m = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      if (!mounted) return;
      setState(() {
        _value = VisibilityChoiceX.fromWire(m[widget.field] as String?);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _openPicker() async {
    final selected = await showDialog<VisibilityChoice>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(widget.title),
          backgroundColor: AppColors.surfaceElevated,
          children: [
            RadioGroup<VisibilityChoice>(
              groupValue: _value,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Column(
                children: VisibilityChoice.values
                    .map(
                      (choice) => RadioListTile<VisibilityChoice>(
                        value: choice,
                        activeColor: AppColors.gold,
                        title: Text(choice.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _value = selected;
    });

    final previous = _value;
    try {
      await Supabase.instance.client.rpc('set_my_privacy_preference',
          params: {'p_key': widget.field, 'p_value': selected.wire});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(
        content: Text('تم الحفظ ✓'),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      if (!mounted) return;
      // يُعاد الاختيار الظاهر إلى ما هو محفوظ فعلًا: إبقاؤه على ما
      // فشل حفظه يُري العضو خصوصيةً لا وجود لها.
      setState(() => _value = previous);
      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(content: Text(FailureText.of(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon, color: AppColors.gold),
      title: Text(widget.title),
      subtitle: Text(
        _loaded ? _value.label : '...',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left,
        color: AppColors.textMuted,
      ),
      onTap: _openPicker,
    );
  }
}

class AccountSwitchSettingTile extends StatefulWidget {
  final String uid;
  final String field;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool defaultValue;

  /// مفتاح التفضيل على الخادم في `chat_notification_preferences`.
  ///
  /// مفاتيح الأصوات كانت تُكتَب في مجموعة `accounts` التي لا يقرأها
  /// أيّ شيء، فيبدو الإطفاء ناجحًا وتبقى الأصوات تُشتغل. تمريره هنا
  /// يحوّل المفتاح إلى الجدول الخادمي الذي يقرأه مشغّل الأصوات فعلًا.
  final String? soundPrefKey;

  const AccountSwitchSettingTile({
    super.key,
    required this.uid,
    required this.field,
    required this.icon,
    required this.title,
    this.subtitle,
    this.defaultValue = false,
    this.soundPrefKey,
  });

  @override
  State<AccountSwitchSettingTile> createState() =>
      _AccountSwitchSettingTileState();
}

class _AccountSwitchSettingTileState extends State<AccountSwitchSettingTile> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = widget.soundPrefKey;
    if (key != null) {
      final v = await SoundPreferences.instance
          .flag(key, defaultValue: widget.defaultValue);
      if (!mounted) return;
      setState(() => _value = v);
      return;
    }
    final raw = await AccountSettingsStore.readField(
      widget.uid,
      widget.field,
    );

    if (!mounted) return;

    setState(() {
      _value = raw as bool? ?? widget.defaultValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(widget.icon, color: AppColors.gold),
      title: Text(widget.title),
      subtitle: widget.subtitle == null
          ? null
          : Text(
              widget.subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
      value: _value ?? widget.defaultValue,
      activeThumbColor: AppColors.gold,
      onChanged: _value == null
          ? null
          : (v) async {
              setState(() {
                _value = v;
              });

              try {
                final key = widget.soundPrefKey;
                if (key != null) {
                  await SoundPreferences.instance.setFlag(key, v);
                } else {
                  await AccountSettingsStore.writeField(
                    widget.uid,
                    widget.field,
                    v,
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                setState(() => _value = !v);
                ScaffoldMessenger.of(context).showSnackBarSfx(
                  SnackBar(content: Text(FailureText.of(e))),
                );
              }
            },
    );
  }
}

class TextInputSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? currentValueLabel;
  final String initialValue;
  final String dialogLabel;
  final Future<void> Function(String newValue) onSave;
  final bool obscure;
  final TextInputType keyboardType;

  const TextInputSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.initialValue,
    required this.dialogLabel,
    required this.onSave,
    this.currentValueLabel,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(title),
      subtitle: currentValueLabel == null
          ? null
          : Text(
              currentValueLabel!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_left,
        color: AppColors.textMuted,
      ),
      onTap: () async {
        final controller = TextEditingController(
          text: initialValue,
        );

        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: dialogLabel,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  controller.text.trim(),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );

        try {
          if (result == null || result.isEmpty) {
            return;
          }

          await onSave(result);
        } finally {
          controller.dispose();
        }
      },
    );
  }
}

const List<Color> kProfileColorSwatches = [
  Color(0xFF000000), // black
  AppColors.gold,
  AppColors.goldBright,
  AppColors.burgundy,
  AppColors.burgundyBright,
  // Neon palette for chat/profile name rendering. The selected color is persisted
  // server-side; chat adds the corresponding glow/shadow automatically.
  Color(0xFFFF1744), // neon red
  Color(0xFFFF00E5), // neon magenta
  Color(0xFF7C4DFF), // electric violet
  Color(0xFF00E5FF), // neon cyan
  Color(0xFF00FF8A), // neon mint
  Color(0xFF69F0AE),
  Color(0xFFFFFF00), // neon yellow
  Color(0xFFFFD740),
  Color(0xFFFF6D00), // neon orange
  Color(0xFFB388FF),
  Color(0xFFFF80AB),
  Color(0xFFFFFFFF),
  Color(0xFF9E9E9E),
];

Future<Color?> showColorSwatchPicker(
  BuildContext context,
  String title,
) {
  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text(title),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kProfileColorSwatches
            .map(
              (c) => GestureDetector(
                onTap: () => Navigator.of(context).pop(c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}
