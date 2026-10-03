import '../../../core/services/supabase_service.dart';

/// Profile-only Storage cleanup helper. It removes only the path that belongs
/// to the supplied bucket URL/path and delegates the actual delete to the
/// central Storage gateway.
class ProfileStorageCleanup {
  static Future<void> deletePublicFile({
    required String bucket,
    required String? publicUrl,
  }) async {
    if (publicUrl == null || publicUrl.trim().isEmpty) return;
    final path = _extractPath(bucket, publicUrl.trim());
    if (path == null || path.isEmpty) return;
    await SupabaseService.deleteStoragePath(bucket: bucket, path: path);
  }

  static String? _extractPath(String bucket, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final marker = segments.indexOf('public');
    if (marker < 0 || marker + 2 >= segments.length) return null;
    if (segments[marker + 1] != bucket) return null;
    return segments.sublist(marker + 2).join('/');
  }
}
