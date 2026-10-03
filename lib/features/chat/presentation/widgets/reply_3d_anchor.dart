import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_theme.dart';

/// عنصر GLB حقيقي للرد/الاقتباس. الرابط المنطقي يبقى replyToId/quoted_message_id؛
/// الضغط يستدعي callback يقفز للرسالة الأصلية. عند تعذر عرض GLB لا يُفقد الربط.
class Reply3DAnchor extends StatelessWidget {
  final String messageId;
  final String targetMessageId;
  final String? preview;
  final VoidCallback onTap;
  final bool compact;

  const Reply3DAnchor(
      {super.key,
      required this.messageId,
      required this.targetMessageId,
      this.preview,
      required this.onTap,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: compact ? 58 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: p.surfaceHighlight.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.accent.withValues(alpha: .45))),
          child: Row(children: [
            SizedBox(
                width: compact ? 48 : 62,
                height: compact ? 48 : 62,
                child: const ModelViewer(
                    src: 'assets/chat/3d/reply_anchor.glb',
                    alt: '3D reply anchor',
                    autoRotate: true,
                    cameraControls: true,
                    disableZoom: true,
                    backgroundColor: Colors.transparent)),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('↩ رد ثلاثي الأبعاد',
                      style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                  Text(
                      preview?.isNotEmpty == true
                          ? preview!
                          : 'الانتقال إلى الرسالة الأصلية',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: p.textSecondary, fontSize: 11)),
                ])),
          ]),
        ));
  }
}
