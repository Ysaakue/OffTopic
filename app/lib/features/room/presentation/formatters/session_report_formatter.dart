import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';

/// The report as plain text for the developers. It is a diagnostic record,
/// not interface copy: stable English keys, one fact per line, so reports
/// from riders in any language read the same.
final class SessionReportFormatter {
  const new();

  static const _decimals = 1;
  static const _secondsPerMinute = 60;
  static const _secondsWidth = 2;
  static const _separator = ' · ';

  String format(SessionReport report, DateTime now) {
    final out = StringBuffer()..writeln('OffTopic room report');
    final info = report.appInfo;
    if (info != null) {
      out.writeln(
        'device: ${info.manufacturer} ${info.model}$_separator'
        '${info.osName} ${info.osVersion}${_separator}core ${info.coreVersion}',
      );
    }
    final routes = report.routes.map((route) => route.name).join(' > ');
    out
      ..writeln('role: ${_role(report.request)}')
      ..writeln(
        'talk: ${report.talk.mode.name}$_separator'
        'sensitivity ${report.talk.sensitivity.name}',
      )
      ..writeln(
        'call mode: '
        '${report.audio.systemCall ? 'system call' : 'direct routing'}',
      )
      ..writeln('routes: ${routes.isEmpty ? 'none' : routes}')
      ..writeln(
        'duration: ${_duration(report.duration(now))}'
        '${report.endedAt == null ? ' (running)' : ''}',
      )
      ..writeln('link drops: ${report.linkDrops}')
      ..writeln(
        "delay estimate ms (network and buffers, without the phones' audio "
        'hardware): ${_spread(report.delay)}',
      )
      ..writeln('round trip ms: ${_spread(report.roundTrip)}')
      ..writeln('jitter ms: ${_spread(report.jitter)}')
      ..writeln('jitter buffer ms: ${_spread(report.jitterBuffer)}')
      ..writeln('loss %: ${_spread(report.loss)}');
    final last = report.last;
    if (last != null) {
      out
        ..writeln(
          'packets: sent ${last.packetsSent}${_separator}received '
          '${last.packetsReceived}${_separator}lost ${last.packetsLost}'
          '${_separator}late ${last.packetsLate}',
        )
        ..writeln(
          'recovered: fec ${last.fecRecovered}$_separator'
          'concealed ${last.concealedFrames}',
        )
        ..writeln(
          'audio: underruns ${last.playoutUnderruns}$_separator'
          'overruns ${last.captureOverruns}',
        );
    }
    return out.toString();
  }

  static String _role(RoomRequest request) => switch (request) {
    HostRoomRequest(:final echoMode) => echoMode ? 'host (echo mode)' : 'host',
    JoinRoomRequest(:final host) => 'client of ${host.value}',
  };

  static String _spread(Spread spread) {
    final min = spread.min;
    final average = spread.average;
    final max = spread.max;
    if (min == null || average == null || max == null) {
      return 'n/a';
    }
    return 'min ${_number(min)}${_separator}avg ${_number(average)}'
        '${_separator}max ${_number(max)}';
  }

  static String _number(double value) => value.toStringAsFixed(_decimals);

  static String _duration(Duration duration) {
    final seconds = duration.inSeconds % _secondsPerMinute;
    return '${duration.inMinutes}:'
        '${seconds.toString().padLeft(_secondsWidth, '0')}';
  }
}
