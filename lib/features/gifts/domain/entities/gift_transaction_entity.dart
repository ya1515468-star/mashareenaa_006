import 'package:equatable/equatable.dart';
import 'gift_entity.dart';

class GiftTransactionEntity extends Equatable {
  final String id;
  final String giftId;
  final String fromUid;
  final String toUid;
  final int pricePoints;
  final DateTime createdAt;

  const GiftTransactionEntity({
    required this.id,
    required this.giftId,
    required this.fromUid,
    required this.toUid,
    required this.pricePoints,
    required this.createdAt,
  });

  // Was GiftCatalog.byId(giftId) — a synchronous lookup into the removed
  // hardcoded catalog. This entity is not currently constructed anywhere in
  // the live app (verified before removing GiftCatalog), so there is no
  // live caller to migrate to an async, server-backed lookup. Returning
  // null keeps this compiling honestly rather than resurrecting a stale
  // local copy of gift data.
  GiftEntity? get gift => null;

  @override
  List<Object?> get props =>
      [id, giftId, fromUid, toUid, pricePoints, createdAt];
}
