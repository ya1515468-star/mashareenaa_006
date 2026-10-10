import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// يستخرج حتى [count] لقطات JPEG من الفيديو على الويب عبر عنصر video + canvas.
Future<List<Uint8List>> extractVideoFrames(XFile file, {int count = 3}) async {
  final video = web.document.createElement('video') as web.HTMLVideoElement;
  video.muted = true;
  video.preload = 'auto';
  video.src = file.path; // blob: URL

  Future<void> once(String event) {
    final c = Completer<void>();
    late final JSFunction cb;
    cb = ((web.Event _) {
      video.removeEventListener(event, cb);
      if (!c.isCompleted) c.complete();
    }).toJS;
    video.addEventListener(event, cb);
    return c.future.timeout(const Duration(seconds: 15));
  }

  final out = <Uint8List>[];
  try {
    await once('loadeddata');
    final duration = video.duration;
    if (duration.isNaN || duration.isInfinite || duration <= 0) return out;
    final vw = video.videoWidth == 0 ? 640 : video.videoWidth;
    final vh = video.videoHeight == 0 ? 360 : video.videoHeight;
    final scale = vw > 768 ? 768 / vw : 1.0;
    final w = (vw * scale).round();
    final h = (vh * scale).round();
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    for (var i = 0; i < count; i++) {
      final t = duration * (i + 0.5) / count;
      final seeked = once('seeked');
      video.currentTime = t;
      await seeked;
      ctx.drawImage(video, 0, 0, w, h);
      final url = canvas.toDataURL('image/jpeg', 0.7.toJS);
      final comma = url.indexOf(',');
      if (comma > 0) out.add(base64Decode(url.substring(comma + 1)));
    }
  } catch (_) {
    // نعيد ما استُخرج حتى لحظة الفشل.
  }
  return out;
}
