import '../../../../core/config/auth_redirect.dart';
import 'dart:async';

import '../../../../core/services/security_risk_probe.dart';
import '../../../../core/services/geo_location_service.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> resendSignupConfirmationEmail(String email);

  Stream<UserModel?> get authStateChanges;

  Future<UserModel?> getCurrentUser();

  Future<AccountStatus> getAccountStatus(String uid);

  /// يرسل تأكيدًا للبريد الجديد (Supabase يتطلب فتح رابط التأكيد
  /// قبل أن يصبح ساري المفعول فعليًا — نفس آلية Confirm Email).
  Future<void> updateEmail(String newEmail);

  /// يغيّر كلمة المرور للمستخدم الحالي (يتطلب أن تكون الجلسة سارية
  /// بالفعل، أي أن المستخدم مسجّل دخوله).
  Future<void> updatePassword(String newPassword);

  /// يربط حساب Google بالحساب الحالي عبر Supabase Identity Linking —
  /// يفتح متصفح OAuth ويعيد التحكم بعد الربط.
  Future<void> linkGoogleIdentity();

  /// يسجّل طلب حذف الحساب (soft-delete request) بدل حذف فوري لا
  /// رجعة فيه من طرف العميل — يمنح فريق الدعم فرصة مراجعة الطلب،
  /// وهو النمط المتّبع فعليًا في أغلب المنصات.
  Future<void> requestAccountDeletion(String uid);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final sb.SupabaseClient supabase;

  static const FlutterSecureStorage _securityStorage = FlutterSecureStorage();

  static const String _deviceIdKey = 'mashareena_security_device_id';

  static const String _sessionIdKey = 'mashareena_security_session_id';

  static const Uuid _uuid = Uuid();

  AuthRemoteDataSourceImpl(this.supabase);

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _securityStorage.read(key: _deviceIdKey);

    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _uuid.v4();

    await _securityStorage.write(
      key: _deviceIdKey,
      value: generated,
    );

    return generated;
  }

  Future<String> _createSessionId() async {
    final generated = _uuid.v4();

    await _securityStorage.write(
      key: _sessionIdKey,
      value: generated,
    );

    return generated;
  }

  Future<String?> _getSessionId() async {
    final value = await _securityStorage.read(
      key: _sessionIdKey,
    );

    return value?.trim().isEmpty == true ? null : value?.trim();
  }

  Future<String> _sha256(String value) async {
    return sha256.convert(utf8.encode(value.trim())).toString();
  }

  Future<void> _syncSecuritySession() async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final sessionId = await _getSessionId() ?? await _createSessionId();
      final deviceIdHash = await _sha256(deviceId);
      final sessionIdHash = await _sha256(sessionId);

      await supabase.rpc(
        'update_security_session',
        params: {
          'p_device_id_hash': deviceIdHash,
          'p_session_id_hash': sessionIdHash,
        },
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Security telemetry is best-effort and must never block authentication.
    }
  }

  Future<void> _clearSecuritySession() async {
    await _securityStorage.delete(
      key: _sessionIdKey,
    );
  }

  Future<void> _enforceSecurityState() async {
    try {
      final response = await supabase
          .rpc('get_my_security_state')
          .timeout(const Duration(seconds: 4));

      if (response == null) {
        return;
      }

      final state = Map<String, dynamic>.from(response as Map);

      if (state['blocked'] != true) {
        return;
      }

      final type = state['penalty_type']?.toString();
      final reason = state['reason']?.toString().trim();
      final expiresAt = state['expires_at']?.toString();

      final typeText = switch (type) {
        'ban' => 'تم حظرك من الوصول.',
        'kick' => 'تم طردك مؤقتًا.',
        'bury' => 'تم عزلك إلى المقبرة.',
        _ => 'تم تقييد وصولك إلى المنصة.',
      };

      final reasonText =
          reason != null && reason.isNotEmpty ? '\nالسبب: $reason' : '';

      final expiryText = type == 'bury' || expiresAt == null || expiresAt.isEmpty
          ? ''
          : '\nينتهي في: $expiresAt';

      await supabase.auth.signOut();
      await _clearSecuritySession();

      throw AuthException(
        message: '$typeText$reasonText$expiryText',
        code: 'SECURITY_BLOCKED',
      );
    } on AuthException {
      rethrow;
    } on sb.PostgrestException {
      // Security-state lookup is an auxiliary gate. A transient transport/RPC
      // failure must not invalidate a valid Supabase Auth session.
    } on TimeoutException {
      // Never let a secondary security probe make a valid Auth session look
      // like a failed login because of network latency.
    } catch (_) {
      // Same fail-open behavior for availability; explicit blocked state above
      // remains fail-closed.
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        // بدونه يحوّل رابط التأكيد إلى Site URL الافتراضي (localhost).
        emailRedirectTo: authRedirectUrl(),
        data: {
          'display_name': displayName.trim().isEmpty
              ? email.split('@').first.trim()
              : displayName.trim(),
        },
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException(
          message: 'تعذّر إنشاء الحساب',
        );
      }

      final status = await getAccountStatus(user.id);
      await _syncSecuritySession();

      // Security telemetry is best-effort and must never block a successful
      // authentication. The authorization state itself is still checked
      // server-side, but with a bounded timeout so login cannot hang.
      unawaited(SecurityRiskProbe.run());
      await _enforceSecurityState();

      return UserModel.fromSupabaseUser(
        user,
        status: status,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthError(e),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'تعذّر إنشاء الحساب: $e',
      );
    }
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;

      if (user == null || response.session == null) {
        throw const AuthException(
          message: 'تعذّر تسجيل الدخول',
        );
      }

      final status = await getAccountStatus(user.id);
      await _syncSecuritySession();

      if (status != AccountStatus.active) {
        await supabase.auth.signOut();

        throw AuthException(
          message: _accountStatusMessage(status),
          code: 'ACCOUNT_NOT_ACTIVE',
        );
      }

      // Security telemetry is best-effort and must never block a successful
      // authentication. The authorization state itself is still checked
      // server-side, but with a bounded timeout so login cannot hang.
      unawaited(SecurityRiskProbe.run());
      await _enforceSecurityState();

      return UserModel.fromSupabaseUser(
        user,
        status: status,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthError(e),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'تعذّر تسجيل الدخول: $e',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      await _clearSecuritySession();
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        message: 'تعذّر تسجيل الخروج: $e',
      );
    }
  }

  @override
  Future<void> resendSignupConfirmationEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        message: 'أدخل البريد الإلكتروني أولًا',
        code: 'INVALID_EMAIL',
      );
    }

    try {
      await supabase.auth.resend(
        type: sb.OtpType.signup,
        email: normalizedEmail,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        message: 'تعذّر إعادة إرسال رسالة تأكيد البريد: $e',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthError(e),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        message: 'تعذّر إرسال رابط إعادة تعيين كلمة المرور: $e',
      );
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return supabase.auth.onAuthStateChange.asyncMap(
      (data) async {
        final user = data.session?.user;

        if (user == null) {
          return null;
        }

        final status = await getAccountStatus(user.id);

        if (status != AccountStatus.active) {
          await supabase.auth.signOut();
          return null;
        }

        // استنتاج الموقع (دولة/مدينة) تلقائيًا من IP. متروك بلا await
        // عمدًا: لا يجوز أن يؤخّر تدفّق المصادقة أو يُفشله إن تعذّر
        // الوصول لمزوّد GeoIP — الخدمة نفسها تبتلع كل أخطائها وتحدّ
        // نفسها بمحاولة واحدة كل 7 أيام.
        unawaited(GeoLocationService.resolveIfNeeded());

        return UserModel.fromSupabaseUser(
          user,
          status: status,
        );
      },
    );
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final status = await getAccountStatus(user.id);

      if (status != AccountStatus.active) {
        await supabase.auth.signOut();
        return null;
      }

      return UserModel.fromSupabaseUser(
        user,
        status: status,
      );
    } catch (e) {
      throw AuthException(
        message: 'تعذّر جلب المستخدم الحالي: $e',
      );
    }
  }

  @override
  Future<AccountStatus> getAccountStatus(String uid) async {
    try {
      final row = await supabase
          .from('profiles')
          .select('is_active, is_suspended')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (row == null) {
        return AccountStatus.active;
      }

      final isActive = row['is_active'] == true;
      final isSuspended = row['is_suspended'] == true;

      if (isSuspended) {
        return AccountStatus.suspended;
      }

      if (!isActive) {
        return AccountStatus.banned;
      }

      return AccountStatus.active;
    } on sb.PostgrestException {
      return AccountStatus.active;
    } catch (_) {
      return AccountStatus.active;
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    try {
      await supabase.auth.updateUser(sb.UserAttributes(email: newEmail));
    } on sb.AuthException catch (e) {
      throw AuthException(message: _mapAuthError(e), code: e.code);
    } catch (e) {
      throw AuthException(message: 'تعذّر تحديث البريد الإلكتروني: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw AuthException(message: _mapAuthError(e), code: e.code);
    } catch (e) {
      throw AuthException(message: 'تعذّر تحديث كلمة المرور: $e');
    }
  }

  @override
  Future<void> linkGoogleIdentity() async {
    try {
      await supabase.auth.linkIdentity(sb.OAuthProvider.google);
    } on sb.AuthException catch (e) {
      throw AuthException(message: _mapAuthError(e), code: e.code);
    } catch (e) {
      throw AuthException(message: 'تعذّر ربط حساب Google: $e');
    }
  }

  @override
  Future<void> requestAccountDeletion(String uid) async {
    try {
      await SupabaseDocumentStore.instance
          .collection(BackendCollections.accounts)
          .doc(uid)
          .set({
        'deletionRequested': true,
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      }, const SetOptions(merge: true));
    } catch (e) {
      throw AuthException(message: 'تعذّر تسجيل طلب حذف العضوية: $e');
    }
  }

  String _mapAuthError(sb.AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();

    if (code.contains('user_already_exists') ||
        code.contains('email_exists') ||
        message.contains('already registered')) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل';
    }

    if (code.contains('invalid') && message.contains('email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (code.contains('email_not_confirmed') ||
        message.contains('email not confirmed') ||
        message.contains('email_not_confirmed')) {
      return 'يجب تأكيد البريد الإلكتروني أولًا';
    }

    if (code.contains('weak_password')) {
      return 'كلمة المرور لا تستوفي متطلبات Supabase الحالية';
    }

    if (code.contains('user_not_found')) {
      return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني';
    }

    if (code.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'كلمة المرور أو البريد الإلكتروني غير صحيح';
    }

    if (code.contains('too_many_requests') || message.contains('rate limit')) {
      return 'محاولات كثيرة جدًا، حاول لاحقًا';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        code.contains('unexpected_failure')) {
      return 'تعذّر الاتصال بخادم المصادقة؛ تحقق من الإنترنت ثم أعد المحاولة';
    }

    return e.message.isNotEmpty ? e.message : 'حدث خطأ أثناء المصادقة';
  }

  String _accountStatusMessage(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return 'الحساب نشط';
      case AccountStatus.suspended:
        return 'تم تعليق هذا الحساب';
      case AccountStatus.banned:
        return 'تم حظر هذا الحساب';
      case AccountStatus.deleted:
        return 'تم حذف هذا الحساب';
    }
  }
}
