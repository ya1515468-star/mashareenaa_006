import 'package:equatable/equatable.dart';

/// كيان الدور. نقطة الحقيقة الوحيدة للصلاحيات في كل النظام — كل
/// وحدة مستقبلية (المشاريع، السوق، المحفظة...) تعتمد على هذا الكيان
/// بدل بناء منطق صلاحيات خاص بها.
class RoleEntity extends Equatable {
  final String id;
  final String name;
  final List<String> permissions;
  final int priority;

  const RoleEntity({
    required this.id,
    required this.name,
    required this.permissions,
    required this.priority,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  List<Object?> get props => [id, name, permissions, priority];
}
