class MemberBadge {
  final String id;
  final String badgeKey;
  final String nameAr;
  final String category;
  final String? description;
  final String assetUrl;
  final String assetPath;
  final String mimeType;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final bool active;

  const MemberBadge({
    required this.id,
    required this.badgeKey,
    required this.nameAr,
    required this.category,
    required this.description,
    required this.assetUrl,
    required this.assetPath,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
    required this.active,
  });

  factory MemberBadge.fromMap(Map<String, dynamic> map) {
    return MemberBadge(
      id: '${map['id'] ?? ''}',
      badgeKey: '${map['badge_key'] ?? ''}',
      nameAr: '${map['name_ar'] ?? ''}',
      category: '${map['category'] ?? 'general'}',
      description: (map['description'] ?? '').toString().trim().isEmpty
          ? null
          : map['description'].toString(),
      assetUrl: '${map['asset_url'] ?? ''}',
      assetPath: '${map['asset_path'] ?? ''}',
      mimeType: '${map['mime_type'] ?? 'image/gif'}',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      active: map['active'] == true || map['is_active'] == true,
    );
  }
}
