import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ChatThreadEntity>> watchThreads(String uid) =>
      remoteDataSource.watchThreads(uid);

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String threadId) =>
      remoteDataSource.watchMessages(threadId);

  @override
  Future<Either<Failure, void>> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDurationSeconds,
    String? replyToId,
    String? replyToPreview,
    String? replyToSenderUid,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await remoteDataSource.sendMessage(
        fromUid: fromUid,
        toUid: toUid,
        text: text,
        type: type,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        mediaDurationSeconds: mediaDurationSeconds,
        replyToId: replyToId,
        replyToPreview: replyToPreview,
        replyToSenderUid: replyToSenderUid,
        metadata: metadata,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markThreadRead(
      {required String threadId, required String uid}) async {
    try {
      await remoteDataSource.markThreadRead(threadId: threadId, uid: uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> editMessage({
    required String threadId,
    required String messageId,
    required String newText,
  }) async {
    try {
      await remoteDataSource.editMessage(
          threadId: threadId, messageId: messageId, newText: newText);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessage({
    required String threadId,
    required String messageId,
    required String requesterUid,
    required bool forEveryone,
  }) async {
    try {
      await remoteDataSource.deleteMessage(
        threadId: threadId,
        messageId: messageId,
        requesterUid: requesterUid,
        forEveryone: forEveryone,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleReaction({
    required String threadId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    try {
      await remoteDataSource.toggleReaction(
          threadId: threadId, messageId: messageId, uid: uid, emoji: emoji);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPinned({
    required String threadId,
    required String messageId,
    required bool pinned,
  }) async {
    try {
      await remoteDataSource.setPinned(
          threadId: threadId, messageId: messageId, pinned: pinned);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<void> setTyping(
      {required String threadId, required String uid, required bool isTyping}) {
    return remoteDataSource.setTyping(
        threadId: threadId, uid: uid, isTyping: isTyping);
  }

  @override
  Future<void> markDelivered(
      {required String threadId, required List<String> messageIds}) {
    return remoteDataSource.markDelivered(
        threadId: threadId, messageIds: messageIds);
  }

  @override
  Stream<List<String>> watchTyping(String threadId) =>
      remoteDataSource.watchTyping(threadId);

  @override
  Stream<UserPresence> watchPresence(String uid) =>
      remoteDataSource.watchPresence(uid);

  @override
  Future<void> setPresence({required String uid, required bool isOnline}) {
    return remoteDataSource.setPresence(uid: uid, isOnline: isOnline);
  }
}
