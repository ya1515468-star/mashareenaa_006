import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/pattern_enums.dart';
import '../../domain/entities/pattern_request_entity.dart';
import '../../domain/repositories/pattern_studio_repository.dart';
import '../../domain/usecases/submit_pattern_request_usecase.dart';
import '../../domain/usecases/submit_pattern_result_usecase.dart';
import '../../domain/usecases/update_pattern_config_usecase.dart';

final patternConfigProvider =
    FutureProvider<PatternStudioConfigEntity>((ref) async {
  final result = await sl<PatternStudioRepository>().getConfig();
  return result.fold(
      (failure) => PatternStudioConfigEntity.fallback(), (config) => config);
});

final myPatternRequestsProvider =
    StreamProvider.family<List<PatternRequestEntity>, String>((ref, uid) {
  return sl<PatternStudioRepository>().watchMyRequests(uid);
});

final allPatternRequestsProvider =
    StreamProvider.family<List<PatternRequestEntity>, PatternRequestStatus?>(
        (ref, status) {
  return sl<PatternStudioRepository>().watchAllRequests(status: status);
});

class PatternStudioController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitRequest({
    required String uid,
    required String sourceImageUrl,
    required MannequinType mannequinType,
    String? notes,
  }) async {
    state = const AsyncLoading();
    final result = await sl<SubmitPatternRequestUseCase>()(
      uid: uid,
      sourceImageUrl: sourceImageUrl,
      mannequinType: mannequinType,
      notes: notes,
    );
    return result.fold((failure) {
      state = AsyncError(failure.message, StackTrace.current);
      return false;
    }, (_) {
      state = const AsyncData(null);
      return true;
    });
  }

  Future<bool> updateConfig({
    required PatternStudioConfigEntity config,
    required String requestedByUid,
  }) async {
    final result = await sl<UpdatePatternConfigUseCase>()(
        config: config, requestedByUid: requestedByUid);
    return result.isRight();
  }

  Future<bool> submitResult({
    required String requestId,
    required String requesterUid,
    required String reviewedByUid,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  }) async {
    final result = await sl<SubmitPatternResultUseCase>()(
      requestId: requestId,
      requesterUid: requesterUid,
      reviewedByUid: reviewedByUid,
      resultImageUrl: resultImageUrl,
      resultVideoUrl: resultVideoUrl,
      reviewerNote: reviewerNote,
    );
    return result.isRight();
  }
}

final patternStudioControllerProvider =
    AsyncNotifierProvider<PatternStudioController, void>(
        PatternStudioController.new);
