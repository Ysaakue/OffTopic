import 'package:offtopic/core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] over the shared_preferences plugin (asynchronous API, so
/// nothing is cached in memory behind the platform's back).
final class SharedPreferencesStore implements KeyValueStore {
  new([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}
