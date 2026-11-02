import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/presentation/controllers/stats_poller.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  test('reads four times per second', () {
    fakeAsync((async) {
      var reads = 0;
      final poller = StatsPoller(
        read: () {
          reads++;
          return const Success(sampleSessionStats);
        },
      );
      final received = <SessionStats>[];
      poller.watch().listen(received.add);

      async.elapse(const Duration(seconds: 1));

      expect(reads, 4);
      expect(received, List.filled(4, sampleSessionStats));
      expect(StatsPoller.defaultInterval, const Duration(milliseconds: 250));
    });
  });

  test('stops reading when the listener goes away', () {
    fakeAsync((async) {
      var reads = 0;
      final subscription = StatsPoller(
        read: () {
          reads++;
          return const Success(sampleSessionStats);
        },
      ).watch().listen((_) {});
      async.elapse(const Duration(milliseconds: 500));

      unawaited(subscription.cancel());
      async.elapse(const Duration(seconds: 2));

      expect(reads, 2);
    });
  });

  test('skips reads without a session or with a failure', () {
    fakeAsync((async) {
      final answers = <Result<SessionStats?>>[
        const Success(null),
        const Failure(CoreFailure('x')),
        const Success(sampleSessionStats),
      ];
      final received = <SessionStats>[];
      StatsPoller(
        read: () => answers.removeAt(0),
        interval: const Duration(milliseconds: 10),
      ).watch().listen(received.add);

      async.elapse(const Duration(milliseconds: 30));

      expect(received, [sampleSessionStats]);
    });
  });
}
