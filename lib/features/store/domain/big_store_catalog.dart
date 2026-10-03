class BigStoreProduct {
  final String id;
  final String sku;
  final String section;
  final String nameAr;
  final int pricePoints;
  final int priceGems;
  final String assetUrl;
  final String rarity;
  final bool featured;
  final String? membershipTier;
  const BigStoreProduct(
      {required this.id,
      required this.sku,
      required this.section,
      required this.nameAr,
      required this.pricePoints,
      required this.priceGems,
      required this.assetUrl,
      required this.rarity,
      required this.featured,
      this.membershipTier});
}

// كان هنا سابقًا "BigStoreCatalog" — قائمة ثابتة من 2200+ سطر بأسعار
// منتجات مكتوبة في الكود. تحقّقت أن points_store_page.dart (المستخدِم
// الوحيد لهذا الملف) يقرأ فعليًا من ListStoreCatalogUseCase (خادم
// حقيقي) ولا يستخدم هذه القائمة إطلاقًا — كانت وزنًا ميتًا ومصدر
// حقيقة ثانٍ محتمل الخطر. حُذفت؛ BigStoreProduct وحدها (فوق) هي
// الشكل الذي يُبنى من بيانات الخادم الحقيقية.
