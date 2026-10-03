import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/dynamic_avatar_frame.dart';

class ChatVisualSize {
  final String userId;
  final int frameLevel;
  final int smileyLevel;
  /// Independent size dimensions for the profile photo and the animal badge
  /// above the name. Kept separate from frameLevel/smileyLevel so the owner
  /// can size each element on its own.
  final int avatarLevel;
  final int animalLevel;
  final int globalFrameLevel;
  final int globalSmileyLevel;
  final int globalAvatarLevel;
  final int globalAnimalLevel;
  final bool hasOverride;
  final bool isPlatformOwner;
  final bool hasHighestRole;
  final bool isDelegated;
  final bool canManageSelf;
  final bool canManageAny;

  const ChatVisualSize({
    required this.userId,
    required this.frameLevel,
    required this.smileyLevel,
    required this.avatarLevel,
    required this.animalLevel,
    required this.globalFrameLevel,
    required this.globalSmileyLevel,
    required this.globalAvatarLevel,
    required this.globalAnimalLevel,
    required this.hasOverride,
    required this.isPlatformOwner,
    required this.hasHighestRole,
    required this.isDelegated,
    required this.canManageSelf,
    required this.canManageAny,
  });

  factory ChatVisualSize.fromMap(Map<String, dynamic> m) => ChatVisualSize(
        userId: m['user_id']?.toString() ?? '',
        frameLevel: _level(m['frame_level']),
        smileyLevel: _level(m['smiley_level']),
        avatarLevel: _level(m['avatar_level']),
        animalLevel: _level(m['animal_level']),
        globalFrameLevel: _level(m['global_frame_level']),
        globalSmileyLevel: _level(m['global_smiley_level']),
        globalAvatarLevel: _level(m['global_avatar_level']),
        globalAnimalLevel: _level(m['global_animal_level']),
        hasOverride: m['has_override'] == true,
        isPlatformOwner: m['is_platform_owner'] == true,
        hasHighestRole: m['has_highest_role'] == true,
        isDelegated: m['is_delegated'] == true,
        canManageSelf: m['can_manage_self'] == true,
        canManageAny: m['can_manage_any'] == true,
      );

  static int _level(Object? value) {
    final n = value is num ? value.toInt() : int.tryParse('$value');
    return (n ?? 5).clamp(1, 10);
  }

  double get frameScale => DynamicAvatarFrame.frameScaleForLevel(frameLevel);

  /// Public-chat smileys now follow the server-controlled level.
  /// Level 1 is intentionally close to the compact reference size.
  double get smileySize => 14.0 + ((smileyLevel - 1) * (10.0 / 9.0));

  /// Username follows the same compact visual contract as the frame/smiley.
  /// The lower of the two server levels wins so shrinking either control also
  /// shrinks the complete public-chat identity cluster.
  double get usernameScale {
    final level = frameLevel < smileyLevel ? frameLevel : smileyLevel;
    return 0.72 + ((level - 1) * (0.28 / 9));
  }

  /// Driven by avatarLevel now (it used to piggyback on the smaller of
  /// frame/smiley, so the photo could never be sized on its own).
  double get avatarDiameter => 34.0 + ((avatarLevel - 1) * (36.0 / 9.0));

  /// Multiplier applied to the animal badge above the name. 5 = normal.
  double get animalScale => 0.55 + ((animalLevel - 1) * (1.45 / 9.0));

}

final chatVisualSizeProvider = FutureProvider.autoDispose
    .family<ChatVisualSize, String>((ref, uid) async {
  final raw = await Supabase.instance.client.rpc(
    'get_chat_visual_size_config',
    params: {'p_user_id': uid},
  );
  if (raw is! Map) throw StateError('INVALID_VISUAL_SIZE_CONFIG');
  return ChatVisualSize.fromMap(Map<String, dynamic>.from(raw));
});

final currentChatVisualSizeProvider = FutureProvider.autoDispose<ChatVisualSize>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) throw StateError('AUTH_REQUIRED');
  return ref.watch(chatVisualSizeProvider(uid).future);
});

class ChatVisualSizeService {
  static final _db = Supabase.instance.client;

  static Future<ChatVisualSize> fetch(String uid) async {
    final raw = await _db.rpc(
      'get_chat_visual_size_config',
      params: {'p_user_id': uid},
    );
    if (raw is! Map) throw StateError('INVALID_VISUAL_SIZE_CONFIG');
    return ChatVisualSize.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Every dimension is optional: passing null leaves that one untouched on
  /// the server, so adjusting one slider never resets the others.
  static Future<void> setGlobal({
    int? frameLevel,
    int? smileyLevel,
    int? avatarLevel,
    int? animalLevel,
  }) async {
    await _db.rpc('set_global_chat_visual_size', params: {
      'p_frame_level': frameLevel,
      'p_smiley_level': smileyLevel,
      'p_avatar_level': avatarLevel,
      'p_animal_level': animalLevel,
    });
    DynamicAvatarFrame.invalidateVisualSizeCache();
  }

  static Future<void> setMine({required int frameLevel, required int smileyLevel}) async {
    _validate(frameLevel, smileyLevel);
    await _db.rpc('set_my_chat_visual_size', params: {
      'p_frame_level': frameLevel,
      'p_smiley_level': smileyLevel,
    });
    DynamicAvatarFrame.invalidateVisualSizeCache();
  }

  static Future<void> setUser({
    required String userId,
    int? frameLevel,
    int? smileyLevel,
    int? avatarLevel,
    int? animalLevel,
  }) async {
    await _db.rpc('set_user_chat_visual_size', params: {
      'p_user_id': userId,
      'p_frame_level': frameLevel,
      'p_smiley_level': smileyLevel,
      'p_avatar_level': avatarLevel,
      'p_animal_level': animalLevel,
    });
    DynamicAvatarFrame.invalidateVisualSizeCache();
  }

  /// Removes a member's personal override so they follow the global values.
  static Future<void> clearUser(String userId) async {
    await _db.rpc('clear_user_chat_visual_size', params: {'p_user_id': userId});
    DynamicAvatarFrame.invalidateVisualSizeCache();
  }


  static Future<void> setAuthority({required String userId, required bool enabled}) async {
    await _db.rpc('set_chat_visual_size_authority', params: {
      'p_user_id': userId,
      'p_enabled': enabled,
    });
  }

  static Future<List<Map<String, dynamic>>> authorities() async {
    final raw = await _db.rpc('get_chat_visual_size_authorities');
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  static void _validate(int frameLevel, int smileyLevel) {
    if (frameLevel < 1 || frameLevel > 10 || smileyLevel < 1 || smileyLevel > 10) {
      throw ArgumentError('LEVEL_MUST_BE_1_TO_10');
    }
  }
}
