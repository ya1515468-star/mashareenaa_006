import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/producer_reel_entity.dart';

// ─── إعدادات الموسم (بانر الرأس) ────────────────────────────────────────────
final marketSeasonBannerProvider =
    StreamProvider.autoDispose<MarketSeasonBannerEntity?>((ref) {
  return Supabase.instance.client
      .from('market_season_banner')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .limit(1)
      .map((rows) {
        if (rows.isEmpty) return null;
        final r = rows.first;
        return MarketSeasonBannerEntity(
          title: r['title']?.toString(),
          date: r['date']?.toString(),
          seasonGifUrl: r['season_gif_url']?.toString(),
          backgroundUrl: r['background_url']?.toString(),
          isActive: r['is_active'] == true,
          titleEffects: r['title_effects'] is Map
              ? Map<String, dynamic>.from(r['title_effects'] as Map)
              : null,
        );
      });
});

// ─── فلتر الفئة ──────────────────────────────────────────────────────────────
final reelCategoryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// ─── ريلات سوق المنتجين مع الفلتر ──────────────────────────────────────────
final producerReelsProvider =
    StreamProvider.autoDispose.family<List<ProducerReelEntity>, String?>((ref, category) {
  final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  var query = Supabase.instance.client
      .from('producer_reels')
      .stream(primaryKey: ['id']);

  // تُرتَّب الريلات بالأحدث أولاً خادميًا
  return query.order('created_at', ascending: false).map((rows) {
    final filtered = category != null && category.isNotEmpty
        ? rows.where((r) => r['category']?.toString() == category).toList()
        : rows;
    return filtered
        // المعيار هو النشر لا الموافقة: is_approved يبقى false لكل
        // الريلات في هذا النظام، وكان هذا الشرط يُفرغ الصفحة تمامًا.
        // الحجب يتم عبر is_blocked من لوحة المالك.
        .where((r) {
          if (r['is_published'] != true || r['is_blocked'] == true) {
            return false;
          }
          // مدة الظهور التي يحدّدها المالك: بعد انتهائها يختفي الريل
          // من السوق تلقائيًا دون حذفه.
          final until = DateTime.tryParse(r['visible_until']?.toString() ?? '');
          return until == null || until.isAfter(DateTime.now());
        })
        .map((r) {
          final tags = (r['tags'] is List)
              ? (r['tags'] as List).map((t) => t.toString()).toList()
              : <String>[];
          final likedBy = (r['liked_by'] is List)
              ? (r['liked_by'] as List).map((e) => e.toString()).toList()
              : <String>[];
          final savedBy = (r['saved_by'] is List)
              ? (r['saved_by'] as List).map((e) => e.toString()).toList()
              : <String>[];
          return ProducerReelEntity(
            id: r['id']?.toString() ?? '',
            uid: r['uid']?.toString() ?? '',
            videoUrl: r['video_url']?.toString() ?? '',
            thumbnailUrl: r['thumbnail_url']?.toString(),
            title: r['title']?.toString() ?? '',
            description: r['description']?.toString() ?? '',
            category: r['category']?.toString() ?? 'other',
            tags: tags,
            likes: (r['likes_count'] as num?)?.toInt() ?? 0,
            views: (r['views_count'] as num?)?.toInt() ?? 0,
            saves: (r['saves_count'] as num?)?.toInt() ?? 0,
            comments: (r['comments_count'] as num?)?.toInt() ?? 0,
            shares: (r['shares_count'] as num?)?.toInt() ?? 0,
            isLikedByMe: likedBy.contains(myUid),
            isSavedByMe: savedBy.contains(myUid),
            createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                DateTime.now(),
            pointsCost: (r['points_cost'] as num?)?.toInt() ?? 0,
            isApproved: r['is_approved'] == true,
            ownerNote: r['owner_note']?.toString(),
          );
        })
        .toList();
  });
});

// ─── حصة النشر المتبقية للمستخدم الحالي ─────────────────────────────────────
final myReelQuotaProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final result = await Supabase.instance.client
      .rpc('get_my_reel_quota');
  if (result is Map) return Map<String, dynamic>.from(result);
  return {'used': 0, 'limit': 0, 'tier': 'free'};
});

// ─── تعليقات ريل محدد ────────────────────────────────────────────────────────
final reelCommentsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, reelId) {
  return Supabase.instance.client
      .from('reel_comments')
      .stream(primaryKey: ['id'])
      .eq('reel_id', reelId)
      .order('created_at', ascending: true)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

// ─── التحكم: إجراءات على الريلات ────────────────────────────────────────────
class ProducerMarketController extends StateNotifier<AsyncValue<void>> {
  ProducerMarketController() : super(const AsyncValue.data(null));

  final _db = Supabase.instance.client;

  Future<void> likeReel(String reelId) async {
    try {
      await _db.rpc('reel_interact',
          params: {'p_reel_id': reelId, 'p_action': 'like'});
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> saveReel(String reelId) async {
    try {
      await _db.rpc('reel_interact',
          params: {'p_reel_id': reelId, 'p_action': 'save'});
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> shareReel(String reelId) async {
    try {
      await _db.rpc('reel_interact',
          params: {'p_reel_id': reelId, 'p_action': 'share'});
    } catch (e) {
      // لا تُفشل التجربة بسبب خطأ في العدّاد
    }
  }

  Future<void> addComment(String reelId, String text) async {
    state = const AsyncValue.loading();
    try {
      // عبر RPC لا إدراجًا مباشرًا: الدالة تتحقق من الصلاحية وتزيد
      // comments_count في المعاملة نفسها.
      await _db.rpc('add_reel_comment', params: {
        'p_reel_id': reelId,
        'p_body': text.trim(),
        'p_reply_to': null,
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> publishReel({
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    int durationSeconds = 30,
    String publicationCurrency = 'points',
  }) async {
    state = const AsyncValue.loading();
    try {
      // المسار المدفوع لا المجاني.
      //
      // كان هذا ينادي publish_producer_reel — نسخة تنشر بلا مقابل،
      // فكل ريل كان مجانيًا مهما ضبط المالك الأسعار في لوحته.
      // publish_producer_reel_paid هي التي تقرأ عضوية العضو من
      // reel_membership_quotas، تفرض حصته الشهرية ومدته القصوى،
      // وتخصم publish_cost_points أو publish_cost_gems في معاملة
      // واحدة مع منع التكرار. المالك يُعفى تلقائيًا داخل الخادم.
      await _db.rpc('publish_producer_reel_paid', params: {
        'p_title': title,
        'p_video_url': videoUrl,
        'p_duration_seconds': durationSeconds,
        'p_publication_currency': publicationCurrency,
        'p_description': description,
        'p_thumbnail_url': thumbnailUrl,
        'p_business_id': null,
        'p_product_id': null,
        'p_sector_key': category,
        'p_price_minor_units': 0,
        'p_city': null,
        'p_tags': tags,
        'p_allow_download': true,
        'p_request_id': const Uuid().v4(),
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// يترجم أخطاء الخادم إلى رسائل يفهمها المستخدم.
  static String publishErrorMessage(Object e) {
    final s = e.toString();
    if (s.contains('REEL_QUOTA_EXCEEDED')) {
      return 'استنفدت حصتك الشهرية من الريلز. رقِّ عضويتك للمزيد.';
    }
    if (s.contains('DURATION_EXCEEDED')) {
      return 'مدة الفيديو تتجاوز الحد المسموح لعضويتك.';
    }
    if (s.contains('INSUFFICIENT')) {
      return 'رصيدك من النقاط أو الجواهر لا يكفي لرسوم النشر.';
    }
    if (s.contains('LEGAL_ACCEPTANCE_REQUIRED')) {
      return 'يجب الموافقة على شروط النشر أولًا.';
    }
    if (s.contains('INVALID_SECTOR') || s.contains('SECTOR_REQUIRED')) {
      return 'اختر قطاعًا صحيحًا للفيديو.';
    }
    if (s.contains('TITLE_REQUIRED')) return 'العنوان مطلوب.';
    if (s.contains('VIDEO_REQUIRED')) return 'الفيديو مطلوب.';
    return 'تعذّر النشر: $s';
  }

  Future<void> downloadReel(String reelId) async {
    try {
      await _db.rpc('reel_interact',
          params: {'p_reel_id': reelId, 'p_action': 'download'});
    } catch (_) {}
  }

  // مالك المنصة فقط
  Future<void> updateSeasonBanner({
    required String title,
    required String date,
    String? seasonGifUrl,
    String? backgroundUrl,
    Map<String, dynamic>? titleEffects,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('owner_set_market_season_banner', params: {
        'p_title': title,
        'p_season_date': date,
        'p_season_gif_url': seasonGifUrl,
        'p_background_url': backgroundUrl,
        'p_title_effects': titleEffects ?? {},
        'p_is_active': true,
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> moderateReel(
      {required String reelId, required bool approved}) async {
    state = const AsyncValue.loading();
    try {
      // owner_moderate_reel حُذفت من الخادم عند توحيد الريلز؛ هذا موضع
      // ثانٍ ما زال يستدعيها. owner_update_reel هي المسار الوحيد الحيّ.
      await _db.rpc('owner_update_reel', params: {
        'p_reel_id': reelId,
        'p_patch': approved
            ? {'is_published': true, 'is_approved': true, 'is_blocked': false}
            : {'is_blocked': true},
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final producerMarketControllerProvider =
    StateNotifierProvider<ProducerMarketController, AsyncValue<void>>(
        (ref) => ProducerMarketController());
