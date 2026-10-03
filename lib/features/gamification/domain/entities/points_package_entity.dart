// ignore_for_file: unused_import

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show IconData, Icons, Color;

/// ═══════════════════════════════════════════════════════════════
///  كيان حزمة النقاط + الكتالوج الضخم
///  • يدعم 18 حزمة موزعة على 5 فئات
///  • يدعم 5 مستويات ندرة بألوان مميزة
///  • يظل قابلًا للتحويل إلى Remote Config دون تغيير المنطق
///  • متوافق مع `Money` القديم عبر alias `minorUnits`
/// ═══════════════════════════════════════════════════════════════

/// ───────────────────────────────────────────────────────────────
///  مستويات الندرة (تحدد اللون والأيقونة)
/// ───────────────────────────────────────────────────────────────
enum Rarity {
  common(
    Icons.circle_outlined,
    Color(0xFF9E9E9E),
    'عادي',
  ),
  rare(
    Icons.star_outline,
    Color(0xFF2196F3),
    'نادر',
  ),
  epic(
    Icons.auto_awesome,
    Color(0xFF9C27B0),
    'ملحمي',
  ),
  legendary(
    Icons.workspace_premium,
    Color(0xFFFFA000),
    'أسطوري',
  ),
  mythic(
    Icons.shield_moon,
    Color(0xFFE91E63),
    'خرافي',
  );

  final IconData icon;
  final Color color;
  final String label;
  const Rarity(this.icon, this.color, this.label);
}

/// ───────────────────────────────────────────────────────────────
///  فئات الحزم (للتصفية والعرض)
/// ───────────────────────────────────────────────────────────────
enum PackageCategory {
  points('نقاط'),
  gems('جواهر'),
  mixed('مختلطة'),
  bulk('جملة'),
  daily('يومية');

  final String label;
  const PackageCategory(this.label);
}

/// ───────────────────────────────────────────────────────────────
///  كيان السعر
///  • متوافق مع `Money` القديم عبر getter `minorUnits`
///  • يدعم العمل بأي عملة
/// ───────────────────────────────────────────────────────────────
class Price {
  final double amount;
  final String currency;

  /// alias للتوافق الخلفي مع `Money.minorUnits`
  int get minorUnits => (amount * 100).round();

  const Price(this.amount, this.currency);

  /// constructor بديل للتوافق الخلفي (يستقبل minorUnits)
  const Price.fromMinorUnits(int minorUnits, this.currency)
      : amount = minorUnits / 100.0;

  String get formatted {
    final symbol = currency == 'shamCash' ? 'ش.ك' : '\$';
    if (amount == amount.truncate()) {
      return '$symbol${amount.toStringAsFixed(0)}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Price && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => 'Price($amount $currency)';
}

/// ───────────────────────────────────────────────────────────────
///  الكيان الأساسي
/// ───────────────────────────────────────────────────────────────
class PointsPackageEntity extends Equatable {
  final String id;
  final String title;
  final int pointsGranted;
  final Price price;
  final PackageCategory category;
  final Rarity rarity;
  final String icon;
  final bool isFeatured;

  const PointsPackageEntity({
    required this.id,
    required this.title,
    required this.pointsGranted,
    required this.price,
    this.category = PackageCategory.points,
    this.rarity = Rarity.common,
    this.icon = '⭐',
    this.isFeatured = false,
  });

  PointsPackageEntity copyWith({
    String? id,
    String? title,
    int? pointsGranted,
    Price? price,
    PackageCategory? category,
    Rarity? rarity,
    String? icon,
    bool? isFeatured,
  }) {
    return PointsPackageEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      pointsGranted: pointsGranted ?? this.pointsGranted,
      price: price ?? this.price,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      icon: icon ?? this.icon,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        pointsGranted,
        price,
        category,
        rarity,
        icon,
        isFeatured,
      ];
}

// كان هنا سابقًا "PointsCatalog" — 18 باقة نقاط/جواهر بأسعار دولار
// ثابتة مكتوبة في الكود. تحقّقت أنه لا يُستخدم في أي شاشة حالية
// (صفر استدعاء لـPointsCatalog. في كل المشروع) — كان وزنًا ميتًا،
// ومصدر حقيقة ثانٍ خطر لو استُخدم بالخطأ لاحقًا. حُذف؛
// PointsPackageEntity وحدها (فوق) هي الشكل الذي يُبنى من بيانات
// الخادم الحقيقية عبر gamification_remote_data_source.
