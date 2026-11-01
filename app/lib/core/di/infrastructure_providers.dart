import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/voice_platform.dart';

/// Native voice core. Overridden in `main.dart` with the FFI client and in
/// tests with `FakeVoiceCoreClient`.
final voiceCoreClientProvider = Provider<VoiceCoreClient>(
  (ref) => throw UnimplementedError(
    'voiceCoreClientProvider must be overridden (see main.dart).',
  ),
);

/// Platform services. Overridden in `main.dart` with the Pigeon gateway and in
/// tests with `FakeVoicePlatformGateway`.
final voicePlatformGatewayProvider = Provider<VoicePlatformGateway>(
  (ref) => throw UnimplementedError(
    'voicePlatformGatewayProvider must be overridden (see main.dart).',
  ),
);

/// Retry policy for providers whose screens offer an explicit retry button.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
