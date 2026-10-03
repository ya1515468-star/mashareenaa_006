import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';

class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;
  final double frameScale;
  final String? animatedAvatarUrl;
  final String? frameKey;
  final int? frameId;
  final String? userId;

  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 44,
    this.frameScale = 1.0,
    this.animatedAvatarUrl,
    this.frameKey,
    this.frameId,
    this.userId,
  });

  String? _normalizeSupabasePublicUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    final segments = [...uri.pathSegments];
    final objectMarker = segments.indexOf('object');
    if (objectMarker < 0 || objectMarker + 3 >= segments.length) return value;
    if (segments[objectMarker + 1] != 'public') return value;
    final bucket = segments[objectMarker + 2];
    if (bucket == 'profile-avatars' &&
        objectMarker + 3 < segments.length &&
        segments[objectMarker + 3] == bucket) {
      final fixed = [
        ...segments.sublist(0, objectMarker + 3),
        ...segments.sublist(objectMarker + 4),
      ];
      return uri.replace(pathSegments: fixed).toString();
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = displayName.trim();
    final initial =
        trimmed.isNotEmpty ? trimmed.substring(0, 1).toUpperCase() : '?';

    // A newly uploaded normal avatar is authoritative for the visible image.
    // The profile upload flow clears animatedAvatarUrl on the same save, so the
    // static URL must be preferred whenever it is available.
    final rawUrl =
        (avatarUrl != null && avatarUrl!.isNotEmpty)
            ? avatarUrl
            : animatedAvatarUrl?.trim();
    final effectiveUrl = _normalizeSupabasePublicUrl(rawUrl);

    final avatar = effectiveUrl != null && effectiveUrl.isNotEmpty
        ? ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Image.network(
                effectiveUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: radius * 0.7,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, event) => event == null
                    ? child
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: radius * 0.35,
                          height: radius * 0.35,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          );

    return DynamicAvatarFrame(
      frameId: frameId,
      frameKey: frameKey,
      radius: radius,
      frameScale: frameScale,
      userId: userId,
      child: avatar,
    );
  }
}
