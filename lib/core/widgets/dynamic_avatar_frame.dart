import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/presentation/widgets/avatar_frame_catalog.dart';
import 'avatar_frame_compositor.dart';

/// Canonical animated avatar-frame renderer.
///
/// The original GIF remains untouched in Storage. The frame is rendered as a
/// ring over the user's avatar, which gives a real transparent opening without
/// re-encoding the animated GIF or risking frame loss/corruption.
class DynamicAvatarFrame extends StatefulWidget {
  final String? frameKey;
  final int? frameId;
  final double radius;
  final double frameScale;
  final String? userId;
  final Widget child;

  const DynamicAvatarFrame({
    super.key,
    this.frameKey,
    this.frameId,
    required this.radius,
    this.frameScale = 1.0,
    this.userId,
    required this.child,
  });

  @override
  State<DynamicAvatarFrame> createState() => _DynamicAvatarFrameState();

  static double frameScaleForLevel(int level) {
    // Chat reference sizing: keep the frame close to the avatar instead of
    // letting the transparent artwork dominate the row. The full 1..10 range
    // remains active so each setting is visibly different.
    final l = level.clamp(1, 10);
    return 0.55 + ((l - 1) * (0.31 / 9));
  }

  static void invalidateVisualSizeCache([String? userId]) =>
      _DynamicAvatarFrameState.invalidateVisualSizeCache(userId);
}

class _DynamicAvatarFrameState extends State<DynamicAvatarFrame> {
  static final Map<String, Future<AvatarFrameDefinition?>> _cache = {};
  static final Map<String, Future<double>> _sizeCache = {};
  static final ValueNotifier<int> _visualRevisionNotifier = ValueNotifier<int>(0);
  static int _revision = 0;

  late Future<AvatarFrameDefinition?> _definitionFuture;

  String? get _key {
    final key = widget.frameKey?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  @override
  void initState() {
    super.initState();
    _definitionFuture = _load(_key);
  }

  @override
  void didUpdateWidget(covariant DynamicAvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameKey?.trim() != widget.frameKey?.trim()) {
      _definitionFuture = _load(_key);
    }
  }

  static void invalidateVisualSizeCache([String? userId]) {
    if (userId == null || userId.isEmpty) {
      _sizeCache.clear();
    } else {
      _sizeCache.remove(userId);
    }
    _revision++;
    _visualRevisionNotifier.value = _revision;
  }

  Future<double> _loadEffectiveScale(String? userId) {
    final uid = userId?.trim();
    final cacheKey = uid == null || uid.isEmpty ? '__me__' : uid;
    return _sizeCache.putIfAbsent(cacheKey, () async {
      try {
        final raw = await Supabase.instance.client.rpc(
          'get_chat_visual_size_config',
          params: {'p_user_id': uid},
        );
        final map = raw is Map
            ? Map<String, dynamic>.from(raw)
            : const <String, dynamic>{};
        final n = map['frame_level'] is num
            ? (map['frame_level'] as num).toInt()
            : int.tryParse('${map['frame_level'] ?? 5}') ?? 5;
        return DynamicAvatarFrame.frameScaleForLevel(n);
      } catch (_) {
        return DynamicAvatarFrame.frameScaleForLevel(5);
      }
    });
  }

  static Future<AvatarFrameDefinition?> _load(String? key) {
    if (key == null) return Future.value(null);
    return _cache.putIfAbsent(key, () async {
      try {
        final raw = await Supabase.instance.client.rpc(
          'get_avatar_frame_config',
          params: {'p_frame_key': key},
        );
        if (raw is! Map || raw.isEmpty) return null;
        final def = AvatarFrameDefinition.fromMap(
          Map<String, dynamic>.from(raw),
        );
        return def.assetUrl == null ? null : def;
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.radius * 2;
    return ValueListenableBuilder<int>(
      valueListenable: _visualRevisionNotifier,
      builder: (_, __, ___) => FutureBuilder<List<Object?>>(
        future: Future.wait<Object?>([_definitionFuture, _loadEffectiveScale(widget.userId)]),
        builder: (context, snapshot) {
          final definition = snapshot.data != null && snapshot.data!.isNotEmpty
              ? snapshot.data![0] as AvatarFrameDefinition?
              : null;
          final remoteScale = snapshot.data != null && snapshot.data!.length > 1
              ? snapshot.data![1] as double
              : DynamicAvatarFrame.frameScaleForLevel(5);
          if (definition == null || definition.assetUrl == null) {
            return SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: widget.child,
            );
          }
          return AvatarFrameComposite(
            avatar: widget.child,
            frame: NetworkImage(definition.assetUrl!),
            size: avatarSize,
            frameScale: widget.frameScale * remoteScale,
            framePadding: 0,
            innerOpeningRatio: definition.metrics.innerOpeningRatio,
            innerCenterX: definition.metrics.innerCenterX,
            innerCenterY: definition.metrics.innerCenterY,
            effect: definition.frameEffect,
          );
        },
      ),
    );
  }
}
