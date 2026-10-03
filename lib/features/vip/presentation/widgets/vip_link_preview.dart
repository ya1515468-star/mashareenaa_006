import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VipLinkPreview extends StatelessWidget {
  final String url;
  final bool compact;
  const VipLinkPreview({super.key, required this.url, this.compact = false});

  Uri? get _uri {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    return Uri.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final uri = _uri;
    if (uri == null || uri.host.isEmpty) return const SizedBox.shrink();
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return const SizedBox.shrink();
    final path = uri.path.isEmpty ? '/' : uri.path;
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 10 : 14),
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: EdgeInsets.all(compact ? 8 : 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 30 : 38,
              height: compact ? 30 : 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: Colors.cyanAccent.withValues(alpha: .12),
              ),
              child: Icon(Icons.link, color: Colors.cyanAccent, size: compact ? 17 : 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(uri.host, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(path + (uri.hasQuery ? '?…' : ''), maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 10 : 11, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, size: 15, color: Colors.cyanAccent),
          ],
        ),
      ),
    );
  }
}
