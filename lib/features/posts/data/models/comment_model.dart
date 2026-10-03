import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/comment_entity.dart';

class CommentModel extends CommentEntity {
  const CommentModel({
    required super.id,
    required super.postId,
    required super.authorUid,
    required super.text,
    required super.createdAt,
  });

  factory CommentModel.fromMap(
      String id, String postId, Map<String, dynamic> map) {
    return CommentModel(
      id: id,
      postId: postId,
      authorUid: map['authorUid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
