import 'visual_effect_config.dart';
import 'visual_effect_registry.dart';

/// Central runtime contracts used by the 50-effect renderer.
/// These are intentionally lightweight: they own lifecycle/caching policy while
/// [VisualEffectPainter] stays a pure renderer.
class EffectDefinition {
  final VisualEffectConfig config;
  const EffectDefinition(this.config);
}

class EffectRegistry {
  const EffectRegistry();

  EffectDefinition? resolve(String? key) {
    final config = VisualEffectRegistry.get(key);
    return config == null ? null : EffectDefinition(config);
  }
}

class EffectController {
  final EffectRegistry registry;
  const EffectController(this.registry);
}

class EffectCache {
  final Map<String, VisualEffectConfig> _cache = <String, VisualEffectConfig>{};

  VisualEffectConfig? resolve(String? key, VisualEffectQuality quality) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty || normalized == 'none') return null;
    final cacheKey = '$normalized:${quality.name}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final definition = VisualEffectRegistry.get(normalized);
    if (definition == null) return null;
    final scaled = definition.forQuality(quality);
    _cache[cacheKey] = scaled;
    return scaled;
  }

  void clear() => _cache.clear();
}

class EffectPool<T> {
  final List<T> _items = <T>[];
  final T Function() factory;

  EffectPool(this.factory);

  T obtain() => _items.isEmpty ? factory() : _items.removeLast();
  void release(T value) => _items.add(value);
  void clear() => _items.clear();
  int get size => _items.length;
}

class EffectRenderer {
  const EffectRenderer();
}

class ParticleSystem {
  final EffectPool<Object> pool;
  ParticleSystem(this.pool);
}

class LayerManager {
  const LayerManager();

  bool rendersBehind(VisualEffectLayer layer) => layer == VisualEffectLayer.behind;
}

class AnimationTimeline {
  final Duration cycle;
  const AnimationTimeline({this.cycle = const Duration(seconds: 6)});
}

class QualityManager {
  const QualityManager();

  VisualEffectConfig scale(VisualEffectConfig config, VisualEffectQuality quality) =>
      config.forQuality(quality);
}

/// Audio is optional per effect and remains absent unless the server/catalog
/// explicitly supplies an audio asset. This manager does not fabricate audio.
class AudioManager {
  const AudioManager();
}

/// Server-backed metadata boundary. Runtime callers resolve cosmetic metadata
/// from [VisualEffectRegistry] after the authenticated catalog is loaded.
class ServerEffectRepository {
  const ServerEffectRepository();

  EffectDefinition? resolve(String? key) => const EffectRegistry().resolve(key);
}

class EffectEngine {
  final EffectController controller;
  final EffectCache cache;
  final LayerManager layers;
  final AnimationTimeline timeline;
  final QualityManager quality;
  final AudioManager audio;
  final ServerEffectRepository server;

  EffectEngine({
    EffectController? controller,
    EffectCache? cache,
    LayerManager? layers,
    AnimationTimeline? timeline,
    QualityManager? quality,
    AudioManager? audio,
    ServerEffectRepository? server,
  })  : controller = controller ?? const EffectController(EffectRegistry()),
        cache = cache ?? EffectCache(),
        layers = layers ?? const LayerManager(),
        timeline = timeline ?? const AnimationTimeline(),
        quality = quality ?? const QualityManager(),
        audio = audio ?? const AudioManager(),
        server = server ?? const ServerEffectRepository();

  VisualEffectConfig? resolve(String? key, VisualEffectQuality level) =>
      cache.resolve(key, level);

  void dispose() => cache.clear();
}
