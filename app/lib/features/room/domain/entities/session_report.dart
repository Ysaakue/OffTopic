import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

/// Minimum, average and maximum of one measure over a session.
final class Spread extends Equatable {
  const new() : count = 0, _sum = 0, min = null, max = null;

  const new _(this.count, this._sum, this.min, this.max);

  final int count;
  final double _sum;
  final double? min;
  final double? max;

  double? get average => count == 0 ? null : _sum / count;

  Spread add(num value) {
    final sample = value.toDouble();
    return Spread._(
      count + 1,
      _sum + sample,
      math.min(min ?? sample, sample),
      math.max(max ?? sample, sample),
    );
  }

  @override
  List<Object?> get props => [count, _sum, min, max];
}

/// What happened during one room, for the rider to send to the developers:
/// the setup, the route, and how the link behaved. Built step by step from
/// the 4 Hz statistics and the room's events.
final class SessionReport extends Equatable {
  const new({
    required this.request,
    required this.talk,
    required this.startedAt,
    this.endedAt,
    this.appInfo,
    this.audio = const RoomAudio(),
    this.routes = const [],
    this.linkDrops = 0,
    this.delay = const Spread(),
    this.roundTrip = const Spread(),
    this.jitter = const Spread(),
    this.jitterBuffer = const Spread(),
    this.loss = const Spread(),
    this.last,
  });

  final RoomRequest request;
  final TalkSettings talk;
  final DateTime startedAt;
  final DateTime? endedAt;
  final AppInfo? appInfo;

  /// The latest route and call mode.
  final RoomAudio audio;

  /// Every route the room went through, in order.
  final List<AudioRoute> routes;

  /// Times the link to the other phone went down.
  final int linkDrops;

  final Spread delay;
  final Spread roundTrip;
  final Spread jitter;
  final Spread jitterBuffer;
  final Spread loss;

  /// The latest statistics (totals: packets, underruns...).
  final SessionStats? last;

  /// How long the room ran, up to [now] while it runs.
  Duration duration(DateTime now) => (endedAt ?? now).difference(startedAt);

  SessionReport withStats(SessionStats stats) {
    final estimate = stats.estimatedDelayMs;
    final rtt = stats.rttMs;
    return _copy(
      delay: estimate == null ? delay : delay.add(estimate),
      roundTrip: rtt == null ? roundTrip : roundTrip.add(rtt),
      jitter: jitter.add(stats.jitterMs),
      jitterBuffer: jitterBuffer.add(stats.jitterBufferMs),
      loss: loss.add(stats.lossPct),
      last: stats,
    );
  }

  SessionReport withAudio(RoomAudio newAudio) => _copy(
    audio: newAudio,
    routes: routes.isNotEmpty && routes.last == newAudio.route
        ? routes
        : [...routes, newAudio.route],
  );

  SessionReport withLink(RoomLink link) =>
      link.up ? this : _copy(linkDrops: linkDrops + 1);

  SessionReport withTalk(TalkSettings newTalk) => _copy(talk: newTalk);

  SessionReport withAppInfo(AppInfo info) => _copy(appInfo: info);

  SessionReport ended(DateTime at) => _copy(endedAt: at);

  SessionReport _copy({
    TalkSettings? talk,
    DateTime? endedAt,
    AppInfo? appInfo,
    RoomAudio? audio,
    List<AudioRoute>? routes,
    int? linkDrops,
    Spread? delay,
    Spread? roundTrip,
    Spread? jitter,
    Spread? jitterBuffer,
    Spread? loss,
    SessionStats? last,
  }) => SessionReport(
    request: request,
    talk: talk ?? this.talk,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    appInfo: appInfo ?? this.appInfo,
    audio: audio ?? this.audio,
    routes: routes ?? this.routes,
    linkDrops: linkDrops ?? this.linkDrops,
    delay: delay ?? this.delay,
    roundTrip: roundTrip ?? this.roundTrip,
    jitter: jitter ?? this.jitter,
    jitterBuffer: jitterBuffer ?? this.jitterBuffer,
    loss: loss ?? this.loss,
    last: last ?? this.last,
  );

  @override
  List<Object?> get props => [
    request,
    talk,
    startedAt,
    endedAt,
    appInfo,
    audio,
    routes,
    linkDrops,
    delay,
    roundTrip,
    jitter,
    jitterBuffer,
    loss,
    last,
  ];
}
