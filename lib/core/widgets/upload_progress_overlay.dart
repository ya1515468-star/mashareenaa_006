import 'package:flutter/material.dart';
import '../services/upload_progress.dart';

class UploadProgressOverlay extends StatelessWidget {
  final Widget child;
  const UploadProgressOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<UploadProgress?>(
          valueListenable: UploadProgressBus.current,
          builder: (context, progress, _) {
            if (progress == null) return const SizedBox.shrink();
            final isSuccess = progress.status == 'success';
            final isError = progress.status == 'error';
            return Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF1B1524),
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle
                                  : isError
                                      ? Icons.error
                                      : Icons.cloud_upload,
                              color: isSuccess
                                  ? Colors.greenAccent
                                  : isError
                                      ? Colors.redAccent
                                      : const Color(0xFFD39BFF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isSuccess
                                    ? 'اكتمل رفع ${progress.fileName}'
                                    : isError
                                        ? 'فشل رفع ${progress.fileName}'
                                        : 'جاري رفع ${progress.fileName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${progress.percent}%',
                              style: const TextStyle(
                                color: Color(0xFFFFD45C),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: isError ? null : progress.fraction,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatBytes(progress.sentBytes)} / ${_formatBytes(progress.totalBytes)}  •  ${progress.bucket}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}
