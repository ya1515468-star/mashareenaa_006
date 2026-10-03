import 'dart:async';
import 'package:flutter/foundation.dart';

class UploadProgress {
  final String id;
  final String fileName;
  final String bucket;
  final int sentBytes;
  final int totalBytes;
  final String status;
  final Object? error;

  const UploadProgress({
    required this.id,
    required this.fileName,
    required this.bucket,
    required this.sentBytes,
    required this.totalBytes,
    required this.status,
    this.error,
  });

  double get fraction => totalBytes <= 0
      ? (status == 'success' ? 1 : 0)
      : (sentBytes / totalBytes).clamp(0, 1);

  int get percent => (fraction * 100).round().clamp(0, 100);
}

class UploadProgressBus {
  UploadProgressBus._();

  static final ValueNotifier<UploadProgress?> current =
      ValueNotifier<UploadProgress?>(null);

  static void begin({required String id, required String fileName, required String bucket, required int totalBytes}) {
    current.value = UploadProgress(
      id: id,
      fileName: fileName,
      bucket: bucket,
      sentBytes: 0,
      totalBytes: totalBytes,
      status: 'uploading',
    );
  }

  static void update({required String id, required String fileName, required String bucket, required int sentBytes, required int totalBytes}) {
    if (current.value?.id != id) return;
    current.value = UploadProgress(
      id: id,
      fileName: fileName,
      bucket: bucket,
      sentBytes: sentBytes,
      totalBytes: totalBytes,
      status: 'uploading',
    );
  }

  static Future<void> success({required String id, required String fileName, required String bucket, required int totalBytes}) async {
    if (current.value?.id != id) return;
    current.value = UploadProgress(
      id: id,
      fileName: fileName,
      bucket: bucket,
      sentBytes: totalBytes,
      totalBytes: totalBytes,
      status: 'success',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (current.value?.id == id) current.value = null;
  }

  static Future<void> failure({required String id, required String fileName, required String bucket, required int totalBytes, required Object error}) async {
    if (current.value?.id != id) return;
    current.value = UploadProgress(
      id: id,
      fileName: fileName,
      bucket: bucket,
      sentBytes: current.value?.sentBytes ?? 0,
      totalBytes: totalBytes,
      status: 'error',
      error: error,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (current.value?.id == id) current.value = null;
  }
}

class UploadId {
  UploadId._();
  static int _counter = 0;
  static String next() => '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
}
