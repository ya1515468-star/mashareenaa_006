import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/post_entity.dart';

class PostModel extends PostEntity {
  const PostModel({
    required super.id,
    required super.authorUid,
    required super.text,
    super.mediaUrls,
    super.mediaType,
    required super.category,
    super.tags,
    super.likesCount,
    super.commentsCount,
    super.isHidden,
    required super.createdAt,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] as List? ?? []),
      mediaType: PostMediaTypeX.fromWire(map['mediaType'] as String?),
      category: map['category'] as String? ?? 'general',
      tags: List<String>.from(map['tags'] as List? ?? []),
      likesCount: map['likesCount'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      isHidden: map['isHidden'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PostModel.fromEntity(PostEntity e) => PostModel(
        id: e.id,
        authorUid: e.authorUid,
        text: e.text,
        mediaUrls: e.mediaUrls,
        mediaType: e.mediaType,
        category: e.category,
        tags: e.tags,
        createdAt: e.createdAt,
      );

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'text': text,
      'mediaUrls': mediaUrls,
      'mediaType': mediaType.wire,
      'category': category,
      'tags': tags,
      'likesCount': 0,
      'commentsCount': 0,
      'isHidden': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
