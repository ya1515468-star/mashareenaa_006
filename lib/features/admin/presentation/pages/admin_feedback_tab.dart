import '../../../../core/data/supabase_document_compat.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';

/// يعرض اقتراحات الأعضاء (ميزة 12) لإدارة المنصة — بلا Riverpod
/// provider مخصَّص لتوفير الوقت، عبر StreamBuilder مباشر لأنها شاشة
/// إدارية بسيطة القراءة فقط.
class AdminFeedbackTab extends StatelessWidget {
  const AdminFeedbackTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SupabaseDocumentStore.instance
          .collection('member_feedback')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
              child: Text('لا توجد اقتراحات بعد',
                  style: TextStyle(color: p.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final uid = data['uid'] as String? ?? '';
            return ListTile(
              leading: Icon(Icons.lightbulb_outline, color: p.accent),
              title: Text(data['message'] as String? ?? ''),
              subtitle: Text('من: $uid',
                  style: TextStyle(fontSize: 11, color: p.textMuted)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => UserProfileViewPage(uid: uid)),
              ),
            );
          },
        );
      },
    );
  }
}
