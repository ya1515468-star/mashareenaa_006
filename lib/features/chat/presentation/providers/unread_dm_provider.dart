import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/resilient_realtime_channel.dart';

/// عدّاد أيقونة «رسالة» في الشريط العلوي. كان يُحسب من إشعارات نوع message
/// غير المقروءة — والرسائل الخاصة لم تعد إشعارات (مثل شات أحلى لمة: لها
/// أيقونتها الخاصة فقط)، وكان يعدّ الهدايا أيضًا كرسائل. المصدر الآن
/// المحادثات نفسها (chat_threads.unread_counts) عبر get_my_unread_dm_count،
/// ويُعاد حسابه فور أي تغيير لحظي على المحادثات.
final unreadDmCountProvider = StreamProvider.autoDispose<int>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<int>();

  Future<void> refresh() async {
    try {
      final v = await client.rpc('get_my_unread_dm_count');
      if (!controller.isClosed) controller.add((v as num?)?.toInt() ?? 0);
    } catch (_) {
      if (!controller.isClosed) controller.add(0);
    }
  }

  final channelRes = ResilientRealtimeChannel(
    client: client,
    build: (c) => c
        .channel('my_dm_unread_${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_threads',
          callback: (_) => unawaited(refresh()),
        ),
  );

  unawaited(refresh());

  ref.onDispose(() {
    unawaited(channelRes.dispose());
    controller.close();
  });
  return controller.stream;
});
