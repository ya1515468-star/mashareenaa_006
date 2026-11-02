import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// حقلا الجنس وتاريخ الميلاد — مشتركان بين التسجيل بالبريد والدخول
/// كزائر، فلا يختلف ما يُجمع بين المسارين.
///
/// تاريخ الميلاد لا العمر: العمر رقم يصدأ، ومن يسجّل بعمر 20 يبقى 20
/// إلى الأبد. العمر يُحسب خادميًا من التاريخ عبر `public.profile_age()`.
class GenderBirthFields extends StatelessWidget {
  final String? gender;
  final DateTime? birthDate;
  final ValueChanged<String> onGender;
  final ValueChanged<DateTime> onBirthDate;

  /// يظهر نجمة بجانب العنوان حين يكون الحقل مطلوبًا.
  final bool required;

  const GenderBirthFields({
    super.key,
    required this.gender,
    required this.birthDate,
    required this.onGender,
    required this.onBirthDate,
    this.required = false,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'تاريخ الميلاد',
    );
    if (picked != null) onBirthDate(picked);
  }

  String? get _birthLabel {
    final d = birthDate;
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age -= 1;
    }
    return '${d.year}/${d.month}/${d.day}  —  $age سنة';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(required ? 'الجنس *' : 'الجنس',
              style: TextStyle(color: p.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _GenderChip(
              label: 'ذكر',
              icon: Icons.male_rounded,
              selected: gender == 'male',
              onTap: () => onGender('male'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _GenderChip(
              label: 'أنثى',
              icon: Icons.female_rounded,
              selected: gender == 'female',
              onTap: () => onGender('female'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
            child: Row(children: [
              Icon(Icons.cake_outlined, size: 20, color: p.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _birthLabel ??
                        (required ? 'تاريخ الميلاد *' : 'تاريخ الميلاد'),
                    style: TextStyle(
                        color:
                            birthDate == null ? p.textMuted : p.textPrimary)),
              ),
              Icon(Icons.chevron_left, color: p.textMuted),
            ]),
          ),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: .18) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.accent : p.divider),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 19, color: selected ? p.accent : p.textMuted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: selected ? p.accent : p.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }
}
