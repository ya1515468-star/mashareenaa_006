import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/usecases/start_call_usecase.dart';

final incomingRingingCallProvider = StreamProvider<CallEntity?>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return sl<CallRepository>().watchIncomingRingingCall(uid);
});

final callByIdProvider =
    StreamProvider.family<CallEntity?, String>((ref, callId) {
  return sl<CallRepository>().watchCall(callId);
});

class CallController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// كان يُعيد null دائمًا عند أي فشل (رصيد، حظر، خدمة معطّلة...) بلا أي
  /// رسالة خطأ حقيقية — المتصل يرى فقط رسالة عامة "تعذّر بدء الاتصال"
  /// دون معرفة السبب الفعلي أبدًا. الآن يُعاد Either الحقيقي كاملًا.
  Future<Either<Failure, CallEntity>> startCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  }) {
    return sl<StartCallUseCase>()(
        callerUid: callerUid, calleeUid: calleeUid, type: type);
  }

  Future<void> updateStatus(
      {required String callId, required CallStatus status}) async {
    await sl<CallRepository>().updateStatus(callId: callId, status: status);
  }
}

final callControllerProvider =
    AsyncNotifierProvider<CallController, void>(CallController.new);
