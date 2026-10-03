import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/broadcast_entity.dart';

abstract class BroadcastRepository {
  /// DRAGON فقط (يُتحقَّق من صلاحية broadcast_messages) — يبث رسالة
  /// نصية لكل المستخدمين، تظهر كشريط متحرك (Banner) أعلى أي شاشة
  /// مفتوحة فورًا، وتظهر أيضًا لمن يفتح التطبيق لاحقًا مرة واحدة.
  Future<Either<Failure, void>> sendBroadcast(
      {required String message, required String sentByUid});

  /// آخر رسالة بث نشطة — تُستهلك من [BroadcastListener] في كل من
  /// الجلسة الحيّة (real-time) وعند فتح التطبيق (نداء لمرة واحدة).
  Stream<BroadcastEntity?> watchLatestBroadcast();
}
