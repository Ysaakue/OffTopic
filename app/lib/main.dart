// Bootstrap only: wires the real native implementations into the providers.
// Excluded from the coverage gate (it only runs on a device); everything it
// wires is tested through fakes.
// coverage:ignore-file
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/app.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/permissions/permission_handler_requester.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/voice_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        voiceCoreClientProvider.overrideWithValue(FfiVoiceCoreClient.open()),
        voicePlatformGatewayProvider.overrideWithValue(
          PigeonVoicePlatformGateway(),
        ),
        permissionRequesterProvider.overrideWithValue(
          const PermissionHandlerRequester(),
        ),
      ],
      child: const OffTopicApp(),
    ),
  );
}
