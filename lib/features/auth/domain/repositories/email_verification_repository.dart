import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class EmailVerificationRepository {
  /// يطلب من Cloud Function توليد كود مكوّن من 6 أرقام وإرساله
  /// لبريد المستخدم، وتخزين تجزئته في طبقة بيانات Supabase بصلاحية 10 دقائق.
  Future<Either<Failure, void>> sendVerificationCode(
      {required String uid, required String email});

  /// يتحقق من الكود المُدخَل عبر Cloud Function (التحقق يتم على
  /// الخادم وليس على العميل حتى لا يُكشف الكود المجزّأ).
  Future<Either<Failure, bool>> confirmVerificationCode(
      {required String uid, required String code});
}
