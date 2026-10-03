import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// قطاع الألبسة الموحّد.
///
/// يقرأ من نظام `garment_*` الخادمي القائم — 24 قطاعًا، كتالوج خدمات،
/// منشآت، إعلانات خدمات، ورسوم نشر بالنقاط/الجواهر — بدل نظام
/// `factory_*` الموازي الذي حُذف لأنه كان يكرّر هذا دون داعٍ ويشتّت
/// البيانات بين مسارين.

final _db = Supabase.instance.client;

/// قطاعات الألبسة (خياطة، ورشة، مصنع، أقمشة، تطريز…)
final garmentSectorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await _db
      .from('garment_sectors')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows as List);
});

/// كتالوج الخدمات داخل كل قطاع
final garmentServiceCatalogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await _db.rpc('get_garment_service_catalog');
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

/// دليل المنشآت — بحث وفلترة خادميًا
class GarmentDirectoryArgs {
  final String? sectorKey;
  final String? city;
  final String search;
  const GarmentDirectoryArgs({this.sectorKey, this.city, this.search = ''});

  @override
  bool operator ==(Object other) =>
      other is GarmentDirectoryArgs &&
      other.sectorKey == sectorKey &&
      other.city == city &&
      other.search == search;

  @override
  int get hashCode => Object.hash(sectorKey, city, search);
}

final garmentDirectoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, GarmentDirectoryArgs>(
        (ref, args) async {
  final raw = await _db.rpc('browse_garment_directory', params: {
    'p_sector_key': args.sectorKey,
    'p_city': args.city,
    'p_search': args.search.trim().isEmpty ? null : args.search.trim(),
    'p_limit': 60,
    'p_offset': 0,
  });
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

/// إعلانات الخدمات المنشورة في قطاع
final garmentServiceAdsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, sectorKey) async {
  final raw = await _db
      .rpc('get_garment_service_ads', params: {'p_sector_key': sectorKey});
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

/// منشآت المستخدم الحالي
final myGarmentBusinessesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await _db.rpc('get_my_garment_businesses');
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

/// رسوم النشر التي يحدّدها المالك
final garmentPublicationFeesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await _db.rpc('get_garment_publication_fees');
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

/// عمليات الكتابة — كلها خادمية عبر RPC
class GarmentActions {
  const GarmentActions._();

  /// إنشاء/تعديل منشأة. `p_id` فارغ = إنشاء جديد.
  static Future<String?> upsertBusiness({
    String? id,
    required String businessName,
    required String sectorKey,
    String? description,
    String? city,
    String? address,
    String? phone,
    String? whatsapp,
    String? logoUrl,
    String? coverUrl,
    List<String> gallery = const [],
    int? minOrderQty,
    int? capacityPerMonth,
    int? establishedYear,
    bool isPublished = false,
  }) async {
    final res = await _db.rpc('upsert_garment_business', params: {
      'p_id': id,
      'p_business_name': businessName,
      'p_sector_key': sectorKey,
      'p_description': description,
      'p_city': city,
      'p_address': address,
      'p_phone': phone,
      'p_whatsapp': whatsapp,
      'p_logo_url': logoUrl,
      'p_cover_url': coverUrl,
      'p_gallery': gallery,
      'p_min_order_qty': minOrderQty,
      'p_capacity_per_month': capacityPerMonth,
      'p_established_year': establishedYear,
      'p_is_published': isPublished,
    });
    if (res is Map) return res['id']?.toString();
    return res?.toString();
  }

  /// نشر منشأة — يخصم رسوم النشر التي حدّدها المالك.
  static Future<Map<String, dynamic>> publishBusiness({
    required String businessId,
    String currency = 'points',
  }) async {
    final res = await _db.rpc('publish_garment_business', params: {
      'p_business_id': businessId,
      'p_currency': currency,
      // كانت null فتُرفض الدالة فورًا بـ PUBLICATION_REQUEST_REQUIRED —
      // سبب "النشر غير متاح" بالكامل. معرّف فريد يمنع خصم الرسوم
      // مرتين لو أُعيدت المحاولة بعد انقطاع شبكة.
      'p_request_id': const Uuid().v4(),
    });
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  /// نشر إعلان خدمة — يخصم الرسوم أيضًا.
  static Future<Map<String, dynamic>> publishServiceAd({
    required String serviceKey,
    required String sectorKey,
    required String title,
    String? description,
    int priceMinorUnits = 0,
    // الخادم يقبل sham_cash فقط لسعر الخدمة ويرفض غيره بـ
    // INVALID_PRICE_CURRENCY — كان الافتراضي 'USD' فيُرفض كل نشر.
    String currency = 'sham_cash',
    String? unit,
    int? minQty,
    String? city,
    String? address,
    String? phone,
    String? whatsapp,
    List<String> images = const [],
    Map<String, dynamic> specs = const {},
    String publicationCurrency = 'points',
  }) async {
    final res = await _db.rpc('publish_garment_service_ad', params: {
      'p_service_key': serviceKey,
      'p_sector_key': sectorKey,
      'p_title': title,
      'p_description': description,
      'p_price_minor_units': priceMinorUnits,
      'p_currency': currency,
      'p_unit': unit,
      'p_min_qty': minQty,
      'p_city': city,
      'p_address': address,
      'p_phone': phone,
      'p_whatsapp': whatsapp,
      'p_images': images,
      'p_specs': specs,
      'p_publication_currency': publicationCurrency,
      'p_request_id': const Uuid().v4(),
    });
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  /// المالك: قبول/رفض إعلان خدمة
  /// تحكّم المالك الشامل: kind = sector | business | ad،
  /// action = create | update | delete. محروسة خادميًا (OWNER_ONLY).
  static Future<void> ownerManage(
          String kind, String id, String action, Map<String, dynamic> patch) =>
      _db.rpc('owner_manage_garment', params: {
        'p_kind': kind,
        'p_id': id,
        'p_action': action,
        'p_patch': patch,
      });

  static Future<void> setAdStatus(String adId, String status) =>
      _db.rpc('admin_set_garment_service_ad_status',
          params: {'p_ad_id': adId, 'p_status': status});

  /// المالك: تحديد رسوم النشر
  static Future<void> setPublicationFee({
    required String contentType,
    required int pointsCost,
    required int gemsCost,
    bool isEnabled = true,
  }) =>
      _db.rpc('admin_upsert_garment_publication_fee', params: {
        'p_content_type': contentType,
        'p_points_cost': pointsCost,
        'p_gems_cost': gemsCost,
        'p_is_enabled': isEnabled,
      });
}
