import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../models/app_notification_model.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<AppNotificationModel>> watchNotifications(String uid);
  Stream<int> watchUnreadCount(String uid);
  Future<void> create(AppNotificationModel notification);
  Future<void> markRead(String notificationId);
  Future<void> markAllRead(String uid);
  Future<void> delete(String notificationId);
  Future<void> deleteAll(String uid);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final SupabaseClient client;
  NotificationRemoteDataSourceImpl(this.client);
  AppNotificationModel map(Map<String, dynamic> r) =>
      AppNotificationModel.fromMap(r['id'].toString(), r);
  @override
  Stream<List<AppNotificationModel>> watchNotifications(String uid) => client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('uid', uid)
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) =>
          rows.map((r) => map(Map<String, dynamic>.from(r))).toList());
  @override
  Stream<int> watchUnreadCount(String uid) => client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('uid', uid)
      .map((rows) => rows.where((r) => r['is_read'] == false).length);
  @override
  Future<void> create(AppNotificationModel n) async {
    try {
      // كانت هذه إدراجًا مباشرًا في جدول notifications، وسياسته تسمح فقط
      // بـuid=auth.uid() (إشعار نفسك) — بينما كل إشعارات التفاعل الحقيقية
      // (إعجاب، تعليق، رسالة) يكون مستقبلها طرفًا آخر غير الفاعل، فكانت
      // تفشل بصمت دائمًا (الفعل الأصلي — الإعجاب مثلًا — ينجح، لكن صاحبه
      // لا يُخطَر إطلاقًا). create_notification_for_user تفرض actor_uid
      // كالمتصل الحقيقي دائمًا (لا انتحال فاعل) وتقبل أي مستلم.
      await client.rpc('create_notification_for_user', params: {
        'p_uid': n.uid,
        'p_type': n.type.wire,
        'p_title': n.title,
        'p_body': n.body,
        'p_related_id': n.relatedId,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر إنشاء الإشعار: $e');
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('uid', client.auth.currentUser!.id);
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث الإشعار: $e');
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    if (client.auth.currentUser?.id != uid) return;
    try {
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('uid', uid)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث الإشعارات: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('uid', client.auth.currentUser!.id);
    } catch (e) {
      throw ServerException(message: 'تعذّر حذف الإشعار: $e');
    }
  }

  @override
  Future<void> deleteAll(String uid) async {
    if (client.auth.currentUser?.id != uid) return;
    try {
      await client.from('notifications').delete().eq('uid', uid);
    } catch (e) {
      throw ServerException(message: 'تعذّر حذف الإشعارات: $e');
    }
  }
}
