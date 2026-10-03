import 'package:equatable/equatable.dart';

enum PostMediaType { none, image, video }

extension PostMediaTypeX on PostMediaType {
  String get wire => name;

  static PostMediaType fromWire(String? s) => PostMediaType.values
      .firstWhere((e) => e.wire == s, orElse: () => PostMediaType.none);
}

class PostEntity extends Equatable {
  final String id;
  final String authorUid;
  final String text;
  final List<String> mediaUrls;
  final PostMediaType mediaType;
  final String category;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final bool isHidden;
  final DateTime createdAt;

  const PostEntity({
    required this.id,
    required this.authorUid,
    required this.text,
    this.mediaUrls = const [],
    this.mediaType = PostMediaType.none,
    required this.category,
    this.tags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isHidden = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        authorUid,
        text,
        mediaUrls,
        mediaType,
        category,
        tags,
        likesCount,
        commentsCount,
        isHidden,
        createdAt,
      ];
}
