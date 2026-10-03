import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../../../social_graph/domain/repositories/social_graph_repository.dart';
import '../repositories/chat_repository.dart';
import '../entities/chat_message_entity.dart';
import '../entities/chat_thread_entity.dart';

class SendMessageParams extends Equatable {
  final String fromUid;
  final String toUid;
  final String text;
  final MessageType type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? mediaDurationSeconds;
  final String? replyToId;
  final String? replyToPreview;
  final String? replyToSenderUid;
  final Map<String, dynamic>? metadata;

  const SendMessageParams({
    required this.fromUid,
    required this.toUid,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaDurationSeconds,
    this.replyToId,
    this.replyToPreview,
    this.replyToSenderUid,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        fromUid,
        toUid,
        text,
        type,
        mediaUrl,
        thumbnailUrl,
        mediaDurationSeconds,
        replyToId,
        replyToPreview,
        replyToSenderUid,
        metadata,
      ];
}

/// يرسل الرسالة بعد التحقق من عدم وجود حظر بين الطرفين بأي اتجاه،
/// ثم ينشئ إشعارًا للمستقبل — ربط حقيقي بين ثلاث وحدات: Chat،
/// SocialGraph (الحظر)، وNotifications.
class SendMessageUseCase {
  final ChatRepository chatRepository;
  final NotificationRepository notificationRepository;
  final SocialGraphRepository socialGraphRepository;

  const SendMessageUseCase({
    required this.chatRepository,
    required this.notificationRepository,
    required this.socialGraphRepository,
  });

  Future<Either<Failure, void>> call(SendMessageParams params) async {
    if (params.text.trim().isEmpty && params.mediaUrl == null) {
      return const Left(
          ValidationFailure(message: 'لا يمكن إرسال رسالة فارغة'));
    }
    if (params.fromUid == params.toUid) {
      return const Left(ValidationFailure(message: 'لا يمكن مراسلة نفسك'));
    }

    final blockResult = await socialGraphRepository.hasBlockEitherDirection(
      uidA: params.fromUid,
      uidB: params.toUid,
    );
    final blocked = blockResult.getOrElse(() => false);
    if (blocked) {
      return const Left(PermissionFailure(
          message: 'لا يمكن إرسال رسالة بسبب وجود حظر بين الطرفين'));
    }

    final sendResult = await chatRepository.sendMessage(
      fromUid: params.fromUid,
      toUid: params.toUid,
      text: params.text.trim(),
      type: params.type,
      mediaUrl: params.mediaUrl,
      thumbnailUrl: params.thumbnailUrl,
      mediaDurationSeconds: params.mediaDurationSeconds,
      replyToId: params.replyToId,
      replyToPreview: params.replyToPreview,
      replyToSenderUid: params.replyToSenderUid,
      metadata: params.metadata,
    );

    if (sendResult.isRight()) {
      await notificationRepository.create(
        AppNotificationEntity(
          id: '',
          uid: params.toUid,
          type: AppNotificationType.message,
          title: 'رسالة جديدة',
          body: params.text.trim().isEmpty ? '📎 مرفق' : params.text.trim(),
          relatedId: ChatThreadEntity.buildId(params.fromUid, params.toUid),
          actorUid: params.fromUid,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    return sendResult;
  }
}
