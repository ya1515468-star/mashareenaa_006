import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../domain/lobby_directory_service.dart';

/// صفحة لائحة عامة تُستخدم لعنصرين من قائمة الشات (8: العرش الملكي
/// للعضويات المدفوعة، 10: طاقم الإدارة) — كلاهما "uid + وسم نصي"
/// يُعرض بجانب اسم/صورة العضو الحيّين عبر profileByIdProvider، بنفس
/// نمط _LeaderboardList تمامًا.
class DirectoryListPage extends StatelessWidget {
  final String title;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<List<DirectoryEntry>> Function() fetcher;

  const DirectoryListPage({
    super.key,
    required this.title,
    required this.fetcher,
    this.emptyIcon = Icons.people_outline,
    this.emptyMessage = 'لا توجد بيانات كافية بعد',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<DirectoryEntry>>(
        future: fetcher(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('تعذّر التحميل: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            );
          }
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(emptyMessage,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserProfileViewPage(uid: entry.uid))),
                leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceHighlight,
                    child: Icon(Icons.person, color: AppColors.gold)),
                title: ServerUsernameDisplay(
                  uid: entry.uid,
                  fallbackName: entry.uid,
                  fallbackFontSize: 16,
                  showBadges: true,
                  showAchievements: false,
                ),
                trailing: Text(entry.label,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
