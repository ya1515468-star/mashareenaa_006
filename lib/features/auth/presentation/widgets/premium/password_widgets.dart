import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class _PasswordRule {
  final String label;
  final bool Function(String) test;
  const _PasswordRule(this.label, this.test);
}

final List<_PasswordRule> _rules = [
  _PasswordRule('8 أحرف على الأقل', (v) => v.length >= 8),
  _PasswordRule('حرف كبير (A-Z)', (v) => v.contains(RegExp(r'[A-Z]'))),
  _PasswordRule('رقم واحد على الأقل', (v) => v.contains(RegExp(r'[0-9]'))),
  _PasswordRule('رمز خاص (!@#\$...)',
      (v) => v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))),
];

/// لوحة إرشادات كلمة المرور: تظهر عند التركيز على الحقل، وتتحول كل
/// شروطها للون الأخضر تلقائيًا فور تحققها أثناء الكتابة.
class PasswordStrengthPanel extends StatelessWidget {
  final String password;
  final bool visible;

  const PasswordStrengthPanel(
      {super.key, required this.password, required this.visible});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: !visible
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in _rules)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            rule.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: rule.test(password)
                                  ? p.success
                                  : p.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            rule.test(password)
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 14,
                            color:
                                rule.test(password) ? p.success : p.textMuted,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// مؤشر مباشر لتطابق كلمتي المرور — يتحدث لحظيًا أثناء الكتابة قبل
/// الضغط على أي زر.
class PasswordMatchIndicator extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const PasswordMatchIndicator(
      {super.key, required this.password, required this.confirmPassword});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (confirmPassword.isEmpty) return const SizedBox.shrink();
    final matches = password == confirmPassword;
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            matches ? 'كلمتا المرور متطابقتان' : 'كلمتا المرور غير متطابقتين',
            style: TextStyle(
              fontSize: 12.5,
              color: matches ? p.success : p.error.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            matches ? Icons.check_circle : Icons.error_outline,
            size: 15,
            color: matches ? p.success : p.error.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}
