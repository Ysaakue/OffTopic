/// A failure reported by, or while talking to, the native voice core.
final class VoiceCoreException implements Exception {
  /// Creates an exception with a human readable [message].
  const new(this.message);

  /// What went wrong, for logs and diagnostics.
  final String message;

  @override
  String toString() => 'VoiceCoreException: $message';
}
