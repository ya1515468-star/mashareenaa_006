import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

/// بوّابة التحديث.
///
/// تُغلِّف التطبيق **كلّه** بما فيه شاشة الدخول، عمدًا: مستخدم على نسخة
/// معطوبة قد لا يستطيع تسجيل الدخول أصلًا، فبوّابةٌ بعد المصادقة لا تصله.
///
/// سلوكان:
///  • إلزامي  → شاشة حاجبة لا تُتجاوَز، ولا زرّ رجوع.
///  • اختياري → التطبيق يعمل عاديًّا، مع شريط يظهر مرّة واحدة في الجلسة.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  /// مرّة واحدة لكل تشغيل: إلحاح التذكير عند كل بناء للواجهة يدفع
  /// المستخدم لتجاهله لا لتنفيذه.
  static bool _optionalShown = false;

  AppUpdateInfo? _info;

  @override
  void initState() {
    super.initState();
    AppUpdateService.check().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    // أثناء الفحص يعمل التطبيق عاديًّا: حجبه بانتظار نداء شبكة يجعل
    // بدء التطبيق رهينة الاتصال.
    if (info == null || !info.isActionable) return widget.child;

    if (info.mandatory) return _MandatoryUpdateScreen(info: info);

    if (!_optionalShown) {
      _optionalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOptionalSheet(context, info);
      });
    }
    return widget.child;
  }
}

Future<void> _openDownload(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذّر فتح رابط التنزيل')),
    );
  }
}

void _showOptionalSheet(BuildContext context, AppUpdateInfo info) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.system_update, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text('تحديث متاح — ${info.versionName ?? ''}',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
          ]),
          if (info.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(info.notes!.trim()),
          ],
          if (info.sizeLabel != null) ...[
            const SizedBox(height: 8),
            Text('الحجم: ${info.sizeLabel}',
                style: Theme.of(ctx).textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تنزيل التحديث'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openDownload(context, info.downloadUrl!);
                },
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('لاحقًا'),
            ),
          ]),
        ],
      ),
    ),
  );
}

class _MandatoryUpdateScreen extends StatelessWidget {
  const _MandatoryUpdateScreen({required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // canPop: false — التحديث الإلزامي يُنشر لإغلاق ثغرة أمنية، فتجاوزه
    // بزرّ رجوع يُفرغه من معناه.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security_update_warning,
                      size: 72, color: t.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text('تحديث إلزامي',
                      style: t.textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    'هذه النسخة لم تعد مدعومة. حدِّث التطبيق للمتابعة.',
                    style: t.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (info.notes?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(info.notes!.trim(),
                          textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(
                        info.sizeLabel == null
                            ? 'تنزيل النسخة ${info.versionName ?? ''}'
                            : 'تنزيل ${info.versionName ?? ''} · ${info.sizeLabel}',
                      ),
                      onPressed: () => _openDownload(context, info.downloadUrl!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'بعد التنزيل، افتح الملف لتثبيت التحديث فوق النسخة الحالية. '
                    'بياناتك وحسابك لا تتأثّر.',
                    style: t.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
