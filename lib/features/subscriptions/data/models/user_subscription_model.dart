import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/subscription_tier_entity.dart';
import '../../domain/entities/user_subscription_entity.dart';

class UserSubscriptionModel extends UserSubscriptionEntity {
  const UserSubscriptionModel({
    required super.uid,
    required super.tierId,
    super.startedAt,
    super.expiresAt,
  });

  factory UserSubscriptionModel.fromMap(String uid, Map<String, dynamic> map) {
    final sub = (map['subscription'] as Map?) ?? {};
    return UserSubscriptionModel(
      uid: uid,
      tierId: sub['tierId'] as String? ?? SubscriptionCatalog.freeTierId,
      startedAt: (sub['startedAt'] as Timestamp?)?.toDate(),
      expiresAt: (sub['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
