import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../pages/guest_upgrade_page.dart';
import '../providers/guest_provider.dart';

/// بطاقة دائمة في الملف الشخصي: «سجّل ليصير حسابك دائمًا».
/// تختفي نهائيًا بعد اكتمال الترقية.
class GuestUpgradeTile extends ConsumerWidget {
  const GuestUpgradeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isGuestSessionProvider)) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.accent.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.workspace_premium_outlined, color: p.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('أنت تستعمل حساب زائر',
                  style: TextStyle(
                      color: p.textPrimary, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'حسابك محفوظ في هذا الجهاز فقط. أضف بريدك ليصير دائمًا — ويبقى '
            'كل ما جمعته معك: رسائلك ونقاطك وأصدقاؤك.',
            style: TextStyle(color: p.textSecondary, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => GuestUpgradePage.open(context),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('تسجيل الحساب بالبريد'),
          ),
        ],
      ),
    );
  }
}

/// شريط صغير قابل للإخفاء أعلى الشات. يُخفى لهذه الجلسة فقط، ويعود
/// في المرة القادمة ما دام الحساب زائرًا — ويختفي نهائيًا بعد الترقية.
class GuestUpgradeBanner extends ConsumerStatefulWidget {
  const GuestUpgradeBanner({super.key});

  @override
  ConsumerState<GuestUpgradeBanner> createState() => _GuestUpgradeBannerState();
}

class _GuestUpgradeBannerState extends ConsumerState<GuestUpgradeBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    if (!ref.watch(isGuestSessionProvider)) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.accent.withValues(alpha: .4)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: p.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text('أنت زائر — سجّل ببريدك ليصير حسابك دائمًا',
              style: TextStyle(color: p.textSecondary, fontSize: 12)),
        ),
        TextButton(
          onPressed: () => GuestUpgradePage.open(context),
          child: const Text('تسجيل'),
        ),
        IconButton(
          tooltip: 'إخفاء',
          icon: Icon(Icons.close_rounded, size: 16, color: p.textMuted),
          onPressed: () => setState(() => _hidden = true),
        ),
      ]),
    );
  }
}

/// يُنادى قبل أي ميزة مقفلة على الزائر.
///
/// يُرجع `true` إن كانت مسموحة فيُكمل المستدعي عمله؛ وإن كانت مقفلة
/// يعرض رسالة المالك مع زرّ التسجيل ويُرجع `false`.
///
/// هذا **ليس** الحماية: الحماية خادمية داخل الدوال نفسها. هذا يوفّر على
/// المستخدم ضغطةً تنتهي برفض.
Future<bool> ensureGuestAllowed(
  BuildContext context,
  WidgetRef ref,
  String flag,
) async {
  final state = await ref.read(guestStateProvider.future);
  return _applyGuestGate(context, state, flag);
}

/// نفس الحارس بلا WidgetRef — لمن لا يملك `ref` (دوال ساكنة مثل
/// `GiftPickerSheet.show`). يقرأ الحالة من الخادم مباشرة.
Future<bool> ensureGuestAllowedDirect(
  BuildContext context,
  String flag,
) async {
  GuestState state;
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return true;
    state = GuestState.fromRpc(await client.rpc('get_my_guest_state'));
  } catch (_) {
    // المنع الحقيقي خادمي؛ التساهل هنا لا يفتح شيئًا.
    return true;
  }
  if (!context.mounted) return false;
  return _applyGuestGate(context, state, flag);
}

Future<bool> _applyGuestGate(
  BuildContext context,
  GuestState state,
  String flag,
) async {
  if (state.allows(flag)) return true;
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final p = sheetContext.palette;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline, color: p.accent, size: 34),
              const SizedBox(height: 12),
              Text(state.messageFor(flag),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: p.textPrimary, fontSize: 14, height: 1.6)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  GuestUpgradePage.open(context);
                },
                child: const Text('تسجيل الحساب الآن'),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('لاحقًا'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return false;
}
