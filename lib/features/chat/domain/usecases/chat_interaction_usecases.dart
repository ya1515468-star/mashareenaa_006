import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/chat_repository.dart';

class EditMessageUseCase {
  final ChatRepository repository;
  const EditMessageUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String threadId,
    required String messageId,
    required String newText,
  }) {
    if (newText.trim().isEmpty) {
      return Future.value(const Left(
          ValidationFailure(message: 'لا يمكن أن تكون الرسالة فارغة')));
    }
    return repository.editMessage(
        threadId: threadId, messageId: messageId, newText: newText.trim());
  }
}

class DeleteMessageUseCase {
  final ChatRepository repository;
  const DeleteMessageUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String threadId,
    required String messageId,
    required String requesterUid,
    required bool forEveryone,
  }) {
    return repository.deleteMessage(
      threadId: threadId,
      messageId: messageId,
      requesterUid: requesterUid,
      forEveryone: forEveryone,
    );
  }
}

class ToggleReactionUseCase {
  final ChatRepository repository;
  const ToggleReactionUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String threadId,
    required String messageId,
    required String uid,
    required String emoji,
  }) {
    return repository.toggleReaction(
        threadId: threadId, messageId: messageId, uid: uid, emoji: emoji);
  }
}

class SetPinnedMessageUseCase {
  final ChatRepository repository;
  const SetPinnedMessageUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String threadId,
    required String messageId,
    required bool pinned,
  }) {
    return repository.setPinned(
        threadId: threadId, messageId: messageId, pinned: pinned);
  }
}

class SetTypingUseCase {
  final ChatRepository repository;
  const SetTypingUseCase(this.repository);

  Future<void> call(
      {required String threadId, required String uid, required bool isTyping}) {
    return repository.setTyping(
        threadId: threadId, uid: uid, isTyping: isTyping);
  }
}

class WatchTypingUseCase {
  final ChatRepository repository;
  const WatchTypingUseCase(this.repository);

  Stream<List<String>> call(String threadId) =>
      repository.watchTyping(threadId);
}

class WatchPresenceUseCase {
  final ChatRepository repository;
  const WatchPresenceUseCase(this.repository);

  Stream<UserPresence> call(String uid) => repository.watchPresence(uid);
}

class SetPresenceUseCase {
  final ChatRepository repository;
  const SetPresenceUseCase(this.repository);

  Future<void> call({required String uid, required bool isOnline}) {
    return repository.setPresence(uid: uid, isOnline: isOnline);
  }
}
