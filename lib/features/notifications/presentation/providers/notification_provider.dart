import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';

final notificationsProvider =
    StreamProvider<List<AppNotificationEntity>>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return sl<NotificationRepository>().watchNotifications(uid);
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(0);
  return sl<NotificationRepository>().watchUnreadCount(uid);
});

class NotificationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// كانت الدوال الأربع هنا جميعًا تستدعي طبقة تُعيد Either<Failure, void>
  /// ثم تتجاهل النتيجة كليًا بلا فحص — أي فشل (صلاحية، شبكة، أي سبب) كان
  /// يُبتلع بصمت تام، فلا يرى المستخدم أي أثر لا لنجاح ولا لفشل، وتبدو
  /// وكأن القراءة/الحذف "لا تُنفَّذ" رغم أن الاستدعاء نفسه تم فعليًا.
  /// الآن state يحمل الفشل الحقيقي كي تعرضه الواجهة، ويُعاد رمي الاستثناء
  /// أيضًا كي يفشل الوعد نفسه لمن ينتظره مباشرة.
  Future<void> markRead(String notificationId) async {
    final result = await sl<MarkNotificationReadUseCase>()(notificationId);
    result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      throw failure;
    }, (_) {});
  }

  Future<void> markAllRead(String uid) async {
    final result = await sl<NotificationRepository>().markAllRead(uid);
    result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      throw failure;
    }, (_) {});
  }

  // Supabase Realtime لا يرسل أحداث DELETE للاشتراكات المفلترة
  // (.eq('uid', …)) — قيد موثّق في Supabase. فكان الحذف ينجح فعلًا على
  // الخادم (الجدول يفرغ) بينما القائمة في التطبيق لا تعلم به أبدًا
  // وتبقى على نسختها القديمة: "تم الحذف وتبقى الإشعارات". إعادة
  // الاشتراك بعد الحذف تجلب الحالة الحقيقية من الخادم فورًا.
  void _refreshStreams() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<void> delete(String notificationId) async {
    final result = await sl<NotificationRepository>().delete(notificationId);
    result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      throw failure;
    }, (_) => _refreshStreams());
  }

  Future<void> deleteAll(String uid) async {
    final result = await sl<NotificationRepository>().deleteAll(uid);
    result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      throw failure;
    }, (_) => _refreshStreams());
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
        NotificationController.new);
