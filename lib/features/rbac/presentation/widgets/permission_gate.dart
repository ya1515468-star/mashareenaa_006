import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rbac_provider.dart';

/// يُستخدم لتغليف أي عنصر واجهة (زر، بطاقة، شاشة) بحيث لا يظهر إلا
/// إذا كان المستخدم الحالي يملك الصلاحية المطلوبة. كل وحدة مستقبلية
/// (لوحة الإدارة، السوق، المشاريع...) تستخدم نفس الويدجت بدل تكرار
/// منطق التحقق داخل كل شاشة.
class PermissionGate extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(hasPermissionProvider(permission));

    return permissionAsync.when(
      data: (allowed) =>
          allowed ? child : (fallback ?? const SizedBox.shrink()),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
    );
  }
}
