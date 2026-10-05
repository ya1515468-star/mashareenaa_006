import 'dart:io';

Future<void> deleteVoiceFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
