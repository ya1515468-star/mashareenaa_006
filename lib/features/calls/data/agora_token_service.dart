import 'package:supabase_flutter/supabase_flutter.dart';

class AgoraTokenData {
  final String appId;
  final String token;
  final int uid;
  final int expiresAt;
  const AgoraTokenData(
      {required this.appId,
      required this.token,
      required this.uid,
      required this.expiresAt});
}

class AgoraTokenService {
  const AgoraTokenService();

  Future<AgoraTokenData> issue(
      {required String channel, required int uid}) async {
    final response = await Supabase.instance.client.functions.invoke(
      'agora-token',
      body: {'channel': channel, 'uid': uid},
    );
    final raw = response.data;
    if (raw is! Map) throw StateError('Invalid Agora token response');
    final data = Map<String, dynamic>.from(raw);
    // The function returns {"error": "..."} on failure. Previously that was
    // mapped straight into empty strings, so the caller only ever saw the
    // useless "AGORA_CREDENTIALS_EMPTY: appId=, token=" and the real reason
    // (most often AGORA_SERVER_NOT_CONFIGURED, i.e. the Agora secrets are not
    // set on the server) was thrown away. Surface the server's own message.
    final serverError = data['error']?.toString();
    if (serverError != null && serverError.isNotEmpty) {
      throw StateError('AGORA_SERVER_ERROR: $serverError');
    }
    return AgoraTokenData(
      appId: data['appId']?.toString() ?? '',
      token: data['token']?.toString() ?? '',
      uid: (data['uid'] as num?)?.toInt() ?? uid,
      expiresAt: (data['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }
}
