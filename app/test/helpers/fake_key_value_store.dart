import 'package:offtopic/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] whose reads and writes can be made to fail.
final class FakeKeyValueStore implements KeyValueStore {
  final Map<String, String> values = {};

  /// When set, [read] throws it.
  Exception? readError;

  /// When set, [write] throws it.
  Exception? writeError;

  @override
  Future<String?> read(String key) async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    values[key] = value;
  }
}
