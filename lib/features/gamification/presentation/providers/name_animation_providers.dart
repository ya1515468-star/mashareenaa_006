import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/name_animation_repository.dart';
import '../../domain/entities/name_animation.dart';

final nameAnimationRepositoryProvider = Provider<NameAnimationRepository>((ref) => const NameAnimationRepository());
final nameAnimationCatalogProvider = FutureProvider<List<NameAnimation>>((ref) => ref.read(nameAnimationRepositoryProvider).catalog());
final myNameAnimationOwnershipProvider = FutureProvider<Set<String>>((ref) => ref.read(nameAnimationRepositoryProvider).owned());
final activeNameAnimationProvider = FutureProvider.family<NameAnimation?, String>((ref, uid) async {
  try { return await ref.read(nameAnimationRepositoryProvider).active(uid); } catch (e, st) {
    debugPrint('activeNameAnimationProvider[$uid] failed: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
});

/// Loads the real animated GIF from the canonical server-side Storage path.
/// JSON/Lottie payloads are intentionally never treated as GIF bytes.
final nameAnimationAssetBytesProvider = FutureProvider.family<Uint8List?, NameAnimation>((ref, animation) async {
  final path = animation.storagePath?.trim();
  if (path == null || path.isEmpty) return null;
  try {
    final bytes = await Supabase.instance.client.storage.from('name-animations').download(path);
    return bytes.isEmpty ? null : bytes;
  } catch (e, st) {
    debugPrint('nameAnimationAssetBytesProvider[$path] failed: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
});

/// Backward-compatible path-based provider for non-UI callers.
final nameAnimationStorageBytesProvider = FutureProvider.family<Uint8List?, String>((ref, storagePath) async {
  final path = storagePath.trim();
  if (path.isEmpty) return null;
  try {
    final bytes = await Supabase.instance.client.storage.from('name-animations').download(path);
    return bytes.isEmpty ? null : bytes;
  } catch (e, st) {
    debugPrint('nameAnimationStorageBytesProvider[$path] failed: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
});
