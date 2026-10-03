import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/profile_model.dart';
import '../../domain/entities/profile_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> createProfile({
    required String uid,
    required String displayName,
    required String email,
  });

  Future<ProfileModel> getProfile(String uid);

  Stream<ProfileModel> watchProfile(String uid);

  Future<ProfileModel> updateProfile(ProfileModel profile);

  Future<void> updateTypography({required String usernameFontFamily, required String messageFontFamily});

  Future<void> setVerified({
    required String uid,
    required bool verified,
  });
}

/// Supabase-only profile source of truth.
/// No legacy app_documents/public_profiles reads or writes are used here.
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient _sb = Supabase.instance.client;

  Map<String, dynamic> _mapPublicRow(Map<dynamic, dynamic> row) =>
      Map<String, dynamic>.from(row);

  ProfileModel _fromRpcRow(Map<String, dynamic> row) {
    final created =
        DateTime.tryParse('${row['created_at'] ?? ''}') ?? DateTime.now();
    final updated = DateTime.tryParse('${row['updated_at'] ?? ''}') ?? created;
    return ProfileModel.fromMap(row['id'].toString(), {
      'displayName': row['display_name']?.toString() ??
          row['username']?.toString() ??
          'عضو',
      'email': row['email']?.toString() ?? '',
      'bio': row['bio']?.toString() ?? '',
      'avatarUrl': _normalizeProfileAvatarUrl(row['avatar_url']?.toString()),
      'coverUrl': row['cover_url']?.toString(),
      'statusText': row['status_text']?.toString(),
      'profileMusicUrl': row['profile_music_url']?.toString(),
      'profileMusicDurationMs':
          (row['profile_music_duration_ms'] as num?)?.toInt(),
      'profileMusicSizeBytes':
          (row['profile_music_size_bytes'] as num?)?.toInt(),
      'country': row['country']?.toString(),
      'city': row['city']?.toString(),
      'profession': row['profession']?.toString(),
      'experiences':
          row['experiences'] is List ? row['experiences'] : const <dynamic>[],
      'socialLinks':
          row['social_links'] is List ? row['social_links'] : const <dynamic>[],
      'verified': row['verified'] == true,
      'visibility': row['visibility']?.toString(),
      'accountType': row['account_type']?.toString(),
      // نفس عطل message_color بالضبط (فحص is num صارم يفشل مع أعمدة bigint
      // التي تصل كنص عبر PostgREST) — كان يجب إصلاحه هنا في المرة السابقة.
      'usernameColor': int.tryParse(row['username_color']?.toString() ?? ''),
      'usernameFontSize': (row['username_font_size'] as num?)?.toDouble() ?? 12,
      'usernameFontFamily': row['username_font_family']?.toString() ?? '',
      'messageFontFamily': row['message_font_family']?.toString() ?? '',
      // كان يتحقق أن القيمة num حرفيًا، فيفشل دائمًا إن وصلت كنص (وهو
      // الشائع لأعمدة bigint عبر PostgREST) — يُعيد القيمة الافتراضية دومًا
      // بصرف النظر عمّا حُفظ فعليًا على الخادم. نفس الحقل المشابه
      // (usernameBackgroundColor) يُقرأ عبر toString() بأمان بلا هذا الفحص.
      'messageColor': int.tryParse(row['message_color']?.toString() ?? '') ?? 4294967295,
      'statusFontSize': (row['status_font_size'] as num?)?.toDouble() ?? 12.5,
      'statusBold': row['status_bold'] == true,
      'statusItalic': row['status_italic'] == true,
      'statusColor': int.tryParse(row['status_color']?.toString() ?? ''),
      'animatedAvatarUrl': _normalizeProfileAvatarUrl(row['animated_avatar_url']?.toString()),
      'avatarFrameKey': row['avatar_frame_key']?.toString(),
      'usernameTemplateKey': row['username_template_key']?.toString(),
      'usernameEffect': row['username_effect']?.toString() ?? 'none',
      'usernameBackgroundKey': row['username_background_key']?.toString(),
      'usernameBackgroundMode': row['username_background_mode']?.toString(),
      'usernameBackgroundColor1': row['username_background_color1']?.toString(),
      'usernameBackgroundColor2': row['username_background_color2']?.toString(),
      'usernameBackgroundOpacity': (row['username_background_opacity'] as num?)?.toDouble() ?? .82,
      'usernameBackgroundExternalEffect': row['username_background_external_effect']?.toString(),
      'createdAt': created,
      'updatedAt': updated,
    });
  }

  Future<Map<String, dynamic>?> _publicProfileRow(String uid) async {
    final raw = await _sb.rpc('get_public_profile_cosmetics', params: {'p_user_id': uid});
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return _mapPublicRow(raw.first as Map);
    }
    return null;
  }

  @override
  Future<ProfileModel> createProfile({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    try {
      if (_sb.auth.currentUser?.id != uid) {
        throw const ServerException(message: 'جلسة المستخدم غير صالحة');
      }
      await _sb.rpc('ensure_my_profile', params: {
        'p_display_name': displayName.trim().isEmpty ? 'عضو' : displayName.trim(),
        'p_email': email,
      });
      final row = await _publicProfileRow(uid);
      if (row == null) {
        throw const ServerException(message: 'لم يكتمل إنشاء الملف الشخصي. أعد المحاولة بعد تسجيل الدخول.');
      }
      return _fromRpcRow(row);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'لم يكتمل إنشاء الملف الشخصي: $e');
    }
  }

  @override
  Future<ProfileModel> getProfile(String uid) async {
    try {
      final row = await _publicProfileRow(uid);
      if (row == null) {
        throw const ServerException(message: 'الملف الشخصي غير موجود');
      }
      return _fromRpcRow(row);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'لم يكتمل تحميل الملف الشخصي: $e');
    }
  }

  @override
  Stream<ProfileModel> watchProfile(String uid) {
    final controller = StreamController<ProfileModel>();
    RealtimeChannel? channel;

    () async {
      try {
        controller.add(await getProfile(uid));
        channel = _sb.channel('profiles:$uid');
        channel!.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (_) async {
            try {
              controller.add(await getProfile(uid));
            } catch (e, st) {
              if (!controller.isClosed) controller.addError(e, st);
            }
          },
        );
        channel!.subscribe();
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }();

    controller.onCancel = () async {
      try {
        final current = channel;
        if (current != null) await _sb.removeChannel(current);
      } catch (_) {}
    };
    return controller.stream;
  }

  @override
  Future<void> updateTypography({required String usernameFontFamily, required String messageFontFamily}) async {
    await _sb.rpc('set_my_profile_typography', params: {
      'p_username_font_family': usernameFontFamily,
      'p_message_font_family': messageFontFamily,
    });
  }


  String? _normalizeProfileAvatarUrl(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return value;
    final uri = Uri.tryParse(v);
    if (uri == null) return value;
    final seg = [...uri.pathSegments];
    final marker = seg.indexOf('public');
    if (marker >= 0 && marker + 3 < seg.length &&
        seg[marker + 1] == 'profile-avatars' &&
        seg[marker + 2] == 'profile-avatars') {
      final fixed = [
        ...seg.sublist(0, marker + 2),
        ...seg.sublist(marker + 3),
      ];
      return uri.replace(pathSegments: fixed).toString();
    }
    return value;
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null || uid != profile.uid) {
        throw const ServerException(message: 'جلسة المستخدم غير صالحة');
      }

      final currentProfile = await getProfile(uid);
      final currentAvatar = currentProfile.avatarUrl;
      final currentCover = currentProfile.coverUrl;
      final currentMusic = currentProfile.profileMusicUrl;
      final currentMusicDurationMs = currentProfile.profileMusicDurationMs;
      final currentMusicSizeBytes = currentProfile.profileMusicSizeBytes;

      final normalizedAvatar = _normalizeProfileAvatarUrl(profile.avatarUrl);
      final avatarChanged = normalizedAvatar != currentAvatar;
      final coverChanged = profile.coverUrl != currentCover;
      final musicChanged = profile.profileMusicUrl != currentMusic;

      await _sb.rpc('sync_my_public_profile', params: {
        'p_display_name': profile.displayName,
        'p_avatar_url': avatarChanged ? normalizedAvatar : null,
        'p_status_text': profile.statusText,
        'p_bio': profile.bio,
        'p_cover_url': coverChanged ? profile.coverUrl : null,
        'p_profile_music_url': musicChanged ? profile.profileMusicUrl : null,
        'p_profile_music_duration_ms': musicChanged
            ? profile.profileMusicDurationMs
            : currentMusicDurationMs,
        'p_profile_music_size_bytes': musicChanged
            ? profile.profileMusicSizeBytes
            : currentMusicSizeBytes,
        'p_country': profile.country,
        'p_city': profile.city,
        'p_profession': profile.profession,
        'p_experiences': profile.experiences,
        'p_social_links': profile.socialLinks.map((e) => e.toMap()).toList(),
        'p_visibility': profile.visibility.wire,
        'p_account_type': profile.accountType.wire,
        'p_username_color': profile.usernameColor,
        'p_username_font_size': profile.usernameFontSize,
        'p_status_font_size': profile.statusFontSize,
        'p_status_bold': profile.statusBold,
        'p_status_italic': profile.statusItalic,
        'p_status_color': profile.statusColor,
        'p_animated_avatar_url': profile.animatedAvatarUrl,
      });
      // Equipped avatar frame and username background are separate server-authoritative
      // contracts. Send a blank key when the caller intentionally clears a value;
      // never leave a stale cosmetic active merely because the model is nullable.
      if (profile.avatarFrameKey != currentProfile.avatarFrameKey) {
        await _sb.rpc('set_avatar_frame', params: {
          'p_frame_key': profile.avatarFrameKey?.trim() ?? '',
        });
      }
      if (profile.usernameBackgroundKey != currentProfile.usernameBackgroundKey) {
        await _sb.rpc('set_username_background', params: {
          'p_background_key': profile.usernameBackgroundKey?.trim() ?? '',
        });
      }
      return await getProfile(profile.uid);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'لم يكتمل تحديث الملف الشخصي: $e');
    }
  }

  @override
  Future<void> setVerified(
      {required String uid, required bool verified}) async {
    if (_sb.auth.currentUser?.id != uid) {
      throw const ServerException(message: 'غير مصرح');
    }
    throw const ServerException(message: 'حالة التحقق تُدار من الخادم فقط');
  }
}
