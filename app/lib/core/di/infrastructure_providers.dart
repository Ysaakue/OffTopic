import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/network/local_interfaces.dart';
import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/core/storage/key_value_store.dart';
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

/// Runtime permissions. Overridden in `main.dart` with the permission_handler
/// plugin and in tests with a fake.
final permissionRequesterProvider = Provider<PermissionRequester>(
  (ref) => throw UnimplementedError(
    'permissionRequesterProvider must be overridden (see main.dart).',
  ),
);

/// Retry policy for providers whose screens offer an explicit retry button.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Persistent key-value storage. Overridden in `main.dart` with
/// shared_preferences and in tests with an in-memory store.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError(
    'keyValueStoreProvider must be overridden (see main.dart).',
  ),
);

/// The wall clock, injectable so tests control time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// This phone's network interfaces, injectable so tests choose them.
final localInterfacesProvider = Provider<LocalInterfaceLister>(
  (ref) => listLocalInterfaces,
);
