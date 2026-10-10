import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class AiImage {
  final Uint8List bytes;
  final String mime;
  const AiImage(this.bytes, this.mime);
}

class AiAssistantStatus {
  final bool enabled;
  final bool subscriber;
  final int costPoints;
  final int imageCostPoints;
  final int freeDaily;
  final int freeLeft;
  final int balance;
  final bool isOwner;
  const AiAssistantStatus({
    required this.enabled,
    required this.subscriber,
    required this.costPoints,
    this.imageCostPoints = 0,
    required this.freeDaily,
    required this.freeLeft,
    required this.balance,
    this.isOwner = false,
  });

  factory AiAssistantStatus.fromMap(Map<String, dynamic> m) => AiAssistantStatus(
        enabled: m['enabled'] != false,
        subscriber: m['subscriber'] == true,
        costPoints: (m['cost_points'] as num?)?.toInt() ?? 0,
        imageCostPoints: (m['image_cost_points'] as num?)?.toInt() ?? 0,
        freeDaily: (m['free_daily'] as num?)?.toInt() ?? 0,
        freeLeft: (m['free_left'] as num?)?.toInt() ?? 0,
        balance: (m['balance'] as num?)?.toInt() ?? 0,
        isOwner: m['is_owner'] == true,
      );

  /// نص موجز يشرح للمستخدم كلفة السؤال القادم.
  String get hint {
    if (isOwner) return 'أنت المالك: بلا خصم نقاط';
    if (subscriber) return 'مجاني لك بحكم اشتراكك';
    if (freeLeft > 0) return 'متبقٍ لك $freeLeft سؤال مجاني اليوم';
    return 'كلفة السؤال $costPoints نقطة • رصيدك $balance';
  }

  /// كلفة توليد صورة: المالك والمشتركون مجانًا، وغيرهم بالنقاط.
  String get imageHint {
    if (isOwner) return 'توليد الصور مجاني لك (مالك)';
    if (subscriber) return 'توليد الصور مجاني لك بحكم اشتراكك';
    return 'كلفة الصورة $imageCostPoints نقطة • رصيدك $balance';
  }
}

class AiSource {
  final String title;
  final String url;
  const AiSource(this.title, this.url);
}

class AiPhoto {
  final Uint8List bytes;
  final String title;
  final String page;
  const AiPhoto(this.bytes, this.title, this.page);
}

class AiAnswer {
  final String transcript;
  final String answer;
  final Uint8List? image;
  final List<AiSource> sources;
  final List<AiPhoto> photos;
  /// طُلبت صور حقيقية لكن ميزة البحث عن الصور غير مضبوطة في الخادم.
  final bool photosMissing;
  const AiAnswer({
    required this.transcript,
    required this.answer,
    this.image,
    this.sources = const [],
    this.photos = const [],
    this.photosMissing = false,
  });
}

class AiAssistantException implements Exception {
  final String code;
  const AiAssistantException(this.code);

  String get message => switch (code) {
        'INSUFFICIENT_POINTS' => 'رصيد نقاطك غير كافٍ لهذا السؤال.',
        'RATE_LIMITED' => 'أرسلت أسئلة كثيرة، حاول بعد قليل.',
        'AI_DISABLED' => 'المساعد الذكي متوقف مؤقتًا من الإدارة.',
        'AI_NOT_CONFIGURED' =>
          'مفتاح الذكاء الاصطناعي غير مضبوط في الخادم (أضف السرّ GEMINI_API_KEY في Supabase ← Edge Functions ← Secrets).',
        'IMAGE_UNAVAILABLE' =>
          'توليد الصور غير متاح الآن على مفتاح الخدمة (قد يحتاج حسابًا مفوتَرًا في Google AI Studio). لم تُخصم أي نقاط.',
        'WEB_UNAVAILABLE' =>
          'البحث في الإنترنت غير متاح الآن على مفتاح الخدمة. لم تُخصم أي نقاط.',
        'NO_IMAGE' => 'لم يُنتج النموذج صورة، جرّب وصفًا آخر. لم تُخصم أي نقاط.',
        'EMPTY_REQUEST' => 'اكتب وصف الصورة المطلوبة.',
        'NO_SPEECH' => 'لم أسمع كلامًا واضحًا، حاول التسجيل مرة أخرى.',
        'FILE_TOO_LARGE' || 'INVALID_IMAGE' => 'الملف كبير أو غير مدعوم.',
        'AUTH_REQUIRED' => 'سجّل الدخول أولًا.',
        _ => 'تعذّر الحصول على إجابة الآن. لم تُخصم أي نقاط.',
      };

  @override
  String toString() => message;
}

class AiTierOption {
  final String id;
  final String name;
  bool included;
  AiTierOption(this.id, this.name, this.included);
}

class AiAdminConfig {
  bool enabled;
  int costPoints;
  int imageCostPoints;
  int freeDaily;
  int hourlyLimit;
  final List<AiTierOption> tiers;
  AiAdminConfig(this.enabled, this.costPoints, this.freeDaily, this.hourlyLimit, this.tiers,
      {this.imageCostPoints = 30});
}

class AiAssistantService {
  AiAssistantService._();

  static Future<AiAssistantStatus> status() async {
    final r = await SupabaseService.client.rpc('ai_assistant_status');
    return AiAssistantStatus.fromMap(Map<String, dynamic>.from(r as Map));
  }

  static Future<AiAnswer> ask({
    required String requestId,
    String text = '',
    Uint8List? audio,
    String audioMime = 'audio/webm',
    List<AiImage> images = const [],
    bool image = false,
    bool web = false,
  }) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'ai-assistant',
        body: {
          'request_id': requestId,
          if (image) 'mode': 'image' else if (web) 'mode': 'web',
          if (text.trim().isNotEmpty) 'text': text.trim(),
          if (audio != null) 'audio_base64': base64Encode(audio),
          if (audio != null) 'audio_mime': audioMime,
          if (images.isNotEmpty)
            'images': [
              for (final i in images) {'mime': i.mime, 'b64': base64Encode(i.bytes)}
            ],
        },
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        Uint8List? img;
        final im = data['image'];
        if (im is Map && im['b64'] != null) {
          img = base64Decode(im['b64'].toString());
        }
        return AiAnswer(
          transcript: (data['transcript'] ?? '').toString(),
          answer: (data['answer'] ?? '').toString(),
          image: img,
          sources: [
            for (final x in (data['sources'] as List? ?? const []))
              if (x is Map && x['url'] != null)
                AiSource((x['title'] ?? x['url']).toString(), x['url'].toString())
          ],
          photos: [
            for (final x in (data['photos'] as List? ?? const []))
              if (x is Map && x['b64'] != null)
                AiPhoto(base64Decode(x['b64'].toString()), (x['title'] ?? '').toString(),
                    (x['page'] ?? '').toString())
          ],
          photosMissing:
              data['photos_wanted'] == true && data['photos_configured'] == false,
        );
      }
      throw AiAssistantException(
          data is Map ? (data['error'] ?? 'AI_FAILED').toString() : 'AI_FAILED');
    } on FunctionException catch (e) {
      final d = e.details;
      throw AiAssistantException(
          d is Map ? (d['error'] ?? 'AI_FAILED').toString() : 'AI_FAILED');
    }
  }

  /// للمالك فقط: قراءة إعدادات الخدمة والباقات المشمولة.
  static Future<AiAdminConfig> adminGet() async {
    final r = Map<String, dynamic>.from(
        await SupabaseService.client.rpc('ai_assistant_admin_get') as Map);
    return AiAdminConfig(
      r['enabled'] != false,
      (r['cost_points'] as num?)?.toInt() ?? 0,
      (r['free_daily'] as num?)?.toInt() ?? 0,
      (r['hourly_limit'] as num?)?.toInt() ?? 30,
      [
        for (final t in (r['tiers'] as List? ?? const []))
          AiTierOption(
              (t as Map)['id'].toString(), t['name'].toString(), t['included'] == true)
      ],
      imageCostPoints: (r['image_cost_points'] as num?)?.toInt() ?? 30,
    );
  }

  /// للمالك فقط: حفظ السعر والحصة والباقات المجانية.
  static Future<void> adminSave(AiAdminConfig c) async {
    await SupabaseService.client.rpc('ai_assistant_admin_save', params: {
      'p_enabled': c.enabled,
      'p_cost_points': c.costPoints,
      'p_free_daily': c.freeDaily,
      'p_hourly_limit': c.hourlyLimit,
      'p_tier_ids': [for (final t in c.tiers) if (t.included) t.id],
    });
    await SupabaseService.client.rpc('ai_assistant_admin_set_image_cost',
        params: {'p_cost': c.imageCostPoints});
  }
}
