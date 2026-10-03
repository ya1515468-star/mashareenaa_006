import 'package:get_it/get_it.dart';

import '../services/agora/agora_service.dart';
import '../services/agora/agora_call_manager.dart';
import '../../features/calls/data/agora_token_service.dart';

void registerAgoraDependencies(GetIt sl) {
  if (!sl.isRegistered<AgoraService>()) {
    sl.registerLazySingleton<AgoraService>(
      () => AgoraService(),
    );
  }

  if (!sl.isRegistered<AgoraTokenService>()) {
    sl.registerLazySingleton<AgoraTokenService>(
      () => const AgoraTokenService(),
    );
  }

  if (!sl.isRegistered<AgoraCallManager>()) {
    sl.registerLazySingleton<AgoraCallManager>(
      () => AgoraCallManager(
        service: sl<AgoraService>(),
      ),
    );
  }
}
