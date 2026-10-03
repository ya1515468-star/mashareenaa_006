import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// خيار تفاعلي اختياري في نهاية شاشة إنشاء الحساب: "هل تود تفعيل
/// التحقق عبر الهاتف لزيادة أمان حسابك؟". لا يبني هذا الويدجت تدفق
/// SMS OTP كاملًا (يحتاج وحدة Phone Auth مستقلة لاحقًا)، بل يسجّل
/// نية المستخدم فقط (wantsPhone2FA) لتُستخدم عند بناء تلك الوحدة.
class TwoFactorPrompt extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TwoFactorPrompt(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: p.accent,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل تود تفعيل التحقق عبر الهاتف لزيادة أمان حسابك؟',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'يمكنك تفعيلها لاحقًا من إعدادات الحساب',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: p.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Icon(Icons.shield_outlined,
              color: p.accent.withValues(alpha: 0.8), size: 20),
        ],
      ),
    );
  }
}
