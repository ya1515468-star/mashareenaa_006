import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../posts/domain/entities/post_entity.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../domain/repositories/search_repository.dart';

final profileSearchResultsProvider =
    FutureProvider.family<List<ProfileEntity>, String>((ref, query) async {
  final result = await sl<SearchRepository>().searchProfiles(query);
  return result.fold((failure) => [], (list) => list);
});

final postSearchResultsProvider =
    FutureProvider.family<List<PostEntity>, String>((ref, query) async {
  final result = await sl<SearchRepository>().searchPosts(query);
  return result.fold((failure) => [], (list) => list);
});
