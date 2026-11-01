import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';

void main() {
  group('Result', () {
    test('Success carries its value and compares by value', () {
      const result = Success(42);

      expect(result.value, 42);
      expect(result, const Success(42));
      expect(result, isNot(const Success(7)));
    });

    test('Failure carries its failure and compares by value', () {
      const result = Failure<int>(CoreFailure('down'));

      expect(result.failure, const CoreFailure('down'));
      expect(result, const Failure<int>(CoreFailure('down')));
      expect(result, isNot(const Failure<int>(CoreFailure('other'))));
    });

    test('can be matched exhaustively', () {
      String describe(Result<int> result) => switch (result) {
        Success(:final value) => 'ok $value',
        Failure(:final failure) => 'failed ${failure.message}',
      };

      expect(describe(const Success(1)), 'ok 1');
      expect(describe(const Failure(CoreFailure('x'))), 'failed x');
    });
  });
}
