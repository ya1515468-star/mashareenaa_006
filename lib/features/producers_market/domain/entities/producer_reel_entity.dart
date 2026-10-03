import 'package:equatable/equatable.dart';

/// كيان الريل في سوق المنتجين — كل ريل هو منتج موجه لقطاع الألبسة
/// يُنشر بالدقائق ويخضع لحصة العضوية المدفوعة التي يتحكم بها المالك.
class ProducerReelEntity extends Equatable {
  final String id;
  final String uid;
  final String videoUrl;
  final String? thumbnailUrl;
  final String title;
  final String description;
  final String category; // embroidery | packaging | washing | dyeing | cutting | etc.
  final List<String> tags;
  final int likes;
  final int views;
  final int saves;
  final int comments;
  final int shares;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final DateTime createdAt;
  final int pointsCost; // نقاط اللازمة للنشر
  final bool isApproved;
  final String? ownerNote; // ملاحظة المالك (نموسم شتاء مثلاً)

  const ProducerReelEntity({
    required this.id,
    required this.uid,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.category,
    this.tags = const [],
    this.likes = 0,
    this.views = 0,
    this.saves = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    required this.createdAt,
    this.pointsCost = 0,
    this.isApproved = true,
    this.ownerNote,
  });

  @override
  List<Object?> get props => [id, uid, videoUrl, title, likes, views, saves];
}

/// إعدادات رأس سوق المنتجين التي يتحكم بها المالك خادميًا
class MarketSeasonBannerEntity extends Equatable {
  final String? title; // مثال: موسم شتاء 2027
  final String? date;
  final String? seasonGifUrl; // gif ثلوج أو شمس
  final String? backgroundUrl;
  final bool isActive;
  final Map<String, dynamic>? titleEffects; // نفس تأثيرات اسم المستخدم الـ100

  const MarketSeasonBannerEntity({
    this.title,
    this.date,
    this.seasonGifUrl,
    this.backgroundUrl,
    this.isActive = false,
    this.titleEffects,
  });

  @override
  List<Object?> get props => [title, date, seasonGifUrl, backgroundUrl, isActive];
}
