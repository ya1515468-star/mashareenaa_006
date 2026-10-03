import 'package:equatable/equatable.dart';

/// السجل المرتبط بالمستخدم لاسم مستخدم فريد + رمز PIN (5 خانات).
/// يُستخدم لتسجيل هوية مختصرة وقفل PIN سريع محلي — وليس كقناة
/// مصادقة شبكية بديلة عن البريد/كلمة المرور.
class UsernameCredentialEntity extends Equatable {
  final String uid;
  final String username;
  final DateTime createdAt;

  const UsernameCredentialEntity({
    required this.uid,
    required this.username,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [uid, username, createdAt];
}
