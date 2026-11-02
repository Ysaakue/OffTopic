import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';

/// Reads the core statistics at a fixed rate (docs/SPEC.md: 4 Hz).
///
/// The timer runs only while the returned stream has a listener; reads that
/// fail or find no session are skipped.
final class StatsPoller {
  const new({required this._read, this.interval = defaultInterval});

  /// 4 Hz.
  static const defaultInterval = Duration(milliseconds: 250);

  final Result<SessionStats?> Function() _read;

  /// Time between reads.
  final Duration interval;

  Stream<SessionStats> watch() => Stream<void>.periodic(interval).expand(
    (_) => switch (_read()) {
      Success(value: final stats?) => [stats],
      _ => const <SessionStats>[],
    },
  );
}
