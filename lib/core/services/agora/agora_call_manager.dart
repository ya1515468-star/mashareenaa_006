import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'agora_service.dart';

class AgoraCallManager {
  final AgoraService service;

  AgoraCallManager({
    required this.service,
  });

  Future<void> joinCall({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    await service.engine.joinChannel(
      token: token ?? '',
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> leaveCall() async {
    await service.engine.leaveChannel();
  }
}
