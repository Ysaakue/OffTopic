/// Small persistent string storage. Wraps the platform plugin so repositories
/// stay plain, testable Dart.
abstract interface class KeyValueStore {
  /// The value stored under [key], or null. Throws when the storage fails.
  Future<String?> read(String key);

  /// Stores [value] under [key]. Throws when the storage fails.
  Future<void> write(String key, String value);
}
