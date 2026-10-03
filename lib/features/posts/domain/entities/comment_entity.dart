import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
  final String id;
  final String postId;
  final String authorUid;
  final String text;
  final DateTime createdAt;

  const CommentEntity({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.text,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, postId, authorUid, text, createdAt];
}
