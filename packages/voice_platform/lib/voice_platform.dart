/// Typed platform services for OffTopic (foreground service, audio route,
/// Wi-Fi, system settings), implemented in Kotlin and Swift through Pigeon.
///
/// No audio samples ever cross these channels.
library;

export 'src/models/active_room.dart';
export 'src/models/audio_route.dart';
export 'src/models/platform_capabilities.dart';
export 'src/models/platform_info.dart';
export 'src/models/platform_state.dart';
export 'src/models/room_config.dart';
export 'src/models/room_role.dart';
export 'src/models/talk_mode.dart';
export 'src/models/vad_sensitivity.dart';
export 'src/models/wifi_state.dart';
export 'src/pigeon_voice_platform_gateway.dart' show PigeonVoicePlatformGateway;
export 'src/voice_platform_exception.dart';
export 'src/voice_platform_gateway.dart';
