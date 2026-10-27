part of 'chat_lobby_page.dart';

// أفاتار بنمط الفيديو
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _VideoStyleAvatar extends ConsumerWidget {
  final String? url;
  final String name;
  final String? rowUid;
  final String? frameKey;
  final String? roomId;

  /// عنصر يُرسم مباشرة أسفل الإطار (شارة الرتبة/السلطة). يوضع داخل نفس
  /// Transform.translate الذي يرفع الأفاتار، فيتحرّك معه ويلتصق به.
  /// خارج التحويل كان يُوضع تحت صندوق التخطيط الأصلي (قبل الرفع) فيظهر
  /// فراغ بمقدار الرفع (~0.45 من القطر) بين الصورة والشارة.
  final Widget? below;
  const _VideoStyleAvatar({
    this.url,
    required this.name,
    this.rowUid,
    this.frameKey,
    this.roomId,
    this.below,
  });

  Widget _withBelow(Widget framed) => below == null
      ? framed
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [framed, below!],
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = rowUid == null
        ? const AsyncValue<ProfileEntity?>.data(null)
        : ref.watch(profileByIdProvider(rowUid!));
    final serverIdentity = rowUid == null
        ? const AsyncValue<Map<String, dynamic>>.data({})
        : (roomId == null
            ? ref.watch(serverUserIdentityProvider(rowUid!))
            : ref.watch(serverUserIdentityInRoomProvider((uid: rowUid!, roomId: roomId))));

    final identity = serverIdentity.valueOrNull ?? const <String, dynamic>{};
    final serverAvatar = identity['avatar_url']?.toString();
    final serverAnimatedAvatar = identity['animated_avatar_url']?.toString();
    final serverFrame = identity['avatar_frame_key']?.toString();
    // Prefer the persisted normal avatar. The upload flow clears the animated
    // avatar when a new normal photo is saved, preventing stale GIF display.
    final imageUrl = _normalizeProfileAvatarUrl(
      (serverAvatar != null && serverAvatar.isNotEmpty)
          ? serverAvatar
          : (serverAnimatedAvatar != null && serverAnimatedAvatar.isNotEmpty)
              ? serverAnimatedAvatar
              : (url ?? profile.valueOrNull?.avatarUrl ?? profile.valueOrNull?.animatedAvatarUrl),
    );
    final effectiveFrameKey = (serverFrame != null && serverFrame.isNotEmpty)
        ? serverFrame
        : (frameKey != null && frameKey!.trim().isNotEmpty)
            ? frameKey
            : profile.valueOrNull?.avatarFrameKey;

    final visualSize = rowUid == null
        ? null
        : ref.watch(chatVisualSizeProvider(rowUid!)).valueOrNull;
    final avatarDiameter = visualSize?.avatarDiameter ?? 50.0;
    final avatarRadius = avatarDiameter / 2;
    final avatarFrameScale = visualSize?.frameScale ?? DynamicAvatarFrame.frameScaleForLevel(5);

    final avatar = SizedBox(
      width: avatarDiameter,
      height: avatarDiameter,
      child: ClipOval(
        child: imageUrl == null || imageUrl.isEmpty
            ? Container(
                color: const Color(0xFFEEE7F4),
                child: const Icon(Icons.person, color: Color(0xFF6D5A78)),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEEE7F4),
                  child: const Icon(Icons.person, color: Color(0xFF6D5A78)),
                ),
              ),
      ),
    );

    // Vertical alignment with the name row.
    //
    // The decorative frame artwork is considerably taller than the avatar
    // circle itself, so with the row's top alignment the visible circle ends
    // up sitting well below the name. Transform.translate is used rather than
    // SizedBox/OverflowBox because it shifts only the PAINTED result and
    // touches no constraints at all — an earlier OverflowBox attempt inherited
    // an unbounded width inside the Row and broke the entire message layout.
    //
    // TUNING: raise or lower this single factor if the circle still looks off
    // (larger value = avatar moves further up).
    const avatarVerticalLiftFactor = 0.45;

    // Colored ("simple") frames are drawn procedurally by StoreAvatarFrame,
    // not from a catalog image, so they cannot go through DynamicAvatarFrame.
    // The equipped id now arrives inside the chat identity payload (resolved
    // server-side, so OTHER members' colored frames render too), and the
    // colours are looked up from the shared store catalog by sku.
    // A normal avatar frame WINS over a colored one.
    //
    // Previously the colored branch ran first, so an old equipped colored
    // frame permanently hijacked the avatar and every normal frame silently
    // did nothing — it saved correctly on the server but never rendered.
    // The two are alternatives, so the explicitly-set avatar_frame_key takes
    // precedence and the colored frame only applies when no normal frame is set.
    final coloredFrameId = (effectiveFrameKey == null || effectiveFrameKey.isEmpty)
        ? (identity['colored_frame_id']?.toString().trim() ?? '')
        : '';
    if (coloredFrameId.isNotEmpty) {
      final catalog =
          ref.watch(storeCatalogProvider).valueOrNull ?? const <StoreItemEntity>[];
      StoreItemEntity? coloredItem;
      for (final it in catalog) {
        if (it.sku.toLowerCase() == coloredFrameId.toLowerCase()) {
          coloredItem = it;
          break;
        }
      }
      if (coloredItem != null && coloredItem.colors.isNotEmpty) {
        return Transform.translate(
          offset: Offset(0, -avatarDiameter * avatarVerticalLiftFactor),
          child: _withBelow(StoreAvatarFrame(
            colors: coloredItem.colors,
            padding: 3,
            child: avatar,
          )),
        );
      }
    }

    return Transform.translate(
      offset: Offset(0, -avatarDiameter * avatarVerticalLiftFactor),
      child: _withBelow(DynamicAvatarFrame(
        frameKey: effectiveFrameKey,
        radius: avatarRadius,
        frameScale: avatarFrameScale,
        userId: rowUid,
        child: avatar,
      )),
    );
  }
}
