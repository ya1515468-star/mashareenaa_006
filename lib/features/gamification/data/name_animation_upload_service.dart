import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/gif_inspector.dart';

class NameAnimationUploadRequest {
  final Uint8List bytes;
  final String filename;
  final String key;
  final String nameAr;
  final String category;
  final int pricePoints;
  final int priceGems;
  final double maxWidth;
  final double maxHeight;
  final int fps;
  final int durationMs;
  final bool ownerFree;

  const NameAnimationUploadRequest({
    required this.bytes,
    required this.filename,
    required this.key,
    required this.nameAr,
    this.category = 'animal',
    required this.pricePoints,
    required this.priceGems,
    this.maxWidth = 44,
    this.maxHeight = 30,
    this.fps = 24,
    this.durationMs = 1800,
    this.ownerFree = false,
  });
}

class NameAnimationUploadService {
  const NameAnimationUploadService();

  Future<Map<String, dynamic>> uploadAndCreate(
    NameAnimationUploadRequest input, {
    void Function(double sentFraction)? onSendProgress,
  }) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) throw StateError('AUTH_REQUIRED');
    if (input.bytes.isEmpty) throw StateError('ANIMATION_EMPTY');
    if (input.bytes.length > 8 * 1024 * 1024) throw StateError('ANIMATION_TOO_LARGE');
    if (!input.filename.toLowerCase().endsWith('.gif')) throw StateError('GIF_REQUIRED');

    final info = GifInspector.inspect(input.bytes);
    if (info == null) throw StateError('INVALID_GIF');
    if (info.width < 1 || info.height < 1 || info.width > 2048 || info.height > 2048) {
      throw StateError('INVALID_GIF_DIMENSIONS');
    }
    if (info.numFrames < 1 || info.numFrames > 240) throw StateError('GIF_TOO_MANY_FRAMES');
    final endpoint = Uri.parse('${SupabaseConfig.url}/functions/v1/name-animation-assets');
    final requestId = const Uuid().v4();
    final apiKey = client.rest.headers['apikey'] ?? SupabaseConfig.publishableKey;
    var token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) throw StateError('AUTH_REQUIRED');

    // A streamed request so the progress bar reflects real bytes handed to
    // the socket, not a fake timer — feeding the sink and awaiting the
    // response run concurrently, which is what lets the percentage move.
    Future<http.Response> send(String accessToken) async {
      final request = http.StreamedRequest('POST', endpoint)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..headers['apikey'] = apiKey
        ..headers['Content-Type'] = 'image/gif'
        ..headers['x-request-id'] = requestId
        ..headers['x-name-animation-filename'] = base64Url.encode(utf8.encode(input.filename))
        ..headers['x-name-animation-key'] = input.key.trim()
        ..headers['x-name-animation-name-ar'] = base64Url.encode(utf8.encode(input.nameAr.trim()))
        ..headers['x-name-animation-category'] = input.category.trim()
        ..headers['x-name-animation-price-points'] = '${input.pricePoints.clamp(0, 1000000000)}'
        ..headers['x-name-animation-price-gems'] = '${input.priceGems.clamp(0, 1000000000)}'
        ..headers['x-name-animation-owner-free'] = '${input.ownerFree}'
        ..contentLength = input.bytes.length;

      final httpClient = http.Client();
      try {
        final total = input.bytes.length;
        onSendProgress?.call(0);
        final responseFuture = httpClient.send(request);
        const chunkSize = 64 * 1024;
        for (var offset = 0; offset < total; offset += chunkSize) {
          final end = (offset + chunkSize < total) ? offset + chunkSize : total;
          request.sink.add(input.bytes.sublist(offset, end));
          onSendProgress?.call(end / total);
          // Yield so the progress bar actually repaints between chunks.
          await Future<void>.delayed(Duration.zero);
        }
        await request.sink.close();
        final streamedResponse = await responseFuture;
        return await http.Response.fromStream(streamedResponse);
      } finally {
        httpClient.close();
      }
    }

    http.Response response;
    try {
      response = await send(token).timeout(const Duration(seconds: 45));
    } catch (e) {
      try {
        response = await send(token).timeout(const Duration(seconds: 45));
      } catch (e2) {
        throw StateError('NETWORK_ERROR: $e2');
      }
    }
    if (response.statusCode == 401) {
      final refreshed = await client.auth.refreshSession();
      token = refreshed.session?.accessToken ?? client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) throw StateError('SESSION_EXPIRED');
      response = await send(token).timeout(const Duration(seconds: 45));
    }

    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300 && body['ok'] == true) return body;

    final error = body['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      final detail = body['detail']?.toString().trim();
      if (detail != null && detail.isNotEmpty) {
        // Keep backend truth in developer logs; show only a safe mapped code to the user.
        debugPrint('NAME_ANIMATION_UPLOAD $requestId $error: $detail');
      }
      throw StateError(error);
    }
    throw StateError(_classifyHttp(response.statusCode));
  }

  String _classifyHttp(int status) {
    if (status == 400) return 'UPLOAD_VALIDATION_FAILED';
    if (status == 401) return 'AUTH_REQUIRED';
    if (status == 403) return 'FORBIDDEN';
    if (status == 413) return 'ANIMATION_TOO_LARGE';
    if (status >= 500) return 'SERVER_ERROR';
    return 'UPLOAD_FAILED_HTTP_$status';
  }
}
