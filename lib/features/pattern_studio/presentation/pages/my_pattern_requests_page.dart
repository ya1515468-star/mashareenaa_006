import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/pattern_enums.dart';
import '../providers/pattern_studio_provider.dart';

class MyPatternRequestsPage extends ConsumerWidget {
  const MyPatternRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: uid == null
          ? const SizedBox.shrink()
          : Consumer(
              builder: (context, ref, _) {
                final requestsAsync = ref.watch(myPatternRequestsProvider(uid));
                return requestsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
                  data: (requests) {
                    if (requests.isEmpty) {
                      return const Center(child: Text('لا توجد طلبات بعد'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = requests[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Chip(label: Text(r.mannequinType.label)),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(r.status.label),
                                      backgroundColor: r.status ==
                                              PatternRequestStatus.completed
                                          ? AppColors.success
                                              .withValues(alpha: 0.2)
                                          : null,
                                    ),
                                  ],
                                ),
                                if (r.reviewerNote != null) ...[
                                  const SizedBox(height: 8),
                                  Text(r.reviewerNote!,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                ],
                                if (r.status ==
                                    PatternRequestStatus.completed) ...[
                                  const SizedBox(height: 10),
                                  if (r.resultImageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(r.resultImageUrl!,
                                          height: 160, fit: BoxFit.cover),
                                    ),
                                  if (r.resultVideoUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final url = Uri.tryParse(r.resultVideoUrl!);
                                          if (url == null || !await launchUrl(url, mode: LaunchMode.platformDefault)) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تعذر فتح رابط الفيديو.')),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.play_circle_outline),
                                        label: const Text(
                                            'عرض الفيديو (رابط خارجي)'),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
