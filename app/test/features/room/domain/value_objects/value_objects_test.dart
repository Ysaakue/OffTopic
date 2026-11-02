import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/room/domain/value_objects/display_name.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';

void main() {
  group('HostAddress', () {
    test('accepts unicast IPv4 addresses, trimmed', () {
      for (final (input, value) in [
        ('192.168.43.1', '192.168.43.1'),
        ('  10.0.0.2 ', '10.0.0.2'),
        ('172.20.10.1', '172.20.10.1'),
        ('223.255.255.255', '223.255.255.255'),
        ('240.0.0.1', '240.0.0.1'),
        ('0.0.0.1', '0.0.0.1'),
      ]) {
        expect(HostAddress.tryParse(input)?.value, value, reason: input);
      }
    });

    test('rejects everything else', () {
      for (final input in [
        '',
        '192.168.43',
        '192.168.43.1.1',
        '256.1.1.1',
        '1.2.3.1000',
        '1..2.3',
        'a.b.c.d',
        '0.0.0.0',
        '255.255.255.255',
        '224.0.0.1',
        '239.255.255.250',
        '::1',
      ]) {
        expect(HostAddress.tryParse(input), isNull, reason: input);
      }
    });

    test('compares by value', () {
      expect(
        HostAddress.tryParse('10.0.0.1'),
        HostAddress.tryParse(' 10.0.0.1'),
      );
    });
  });

  group('DisplayName', () {
    test('trims and accepts 1 to 32 characters', () {
      expect(DisplayName.tryParse('  Ana ')?.value, 'Ana');
      expect(DisplayName.tryParse('é' * 32)?.value, 'é' * 32);
    });

    test('rejects empty and long names', () {
      expect(DisplayName.tryParse('   '), isNull);
      expect(DisplayName.tryParse('a' * 33), isNull);
    });

    test('counts characters, not UTF-16 units', () {
      // 16 emoji = 32 UTF-16 code units, 16 characters.
      expect(DisplayName.tryParse('🏍' * 32), isNotNull);
      expect(DisplayName.tryParse('🏍' * 33), isNull);
    });

    test('compares by value', () {
      expect(DisplayName.tryParse('Ana'), DisplayName.tryParse('Ana '));
    });
  });
}
