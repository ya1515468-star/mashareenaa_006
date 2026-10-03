import 'package:equatable/equatable.dart';
import 'subscription_tier_entity.dart';

class UserSubscriptionEntity extends Equatable {
  final String uid;
  final String tierId;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  const UserSubscriptionEntity({
    required this.uid,
    required this.tierId,
    this.startedAt,
    this.expiresAt,
  });

  static UserSubscriptionEntity free(String uid) =>
      UserSubscriptionEntity(uid: uid, tierId: SubscriptionCatalog.freeTierId);

  /// العضوية المدفوعة تُعتبر منتهية تلقائيًا بعد تاريخ الانتهاء —
  /// هذا الفحص يُطبَّق في كل نقطة استخدام (تأثيرات الأسماء، مضاعِف
  /// المكافأة) فلا تبقى مزايا العضوية فعّالة بعد انتهائها.
  bool get isActive {
    if (tierId == SubscriptionCatalog.freeTierId) return true;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  /// المستوى الفعلي بعد تطبيق فحص الانتهاء — يعود دائمًا لـ "مجاني"
  /// إن كانت العضوية المدفوعة منتهية.
  SubscriptionTierEntity get effectiveTier {
    if (!isActive) return SubscriptionCatalog.free;
    return SubscriptionCatalog.byId(tierId) ?? SubscriptionCatalog.free;
  }

  @override
  List<Object?> get props => [uid, tierId, startedAt, expiresAt];
}
