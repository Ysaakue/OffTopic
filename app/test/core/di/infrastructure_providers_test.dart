import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/network/local_interfaces.dart';

void main() {
  group('infrastructure providers', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer.test());

    test('the voice core must be overridden by main()', () {
      expect(
        () => container.read(voiceCoreClientProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
    });

    test('the platform gateway must be overridden by main()', () {
      expect(
        () => container.read(voicePlatformGatewayProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
    });
  });

  test('the network interfaces come from dart:io by default', () {
    final container = ProviderContainer.test();

    expect(
      container.read(localInterfacesProvider),
      equals(listLocalInterfaces),
    );
  });

  test('noAutomaticRetry never schedules a retry', () {
    expect(noAutomaticRetry(0, Exception('x')), isNull);
    expect(noAutomaticRetry(5, StateError('y')), isNull);
  });
}
