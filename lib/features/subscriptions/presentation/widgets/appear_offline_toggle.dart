import '../../../../core/data/supabase_document_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/subscription_tier_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

final effectiveFeaturesProvider = FutureProvider.autoDispose
    .family<MembershipFeatures, String>((ref, uid) async {
  final result = await sl<SubscriptionRepository>().getEffectiveFeatures(uid);
  return result.fold(
      (failure) => const MembershipFeatures(), (features) => features);
});

/// ميزة 10 من القائمة الإضافية: مفتاح "إخفاء حالة الاتصال" — يظهر
/// فقط لمن تملك عضويته canHideOnlineStatus (الملكية/VIP/الأسطورية
/// أو من مُنحت الميزة يدويًا من DRAGON).
class AppearOfflineToggle extends ConsumerStatefulWidget {
  final String uid;
  const AppearOfflineToggle({super.key, required this.uid});

  @override
  ConsumerState<AppearOfflineToggle> createState() =>
      _AppearOfflineToggleState();
}

class _AppearOfflineToggleState extends ConsumerState<AppearOfflineToggle> {
  bool? _value;

  Future<void> _load() async {
    final doc = await sl<SupabaseDocumentStore>()
        .collection(BackendCollections.accounts)
        .doc(widget.uid)
        .get();
    if (mounted) setState(() => _value = doc.data()?['appearOffline'] == true);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(effectiveFeaturesProvider(widget.uid));
    final p = context.palette;

    return featuresAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (features) {
        if (!features.canHideOnlineStatus || _value == null) {
          return const SizedBox.shrink();
        }
        return SwitchListTile(
          value: _value!,
          onChanged: (v) async {
            setState(() => _value = v);
            await sl<SupabaseDocumentStore>()
                .collection(BackendCollections.accounts)
                .doc(widget.uid)
                .set({'appearOffline': v}, const SetOptions(merge: true));
          },
          activeThumbColor: p.accent,
          title: const Text('إخفاء حالة الاتصال',
              style: TextStyle(fontSize: 13.5)),

        );
      },
    );
  }
}
