import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.emailVerified,
    required super.status,
    required super.createdAt,
  });

  factory UserModel.fromSupabaseUser(
    sb.User user, {
    AccountStatus status = AccountStatus.active,
  }) {
    return UserModel(
      uid: user.id,
      email: user.email ?? '',
      emailVerified: user.emailConfirmedAt != null,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      status: status,
    );
  }

  UserModel copyWithStatus(AccountStatus status) {
    return UserModel(
      uid: uid,
      email: email,
      emailVerified: emailVerified,
      status: status,
      createdAt: createdAt,
    );
  }
}
