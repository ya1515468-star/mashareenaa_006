import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../entities/listing_entity.dart';

/// عملية الشراء الكاملة عبر دالة خادمية ذرّية واحدة (place_marketplace_order):
/// تقفل الإعلان، تتحقق من السعر والحالة من الوثيقة الحقيقية نفسها (لا يُثق
/// بسعر يحمله التطبيق محليًا، فقد يكون قديمًا إن غيّره البائع للتو)، تُحوّل
/// المال، تُعلّم الإعلان "مباعًا"، وتُنشئ سجل الطلب — كل ذلك معًا أو لا شيء
/// منه إطلاقًا.
///
/// كانت هذه العملية سابقًا خطوتين منفصلتين تمامًا (تحويل مالي، ثم إنشاء
/// طلب)، والتطبيق نفسه كان يعترف في تعليقه أن فشل الخطوة الثانية بعد نجاح
/// الأولى يترك المال منقولًا فعليًا بلا أي سجل طلب مقابل. كما لم يكن أي شيء
/// يُعلّم الإعلان كمُباع بعد الشراء — نفس الإعلان الفريد (خدمة تفصيل مثلًا)
/// كان قابلًا للشراء من عدد غير محدود من الأشخاص في آن واحد. الإشعار للبائع
/// يُرسله المحفّز الخادمي عبر write_audit، لا التطبيق.
class PlaceOrderUseCase {
  const PlaceOrderUseCase();

  Future<Either<Failure, void>> call({
    required ListingEntity listing,
    required String buyerUid,
  }) async {
    if (listing.sellerUid == buyerUid) {
      return const Left(
          ValidationFailure(message: 'لا يمكنك شراء إعلانك الخاص'));
    }
    if (listing.status != ListingStatus.active) {
      return const Left(
          ValidationFailure(message: 'هذا الإعلان لم يعد متاحًا'));
    }

    try {
      await Supabase.instance.client.rpc('place_marketplace_order', params: {
        'p_listing_id': listing.id,
        'p_idempotency_key': const Uuid().v4(),
      });
      return const Right(null);
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        String m when m.contains('LISTING_NOT_AVAILABLE') =>
          'هذا الإعلان لم يعد متاحًا — ربما بيع للتو.',
        String m when m.contains('INSUFFICIENT_BALANCE') =>
          'رصيدك لا يكفي لإتمام هذا الشراء.',
        String m when m.contains('CANNOT_BUY_OWN_LISTING') =>
          'لا يمكنك شراء إعلانك الخاص.',
        String m when m.contains('LISTING_NOT_FOUND') =>
          'تعذّر العثور على هذا الإعلان.',
        _ => e.message,
      };
      return Left(ValidationFailure(message: message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
