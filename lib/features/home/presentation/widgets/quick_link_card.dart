import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickLinkCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      // كانت البطاقة مربّعة بحشوة رأسية 20 وأيقونة 28، فتمتدّ على
      // نصف الشاشة في الموبايل ولا يظهر منها إلا ثلاث. صارت مضغوطة:
      // حشوة 10 وأيقونة 20 وخط 11.5، فتُعرض ستّ دفعة واحدة.
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(height: 5),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
