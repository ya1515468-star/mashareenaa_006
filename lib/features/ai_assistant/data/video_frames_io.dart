import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// يستخرج حتى [count] لقطات JPEG من الفيديو (جوال/سطح المكتب).
Future<List<Uint8List>> extractVideoFrames(XFile file, {int count = 3}) async {
  final out = <Uint8List>[];
  const times = [400, 2500, 5500, 9000];
  for (final t in times.take(count)) {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: t,
        maxWidth: 768,
        quality: 70,
      );
      if (data != null && data.isNotEmpty) out.add(data);
    } catch (_) {}
  }
  return out;
}
