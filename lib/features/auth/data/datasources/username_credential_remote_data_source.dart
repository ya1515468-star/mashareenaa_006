import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../../../core/data/supabase_document_compat.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/username_credential_model.dart';

abstract class UsernameCredentialRemoteDataSource {
  Future<bool> isUsernameAvailable(String username);
  Future<UsernameCredentialModel> createUsernameAndPin({
    required String uid,
    required String username,
    required String pin,
  });
  Future<bool> verifyPin({required String uid, required String pin});
  Future<String?> resolveUidByUsername(String username);
}

/// يخزّن سجل اسم المستخدم في مجموعة [BackendCollections.usernames]
/// (المجموعة `users` المحجوزة مسبقًا لهذا الغرض بالضبط في
/// app_constants.dart) بمعرّف مستند = اسم المستخدم نفسه (بأحرف صغيرة)
/// لضمان التفرّد ذريًا عبر طبقة بيانات Supabase transaction، ويُخزَّن تجزئة PIN
/// + الملح داخل نفس المستند تحت مفتاح فرعي لا يُقرأ إلا من صاحبه.
class UsernameCredentialRemoteDataSourceImpl
    implements UsernameCredentialRemoteDataSource {
  final SupabaseFunctionsCompat functions;

  UsernameCredentialRemoteDataSourceImpl(this.functions);

  @override
  Future<bool> isUsernameAvailable(String username) async {
    // الفحص يجري أثناء إنشاء الحساب، أي قبل تسجيل الدخول. username_credential_action
    // لا يستدعيها الزائر غير المسجّل (وهذا مقصود: فيها إنشاء الاسم والتحقق من PIN)،
    // فكان الفحص يفشل دائمًا ويُظهر "اسم مستخدم غير صالح". is_name_available متاحة
    // للزائر وتُرجع نعم/لا فقط بلا أي بيانات عن الحسابات.
    try {
      final result = await Supabase.instance.client.rpc('is_name_available',
          params: {'p_name': username, 'p_kind': 'username'});
      return result == true;
    } catch (e) {
      throw ServerException(message: 'تعذّر التحقق من توفر اسم المستخدم: $e');
    }
  }

  @override
  Future<UsernameCredentialModel> createUsernameAndPin({
    required String uid,
    required String username,
    required String pin,
  }) async {
    try {
      final callable = functions.httpsCallable('usernameCredentialAction');
      final result = await callable.call({
        'action': 'create',
        'username': username,
        'pin': pin,
        'requestId': const Uuid().v4(),
      });
      final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
      final normalized =
          data['username'] as String? ?? username.trim().toLowerCase();
      final createdAt = DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now();
      return UsernameCredentialModel(
          uid: uid, username: normalized, createdAt: createdAt);
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'تعذّر إنشاء اسم المستخدم ورمز PIN',
          code: e.code);
    } catch (e) {
      throw ServerException(message: 'تعذّر إنشاء اسم المستخدم ورمز PIN: $e');
    }
  }

  @override
  Future<bool> verifyPin({required String uid, required String pin}) async {
    try {
      final callable = functions.httpsCallable('usernameCredentialAction');
      final result = await callable.call({
        'action': 'verifyPin',
        'pin': pin,
        'requestId': const Uuid().v4(),
      });
      return (result.data as Map?)?['verified'] == true;
    } on SupabaseFunctionException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'resource-exhausted') {
        return false;
      }
      throw ServerException(
          message: e.message ?? 'تعذّر التحقق من رمز PIN', code: e.code);
    } catch (e) {
      throw ServerException(message: 'تعذّر التحقق من رمز PIN: $e');
    }
  }

  @override
  Future<String?> resolveUidByUsername(String username) async {
    try {
      final callable = functions.httpsCallable('usernameCredentialAction');
      final result = await callable.call({
        'action': 'resolveUid',
        'username': username,
        'requestId': const Uuid().v4(),
      });
      return (result.data as Map?)?['uid'] as String?;
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'تعذّر البحث عن اسم المستخدم: ${e.code}',
          code: e.code);
    } catch (e) {
      throw ServerException(message: 'تعذّر البحث عن اسم المستخدم: $e');
    }
  }
}
