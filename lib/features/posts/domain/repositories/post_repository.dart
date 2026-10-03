import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/comment_entity.dart';
import '../entities/post_entity.dart';

abstract class PostRepository {
  /// يبث المنشورات مرتبة بالأحدث أولًا، مع فلترة اختيارية بالقسم.
  /// المنشورات المخفية (isHidden) لا تظهر إلا لصاحبها أو لمن يملك
  /// صلاحية moderate_content — الفلترة تتم في طبقة الـ UseCase.
  Stream<List<PostEntity>> watchFeed({String? category});

  Future<Either<Failure, void>> createPost(PostEntity post);

  /// يحذف منشورًا. لا تتحقق هذه الدالة من الملكية أو الصلاحية —
  /// التحقق (المالك نفسه أو صاحب moderate_content) يتم داخل
  /// [DeletePostUseCase] قبل الوصول لهذه الطبقة.
  Future<Either<Failure, void>> deletePost(String postId);

  /// يبدّل حالة الإعجاب (Like/Unlike) ضمن معاملة طبقة بيانات Supabase ذرية
  /// تحدّث العدّاد ووثيقة الإعجاب الفردية معًا.
  Future<Either<Failure, void>> toggleLike(
      {required String postId, required String uid});

  Future<Either<Failure, bool>> isLikedByUser(
      {required String postId, required String uid});

  Stream<List<CommentEntity>> watchComments(String postId);

  Future<Either<Failure, void>> addComment(CommentEntity comment);

  Future<Either<Failure, void>> deleteComment(
      {required String postId, required String commentId});
}
