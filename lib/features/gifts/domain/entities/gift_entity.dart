import 'package:equatable/equatable.dart';

/// فئة الهدية — تحدد شدة الرسوم المتحركة عند الإهداء: الفئات
/// العليا (epic/legendary) تُشغّل الرسوم الكبيرة الملء-للشاشة على
/// طراز "الأسد/الحوت" في تيك توك، بينما small/medium تكتفي برسم
/// أصغر داخل فقاعة الدردشة نفسها. basic تطابق قيمة موجودة في
/// gift_catalog على الخادم ولا مقابل ثابت جاهز لها في الواجهة.
enum GiftTier { basic, small, medium, big, epic, legendary }

extension GiftTierX on GiftTier {
  static GiftTier fromWire(String? s) => GiftTier.values.firstWhere(
        (t) => t.name == s,
        orElse: () => GiftTier.small,
      );
}

class GiftEntity extends Equatable {
  final String id;
  final String emoji;
  final String nameAr;
  final int pricePoints;
  final GiftTier tier;

  const GiftEntity({
    required this.id,
    required this.emoji,
    required this.nameAr,
    required this.pricePoints,
    required this.tier,
  });

  /// يُبنى مباشرة من صف public.gift_catalog — لا كتالوج ثابت بديل.
  ///
  /// كان هنا سابقًا "GiftCatalog" ثابت بمئة هدية وأسعار مكتوبة في
  /// الكود (مثال: 🌹 وردة = 10 نقطة)، بينما السعر الحقيقي على
  /// الخادم كان 180 نقطة — فرق 18 مرة. الخادم نفسه كان يتحقق من
  /// السعر الصحيح دائمًا عند الإرسال الفعلي (send_gift_atomic يقرأ
  /// السعر من gift_catalog ولا يثق بما يرسله التطبيق)، فلم تكن هناك
  /// ثغرة مالية — لكن المستخدم كان يرى سعرًا خاطئًا تمامًا قبل
  /// الشراء. مصدر الحقيقة الوحيد الآن هو هذا الصف نفسه.
  factory GiftEntity.fromRow(Map<String, dynamic> row) => GiftEntity(
        id: row['id'].toString(),
        emoji: row['emoji']?.toString() ?? '🎁',
        nameAr: row['name_ar']?.toString() ?? row['id'].toString(),
        pricePoints: (row['price_points'] as num?)?.toInt() ?? 0,
        tier: GiftTierX.fromWire(row['tier']?.toString()),
      );

  @override
  List<Object?> get props => [id, emoji, nameAr, pricePoints, tier];
}
