import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gamification/domain/repositories/gamification_repository.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_interaction_usecases.dart';
import '../../domain/usecases/mark_thread_read_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../data/datasources/chat_remote_data_source.dart';

final chatThreadsProvider = StreamProvider<List<ChatThreadEntity>>((ref) {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return sl<ChatRepository>().watchThreads(user.uid);
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageEntity>, String>((ref, threadId) {
  return sl<ChatRepository>().watchMessages(threadId);
});

/// uids الأعضاء الذين يكتبون حاليًا في هذه المحادثة (باستثناء
/// المستخدم الحالي نفسه — يُستبعد في الواجهة عند العرض).
final chatTypingProvider =
    StreamProvider.family<List<String>, String>((ref, threadId) {
  final durable = sl<WatchTypingUseCase>().call(threadId);
  final realtime = sl<ChatRemoteDataSource>().watchTypingRealtime(threadId);
  // Broadcast path is low-latency; durable DB stream reconciles truth.
  return _mergeTypingStreams(durable, realtime);
});

Stream<List<String>> _mergeTypingStreams(
  Stream<List<String>> durable,
  Stream<List<String>> realtime,
) {
  late final StreamController<List<String>> controller;

  StreamSubscription<List<String>>? durableSubscription;
  StreamSubscription<List<String>>? realtimeSubscription;
  bool disposed = false;

  Future<void> cancelSubscriptions() async {
    if (disposed) return;

    disposed = true;

    final subscriptions = <StreamSubscription<List<String>>>[
      if (durableSubscription != null) durableSubscription!,
      if (realtimeSubscription != null) realtimeSubscription!,
    ];

    durableSubscription = null;
    realtimeSubscription = null;

    for (final subscription in subscriptions) {
      try {
        await subscription.cancel();
      } catch (_) {
        // تجاهل أخطاء الإلغاء أثناء إغلاق المزود.
      }
    }
  }

  controller = StreamController<List<String>>.broadcast(
    onListen: () {
      if (disposed) return;

      durableSubscription ??= durable.listen(
        (value) {
          if (!disposed && !controller.isClosed) {
            controller.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!disposed && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

      realtimeSubscription ??= realtime.listen(
        (value) {
          if (!disposed && !controller.isClosed) {
            controller.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!disposed && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );
    },
    onCancel: () async {
      await cancelSubscriptions();

      if (!controller.isClosed) {
        await controller.close();
      }
    },
  );

  return controller.stream;
}

final userPresenceProvider =
    StreamProvider.family<UserPresence, String>((ref, uid) {
  return sl<WatchPresenceUseCase>().call(uid);
});

/// معرّف الرسالة التي يجري الرد عليها حاليًا في شاشة كتابة الرسالة
/// — حالة واجهة محلية بحتة (وليست في طبقة بيانات Supabase) لأنها تخص جهاز
/// المرسل فقط قبل الإرسال.
final replyingToProvider = StateProvider<ChatMessageEntity?>((ref) => null);
final replyingModeProvider = StateProvider<String>((ref) => 'reply');

class ChatController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDurationSeconds,
    ChatMessageEntity? replyTo,
    Map<String, dynamic>? metadata,
  }) async {
    final useCase = sl<SendMessageUseCase>();
    final result = await useCase(
      SendMessageParams(
        fromUid: fromUid,
        toUid: toUid,
        text: text,
        type: type,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        mediaDurationSeconds: mediaDurationSeconds,
        replyToId: replyTo?.id,
        replyToPreview: replyTo == null
            ? null
            : (replyTo.text.isEmpty ? '📎 مرفق' : replyTo.text),
        replyToSenderUid: replyTo?.senderUid,
        metadata: metadata,
      ),
    );
    if (result.isRight()) {
      lastSendError = null;
      sl<GamificationRepository>()
          .unlockBadge(uid: fromUid, badgeId: 'first_chat');
    } else {
      result.fold((f) => lastSendError = f.message, (_) {});
    }
    return result.isRight();
  }

  /// سبب آخر رفض للإرسال كما أرسله الخادم (كتم، خاص مقفل، حظر…). كان يُهمَل
  /// فيظهر للعضو "تعذّر الإرسال، حاول مرة أخرى" أيًّا كان السبب.
  String? lastSendError;

  Future<void> markRead({required String threadId, required String uid}) async {
    final useCase = sl<MarkThreadReadUseCase>();
    await useCase(threadId: threadId, uid: uid);
  }

  Future<bool> editMessage({
    required String threadId,
    required String messageId,
    required String newText,
  }) async {
    final result = await sl<EditMessageUseCase>().call(
      threadId: threadId,
      messageId: messageId,
      newText: newText,
    );
    return result.isRight();
  }

  Future<bool> deleteMessage({
    required String threadId,
    required String messageId,
    required String requesterUid,
    required bool forEveryone,
  }) async {
    final result = await sl<DeleteMessageUseCase>().call(
      threadId: threadId,
      messageId: messageId,
      requesterUid: requesterUid,
      forEveryone: forEveryone,
    );
    return result.isRight();
  }

  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    await sl<ToggleReactionUseCase>().call(
      threadId: threadId,
      messageId: messageId,
      uid: uid,
      emoji: emoji,
    );
  }

  Future<void> setPinned({
    required String threadId,
    required String messageId,
    required bool pinned,
  }) async {
    await sl<SetPinnedMessageUseCase>()
        .call(threadId: threadId, messageId: messageId, pinned: pinned);
  }

  Future<void> setTyping(
      {required String threadId,
      required String uid,
      required bool isTyping}) async {
    // Realtime Broadcast is the latency path; Postgres remains the durable source.
    final ds = sl<ChatRemoteDataSource>();
    unawaited(ds.publishTypingRealtime(
      threadId: threadId,
      uid: uid,
      isTyping: isTyping,
    ));

    // Durable persistence runs in parallel and never blocks keyboard feedback.
    final remote = sl<ChatRepository>();
    unawaited(remote
        .setTyping(
          threadId: threadId,
          uid: uid,
          isTyping: isTyping,
        )
        .catchError((_) {}));
  }

  Future<void> markDelivered(
      {required String threadId, required List<String> messageIds}) {
    return sl<ChatRepository>()
        .markDelivered(threadId: threadId, messageIds: messageIds);
  }
}

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, void>(ChatController.new);
