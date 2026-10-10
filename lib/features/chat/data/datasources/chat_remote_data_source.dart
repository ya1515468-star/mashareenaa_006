import 'dart:async';
import '../../domain/repositories/chat_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/resilient_realtime_channel.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';

abstract class ChatRemoteDataSource {
  Stream<List<ChatThreadModel>> watchThreads(String uid);
  Stream<List<ChatMessageModel>> watchMessages(String threadId);
  Future<void> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
    required MessageType type,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDurationSeconds,
    String? replyToId,
    String? replyToPreview,
    String? replyToSenderUid,
    Map<String, dynamic>? metadata,
  });
  Future<void> markThreadRead({required String threadId, required String uid});
  Future<void> editMessage(
      {required String threadId,
      required String messageId,
      required String newText});
  Future<void> deleteMessage(
      {required String threadId,
      required String messageId,
      required String requesterUid,
      required bool forEveryone});
  Future<void> toggleReaction(
      {required String threadId,
      required String messageId,
      required String uid,
      required String emoji});
  Future<void> setPinned(
      {required String threadId,
      required String messageId,
      required bool pinned});
  Future<void> markDelivered(
      {required String threadId, required List<String> messageIds});
  Future<void> setTyping(
      {required String threadId, required String uid, required bool isTyping});
  Stream<List<String>> watchTyping(String threadId);
  Future<void> publishTypingRealtime({required String threadId, required String uid, required bool isTyping});
  Stream<List<String>> watchTypingRealtime(String threadId);
  Stream<UserPresence> watchPresence(String uid);
  Future<void> setPresence({required String uid, required bool isOnline});
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient supabase;
  // كانت قنوات typing/الرسائل الخاصة .subscribe() بلا أي معالجة لحالتها،
  // فتنقطع الكتابة أو تنبيه الرسالة الواردة بصمت عند أي channelError/
  // timedOut ولا تعود تعمل أبدًا حتى يُعاد فتح الشاشة بالكامل. الآن مُغلَّفة
  // بـResilientRealtimeChannel لتُعيد الاشتراك تلقائيًا — تنفيذ "اتصال دائم
  // لحظي لاينقطع" على مستوى طبقة البيانات لا الواجهة فقط.
  final Map<String, ResilientRealtimeChannel> _typingChannels =
      <String, ResilientRealtimeChannel>{};

  ChatRemoteDataSourceImpl(this.supabase);

  @override
  Stream<List<ChatThreadModel>> watchThreads(String uid) {
    return supabase.from('chat_threads').stream(primaryKey: ['id']).map(
        (rows) => rows
            .map((row) => ChatThreadModel.fromMap(
                  row['id'].toString(),
                  Map<String, dynamic>.from(row),
                ))
            .where((thread) => thread.participantUids.contains(uid))
            .toList()
          ..sort((a, b) => (b.lastMessageAt ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                  a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))));
  }

  @override
  Stream<List<ChatMessageModel>> watchMessages(String threadId) {
    final controller = StreamController<List<ChatMessageModel>>.broadcast();
    final byId = <String, ChatMessageModel>{};
    StreamSubscription? dbSub;
    Timer? expiryTimer;

    void emit() {
      final now = DateTime.now().toUtc();
      final rows = byId.values.where((message) {
        final raw = message.metadata?['self_destruct_expires_at'];
        if (raw == null) return true;
        final expiry = DateTime.tryParse(raw.toString());
        return expiry == null || expiry.isAfter(now);
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(rows.take(200).toList(growable: false));
    }

    // الإخفاء المحلي للرسائل المنتهية يبقى كل ثانية (emit). أما التنظيف على
    // الخادم فكان يُستدعى كل ثانية لكل محادثة مفتوحة (48 ألف استدعاء) بلا
    // حاجة، إذ الشاشة تُخفي المنتهي محليًا أصلًا. صار كل 60 ثانية.
    var tick = 0;
    expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (tick++ % 60 == 0) {
        try {
          await supabase.rpc('cleanup_expired_self_destruct_messages');
        } catch (_) {
          // Cleanup is best-effort; the renderer still hides expired messages locally.
        }
      }
      emit();
    });

    dbSub = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(200)
        .listen((rows) {
          byId
            ..clear()
            ..addEntries(rows.map((row) {
              final id = row['id'].toString();
              return MapEntry(
                id,
                ChatMessageModel.fromMap(
                  id,
                  threadId,
                  Map<String, dynamic>.from(row),
                ),
              );
            }));
          emit();
        }, onError: controller.addError);

    final channelRes = ResilientRealtimeChannel(
      client: supabase,
      build: (client) => client.channel(
        'dm:$threadId:messages',
        opts: const RealtimeChannelConfig(private: true),
      )..onBroadcast(event: 'message', callback: (payload) {
          final record = payload['record'];
          if (record is! Map) return;
          final map = Map<String, dynamic>.from(record);
          final id = map['id']?.toString();
          if (id == null || id.isEmpty) return;
          final op = payload['op']?.toString() ?? 'INSERT';
          if (op == 'DELETE') {
            byId.remove(id);
          } else {
            byId[id] = ChatMessageModel.fromMap(id, threadId, map);
          }
          emit();
        }),
    );

    controller.onCancel = () async {
      expiryTimer?.cancel();
      await dbSub?.cancel();
      await channelRes.dispose();
      await _typingChannels.remove(threadId)?.dispose();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
    required MessageType type,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDurationSeconds,
    String? replyToId,
    String? replyToPreview,
    String? replyToSenderUid,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await supabase.rpc(
        'send_chat_message',
        params: {
          'p_to_uid': toUid,
          'p_text': text,
          'p_type': type.wire,
          'p_media_url': mediaUrl,
          'p_thumbnail_url': thumbnailUrl,
          'p_media_duration_seconds': mediaDurationSeconds,
          'p_reply_to_id': replyToId,
          'p_reply_to_preview': replyToPreview,
          'p_reply_to_sender_uid': replyToSenderUid,
          'p_metadata': metadata,
        },
      );
      if (response is! Map) {
        throw const PostgrestException(message: 'EMPTY_RPC_RESPONSE');
      }
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'تعذّر إرسال الرسالة: $e');
    }
  }

  String _chatError(PostgrestException e) {
    switch (e.message) {
      case 'AUTH_REQUIRED':
        return 'انتهت جلسة الدخول، سجّل الدخول مرة أخرى.';
      case 'INVALID_PARTICIPANT':
        return 'المستلم غير صالح.';
      case 'EMPTY_MESSAGE':
        return 'لا يمكن إرسال رسالة فارغة.';
      case 'FORBIDDEN':
        return 'لا تملك صلاحية تنفيذ هذه العملية.';
      case 'DAILY_LIMIT_REACHED':
        return 'انتهى الحد اليومي للرد ثلاثي الأبعاد.';
      case 'FEATURE_DISABLED':
        return 'ميزة الرد ثلاثي الأبعاد غير مفعلة حاليًا.';
      default:
        return e.message.isNotEmpty ? e.message : 'حدث خطأ في خادم الشات.';
    }
  }

  @override
  Future<void> markThreadRead(
      {required String threadId, required String uid}) async {
    try {
      await supabase
          .rpc('mark_chat_thread_read', params: {'p_thread_id': threadId});
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> editMessage(
      {required String threadId,
      required String messageId,
      required String newText}) async {
    try {
      await supabase.rpc('edit_chat_message', params: {
        'p_thread_id': threadId,
        'p_message_id': messageId,
        'p_new_text': newText,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> deleteMessage(
      {required String threadId,
      required String messageId,
      required String requesterUid,
      required bool forEveryone}) async {
    try {
      await supabase.rpc('delete_chat_message', params: {
        'p_thread_id': threadId,
        'p_message_id': messageId,
        'p_for_everyone': forEveryone,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> toggleReaction(
      {required String threadId,
      required String messageId,
      required String uid,
      required String emoji}) async {
    try {
      await supabase.rpc('toggle_chat_reaction', params: {
        'p_thread_id': threadId,
        'p_message_id': messageId,
        'p_emoji': emoji,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> setPinned(
      {required String threadId,
      required String messageId,
      required bool pinned}) async {
    try {
      await supabase.rpc('set_chat_pinned', params: {
        'p_thread_id': threadId,
        'p_message_id': messageId,
        'p_pinned': pinned,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> markDelivered(
      {required String threadId, required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;
    try {
      await supabase.rpc('mark_chat_delivered', params: {
        'p_thread_id': threadId,
        'p_message_ids': messageIds,
      });
    } catch (_) {
      // Delivery is non-critical and must not block the chat UI.
    }
  }

  @override
  Future<void> setTyping(
      {required String threadId,
      required String uid,
      required bool isTyping}) async {
    try {
      // Authoritative durable state in Postgres.
      await supabase.rpc('set_chat_typing', params: {
        'p_thread_id': threadId,
        'p_is_typing': isTyping,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: _chatError(e), code: e.code);
    }
  }

  @override
  Future<void> publishTypingRealtime({
    required String threadId,
    required String uid,
    required bool isTyping,
  }) async {
    final res = _typingChannels[threadId] ??= ResilientRealtimeChannel(
      client: supabase,
      build: (client) => client.channel(
        'chat:thread:$threadId',
        opts: const RealtimeChannelConfig(private: true),
      ),
    );
    final channel = res.channel;
    if (channel == null) return; // بين محاولتي إعادة اشتراك — سترسل النبضة التالية.
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: <String, dynamic>{
        'thread_id': threadId,
        'user_id': uid,
        'is_typing': isTyping,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Stream<List<String>> watchTypingRealtime(String threadId) {
    final controller = StreamController<List<String>>.broadcast();
    final state = <String, DateTime>{};
    // أي قناة سابقة مخزَّنة لهذا threadId (أنشأتها publishTypingRealtime
    // مثلًا) يجب التخلص منها قبل استبدالها، لا تركها مشتركة ومنسية.
    unawaited(_typingChannels.remove(threadId)?.dispose());
    final res = ResilientRealtimeChannel(
      client: supabase,
      build: (client) => client.channel(
        'chat:thread:$threadId',
        opts: const RealtimeChannelConfig(private: true),
      )..onBroadcast(
          event: 'typing',
          callback: (payload) {
            final uid = payload['user_id']?.toString();
            if (uid == null || uid.isEmpty) return;
            final isTyping = payload['is_typing'] == true;
            final now = DateTime.now().toUtc();
            if (isTyping) {
              state[uid] = now;
            } else {
              state.remove(uid);
            }
            state.removeWhere((_, at) => now.difference(at).inMilliseconds > 4200);
            controller.add(state.keys.toList(growable: false));
          },
        ),
    );
    _typingChannels[threadId] = res;
    controller.onCancel = () async {
      await res.dispose();
      _typingChannels.remove(threadId);
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<List<String>> watchTyping(String threadId) {
    return supabase
        .from('chat_typing')
        .stream(primaryKey: ['thread_id', 'user_id'])
        .eq('thread_id', threadId)
        .map((rows) {
          final cutoff =
              DateTime.now().toUtc().subtract(const Duration(seconds: 4));
          return rows
              .where((row) {
                if (row['is_typing'] != true) return false;
                final raw = row['updated_at'];
                final updated = raw is DateTime
                    ? raw.toUtc()
                    : DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
                return updated != null && updated.isAfter(cutoff);
              })
              .map((row) => row['user_id']?.toString())
              .whereType<String>()
              .toList(growable: false);
        });
  }

  @override
  Stream<UserPresence> watchPresence(String uid) {
    return supabase
        .from('user_presence')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) {
          if (rows.isEmpty) return const UserPresence(isOnline: false);
          final row = rows.first;
          final seen = _parseDate(row['last_seen']);
          // "متصل" فقط إن كانت النبضة حديثة (الخادم ينهي الجلسات العالقة كل دقيقة).
          final fresh = seen != null &&
              DateTime.now().toUtc().difference(seen.toUtc()).inSeconds <= 120;
          return UserPresence(
            isOnline: row['is_online'] == true && fresh,
            lastSeen: seen,
          );
        });
  }

  @override
  Future<void> setPresence(
      {required String uid, required bool isOnline}) async {
    try {
      await supabase.rpc('set_my_presence', params: {'p_is_online': isOnline});
    } catch (_) {
      // Presence is intentionally best-effort.
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
