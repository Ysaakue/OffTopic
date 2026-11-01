import 'package:flutter/services.dart';

/// Error codes shared with the host implementations (Kotlin
/// `PlatformErrorCodes`).
abstract final class VoicePlatformErrorCode {
  /// The host method exists but is scheduled for a later phase.
  static const notImplemented = 'not_implemented';

  /// The platform cannot offer this feature at all (e.g. hosting on iOS).
  static const unsupported = 'unsupported';

  /// The host side of the channel is missing (plugin not registered).
  static const channelError = 'channel-error';
}

/// A failure reported by the host platform.
final class VoicePlatformException implements Exception {
  /// Creates an exception with a machine readable [code].
  const new({required this.code, this.message});

  /// Converts the exception thrown by a platform channel.
  factory fromPlatformException(PlatformException exception) =>
      VoicePlatformException(code: exception.code, message: exception.message);

  /// One of [VoicePlatformErrorCode], or a host specific code.
  final String code;

  /// Human readable detail, for logs and diagnostics.
  final String? message;

  /// Whether the host has not implemented this call yet.
  bool get isNotImplemented => code == VoicePlatformErrorCode.notImplemented;

  @override
  String toString() => 'VoicePlatformException($code): ${message ?? ''}';
}
