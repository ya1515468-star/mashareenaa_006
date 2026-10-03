import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../posts/domain/entities/post_entity.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<ProfileEntity>>> searchProfiles(
      String query) async {
    if (query.trim().isEmpty) return const Right([]);
    try {
      final results = await remoteDataSource.searchProfiles(query.trim());
      return Right(results);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> searchPosts(String query) async {
    if (query.trim().isEmpty) return const Right([]);
    try {
      final results = await remoteDataSource.searchPosts(query.trim());
      return Right(results);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
