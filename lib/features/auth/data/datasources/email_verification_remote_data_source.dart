import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';

abstract class EmailVerificationRemoteDataSource {
  Future<void> sendVerificationCode(
      {required String uid, required String email});
  Future<bool> confirmVerificationCode(
      {required String uid, required String code});
}

/// يستدعي دالتي Cloud Functions المُعرَّفتين في functions/index.js:
/// sendVerificationCode و confirmVerificationCode. توليد الكود
/// وتخزين تجزئته والتحقق منه يحدث بالكامل على الخادم — العميل هنا
/// لا يرى أي كود أو تجزئة إطلاقًا، فقط ينادي الدالة وينتظر النتيجة.
class EmailVerificationRemoteDataSourceImpl
    implements EmailVerificationRemoteDataSource {
  final SupabaseFunctionsCompat functions;
  EmailVerificationRemoteDataSourceImpl(this.functions);

  @override
  Future<void> sendVerificationCode(
      {required String uid, required String email}) async {
    try {
      final callable = functions.httpsCallable('sendVerificationCode');
      await callable.call({'uid': uid, 'email': email});
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'تعذّر إرسال كود التأكيد', code: e.code);
    } catch (e) {
      throw ServerException(message: 'تعذّر إرسال كود التأكيد: $e');
    }
  }

  @override
  Future<bool> confirmVerificationCode(
      {required String uid, required String code}) async {
    try {
      final callable = functions.httpsCallable('confirmVerificationCode');
      final result = await callable.call({'uid': uid, 'code': code});
      return (result.data as Map)['verified'] == true;
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'كود التأكيد غير صحيح', code: e.code);
    } catch (e) {
      throw ServerException(message: 'تعذّر التحقق من الكود: $e');
    }
  }
}
