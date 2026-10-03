import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../../domain/repositories/friend_repository.dart';
import '../../domain/usecases/respond_to_friend_request_usecase.dart';
import '../../domain/usecases/send_friend_request_usecase.dart';

final friendRelationshipProvider =
    StreamProvider.family<FriendRequestEntity?, ({String uidA, String uidB})>(
  (ref, params) => sl<FriendRepository>()
      .watchRelationship(uidA: params.uidA, uidB: params.uidB),
);

final friendsListProvider =
    StreamProvider.family<List<FriendRequestEntity>, String>(
        (ref, uid) => sl<FriendRepository>().watchFriends(uid));

final pendingFriendRequestsProvider =
    StreamProvider.family<List<FriendRequestEntity>, String>(
  (ref, uid) => sl<FriendRepository>().watchPendingIncoming(uid),
);

class FriendController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> sendRequest(
      {required String fromUid, required String toUid}) async {
    final result =
        await sl<SendFriendRequestUseCase>()(fromUid: fromUid, toUid: toUid);
    return result.isRight();
  }

  Future<void> respond(FriendRequestEntity request,
      {required bool accept}) async {
    await sl<RespondToFriendRequestUseCase>()(request, accept: accept);
  }

  Future<void> removeFriend(
      {required String uidA, required String uidB}) async {
    await sl<FriendRepository>().removeFriend(uidA: uidA, uidB: uidB);
  }
}

final friendControllerProvider =
    AsyncNotifierProvider<FriendController, void>(FriendController.new);
