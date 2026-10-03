import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_data_source.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

class PostRepositoryImpl implements PostRepository {
  final PostRemoteDataSource remoteDataSource;

  PostRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<PostEntity>> watchFeed({String? category}) =>
      remoteDataSource.watchFeed(category: category);

  @override
  Future<Either<Failure, void>> createPost(PostEntity post) async {
    try {
      await remoteDataSource.createPost(PostModel.fromEntity(post));
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      await remoteDataSource.deletePost(postId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleLike(
      {required String postId, required String uid}) async {
    try {
      await remoteDataSource.toggleLike(postId: postId, uid: uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isLikedByUser(
      {required String postId, required String uid}) async {
    try {
      final liked =
          await remoteDataSource.isLikedByUser(postId: postId, uid: uid);
      return Right(liked);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<CommentEntity>> watchComments(String postId) =>
      remoteDataSource.watchComments(postId);

  @override
  Future<Either<Failure, void>> addComment(CommentEntity comment) async {
    try {
      await remoteDataSource.addComment(
        CommentModel(
          id: '',
          postId: comment.postId,
          authorUid: comment.authorUid,
          text: comment.text,
          createdAt: comment.createdAt,
        ),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      await remoteDataSource.deleteComment(
          postId: postId, commentId: commentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
