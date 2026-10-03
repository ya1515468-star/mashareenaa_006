import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../config/agora_config.dart';

class AgoraService {
  late final RtcEngine _engine;

  RtcEngine get engine => _engine;

  Future<void> initialize() async {
    _engine = createAgoraRtcEngine();

    await _engine.initialize(
      const RtcEngineContext(
        appId: AgoraConfig.appId,
      ),
    );

    await _engine.enableAudio();

    if (AgoraConfig.enableVideo) {
      await _engine.enableVideo();
    }
  }

  Future<void> dispose() async {
    await _engine.release();
  }
}
