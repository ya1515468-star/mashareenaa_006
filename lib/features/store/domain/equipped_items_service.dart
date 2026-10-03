import '../../../core/data/supabase_document_compat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import 'entities/store_item_entity.dart';

/// يخزّن العنصر المُجهَّز (Equipped) حاليًا لكل فئة على حساب
/// المستخدم مباشرة (وليس على ProfileEntity الأوسع، لتفادي أي تعديل
/// إضافي على نموذج البروفايل الأساسي المستخدَم في عشرات الأماكن —
/// تقليل خطر أي انحدار جديد قدر الإمكان في هذا التسليم).
class EquippedItemsService {
  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      SupabaseDocumentStore.instance
          .collection(BackendCollections.accounts)
          .doc(uid);

  static Future<void> equip(
      {required String uid,
      required StoreItemCategory category,
      required String itemId}) async {
    await _doc(uid).set({
      'equippedItems': {category.wire: itemId},
    }, const SetOptions(merge: true));
  }

  static Future<void> unequip(
      {required String uid, required StoreItemCategory category}) async {
    await _doc(uid).set({
      'equippedItems': {category.wire: FieldValue.delete()},
    }, const SetOptions(merge: true));
  }

  static Stream<Map<String, String>> watchEquipped(String uid) {
    return _doc(uid).snapshots().map((doc) {
      final raw = doc.data()?['equippedItems'] as Map? ?? {};
      return raw.map((k, v) => MapEntry(k as String, v as String));
    });
  }
}

final equippedItemsProvider =
    StreamProvider.autoDispose.family<Map<String, String>, String>((ref, uid) {
  return EquippedItemsService.watchEquipped(uid);
});
