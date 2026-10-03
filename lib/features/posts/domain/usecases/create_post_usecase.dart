import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/post_entity.dart';
import '../repositories/post_repository.dart';

class CreatePostUseCase {
  final PostRepository repository;

  const CreatePostUseCase(this.repository);

  Future<Either<Failure, void>> call(PostEntity post) async {
    if (post.text.trim().isEmpty && post.mediaUrls.isEmpty) {
      return const Left(ValidationFailure(message: 'لا يمكن نشر منشور فارغ'));
    }
    return repository.createPost(post);
  }
}
