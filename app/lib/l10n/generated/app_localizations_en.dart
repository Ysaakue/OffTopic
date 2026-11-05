// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OffTopic';

  @override
  String get homeTagline => 'Group voice room for riders, no internet needed';

  @override
  String homeCoreVersion(String version) {
    return 'Voice core $version';
  }

  @override
  String homeDevice(
    String manufacturer,
    String model,
    String osName,
    String osVersion,
  ) {
    return '$manufacturer $model · $osName $osVersion';
  }

  @override
  String get homeLoading => 'Checking the voice core…';

  @override
  String get homeCoreError => 'The voice core did not respond.';

  @override
  String get homePlatformError => 'Could not read the phone information.';

  @override
  String get retryButton => 'Try again';

  @override
  String get homeAudioTestButton => 'Audio test';

  @override
  String get audioTestTitle => 'Audio test';

  @override
  String get audioTestRoleHost => 'Host';

  @override
  String get audioTestRoleJoin => 'Join';

  @override
  String get audioTestHostIpLabel => 'Host IP address';

  @override
  String get audioTestInvalidHost =>
      'Type the host\'s IPv4 address, e.g. 192.168.43.1.';

  @override
  String get audioTestEchoMode => 'Echo mode';

  @override
  String get audioTestEchoModeHint =>
      'Returns your voice to the other phone, to measure the delay.';

  @override
  String get audioTestDefaultName => 'Rider';

  @override
  String get audioTestStart => 'Start';

  @override
  String get audioTestStop => 'Stop';

  @override
  String get audioTestStatusIdle => 'Stopped';

  @override
  String get audioTestStatusStarting => 'Starting…';

  @override
  String get audioTestStatusActive => 'Running';

  @override
  String get audioTestStatusStopping => 'Stopping…';

  @override
  String get audioTestLinkWaiting => 'Waiting for the other phone…';

  @override
  String audioTestLinkUp(String peer) {
    return 'Connected to $peer';
  }

  @override
  String audioTestLinkLost(String peer) {
    return 'Connection lost with $peer';
  }

  @override
  String get audioTestStatLoss => 'Loss';

  @override
  String get audioTestStatJitter => 'Jitter';

  @override
  String get audioTestStatBuffer => 'Jitter buffer';

  @override
  String get audioTestStatRtt => 'Round trip';

  @override
  String get audioTestStatInput => 'Microphone';

  @override
  String get audioTestStatPackets => 'Sent / received';

  @override
  String get audioTestStatLostLate => 'Lost / late';

  @override
  String get audioTestStatRecovered => 'FEC / concealed';

  @override
  String get audioTestStatUnderruns => 'Speaker underruns';

  @override
  String audioTestValuePercent(String value) {
    return '$value %';
  }

  @override
  String audioTestValueMs(String value) {
    return '$value ms';
  }

  @override
  String audioTestValueBuffer(String depth, String target) {
    return '$depth ms (target $target ms)';
  }

  @override
  String audioTestValuePair(String first, String second) {
    return '$first / $second';
  }

  @override
  String get audioTestValueUnknown => '—';

  @override
  String get audioTestErrorAlreadyActive => 'A test is already running.';

  @override
  String get audioTestErrorInvalidConfig =>
      'The voice core rejected the settings.';

  @override
  String get audioTestErrorAudioDevice =>
      'The microphone or the speaker could not be opened.';

  @override
  String get audioTestErrorNetwork =>
      'The network could not be opened. Check the Wi-Fi.';

  @override
  String get audioTestErrorUnavailable => 'The voice core is not available.';

  @override
  String get permissionDeniedTitle => 'Permission needed';

  @override
  String get permissionDeniedBody =>
      'OffTopic needs the microphone, the connection to your Bluetooth intercom and, from Android 17, access to devices on the local network to talk over the hotspot.';

  @override
  String get permissionOpenSettings => 'Open settings';

  @override
  String get talkModeLabel => 'Talk mode';

  @override
  String get talkModeVoice => 'Voice';

  @override
  String get talkModePushToTalk => 'Push to talk';

  @override
  String get vadSensitivityLabel => 'Voice detection';

  @override
  String get vadSensitivityLow => 'Low';

  @override
  String get vadSensitivityMedium => 'Medium';

  @override
  String get vadSensitivityHigh => 'High';

  @override
  String get talkSettingsSaveFailed =>
      'This setting could not be saved: it applies to this room only.';

  @override
  String get pushToTalkHold => 'Hold to talk';

  @override
  String get pushToTalkTalking => 'Talking…';

  @override
  String audioRouteLabel(String route) {
    return 'Audio: $route';
  }

  @override
  String get audioRouteIntercom => 'Intercom (Bluetooth)';

  @override
  String get audioRouteHeadset => 'Headset';

  @override
  String get audioRouteSpeaker => 'Loudspeaker';

  @override
  String get audioRouteEarpiece => 'Earpiece';

  @override
  String get audioRouteUnknown => 'not routed yet';

  @override
  String get talkingOnAir => 'Your microphone is on the air';

  @override
  String get talkingQuiet => 'Your microphone is quiet';

  @override
  String get audioCallModeSystem => 'Phone call mode: the intercom sees a call';

  @override
  String get audioCallModeDirect =>
      'Direct audio routing (the phone refused the call mode)';

  @override
  String get audioTestErrorEndedBySystem =>
      'The phone ended the room: another call, or the headset\'s hang-up button.';

  @override
  String get reportCopy => 'Copy report';

  @override
  String get reportCopied =>
      'Report copied: paste it in the chat with the developers.';

  @override
  String get hostAddressTitle => 'Your IP: the other riders type it to join';

  @override
  String hostAddressEntry(String network, String address) {
    return '$network: $address';
  }

  @override
  String get hostAddressHotspot => 'Hotspot';

  @override
  String get hostAddressWifi => 'Wi-Fi';

  @override
  String get hostAddressOther => 'Other network';

  @override
  String get hostAddressNone =>
      'No local network yet: turn on this phone\'s hotspot.';

  @override
  String get hostAddressUnavailable => 'Could not read this phone\'s IP.';

  @override
  String get hostAddressRefresh => 'Refresh IP';
}
