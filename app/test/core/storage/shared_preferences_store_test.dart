import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/storage/shared_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('writes and reads strings through shared_preferences', () async {
    final store = SharedPreferencesStore(SharedPreferencesAsync());

    expect(await store.read('talk.mode'), isNull);
    await store.write('talk.mode', 'voice');

    expect(await store.read('talk.mode'), 'voice');
  });

  test('uses the default shared_preferences instance', () async {
    await SharedPreferencesStore().write('key', 'value');

    expect(await SharedPreferencesAsync().getString('key'), 'value');
  });
}
