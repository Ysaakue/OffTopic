import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Application name, shown in the app bar and task switcher.
  ///
  /// In en, this message translates to:
  /// **'OffTopic'**
  String get appTitle;

  /// One-line description under the app name on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Group voice room for riders, no internet needed'**
  String get homeTagline;

  /// Version of the native voice core.
  ///
  /// In en, this message translates to:
  /// **'Voice core {version}'**
  String homeCoreVersion(String version);

  /// Device summary: manufacturer, model, operating system and its version.
  ///
  /// In en, this message translates to:
  /// **'{manufacturer} {model} · {osName} {osVersion}'**
  String homeDevice(
    String manufacturer,
    String model,
    String osName,
    String osVersion,
  );

  /// Shown while the home screen reads the core and device information.
  ///
  /// In en, this message translates to:
  /// **'Checking the voice core…'**
  String get homeLoading;

  /// Error shown when the native voice core cannot be read.
  ///
  /// In en, this message translates to:
  /// **'The voice core did not respond.'**
  String get homeCoreError;

  /// Error shown when the platform layer (Android or iOS) fails.
  ///
  /// In en, this message translates to:
  /// **'Could not read the phone information.'**
  String get homePlatformError;

  /// Button that repeats a failed operation.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryButton;

  /// Home button that opens the phase 1 audio test.
  ///
  /// In en, this message translates to:
  /// **'Audio test'**
  String get homeAudioTestButton;

  /// Title of the two-phone audio test screen.
  ///
  /// In en, this message translates to:
  /// **'Audio test'**
  String get audioTestTitle;

  /// Segment: this phone hosts the test.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get audioTestRoleHost;

  /// Segment: this phone joins a host.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get audioTestRoleJoin;

  /// Label of the host address field.
  ///
  /// In en, this message translates to:
  /// **'Host IP address'**
  String get audioTestHostIpLabel;

  /// Error under the host address field.
  ///
  /// In en, this message translates to:
  /// **'Type the host\'s IPv4 address, e.g. 192.168.43.1.'**
  String get audioTestInvalidHost;

  /// Switch title: the host returns the caller's own voice.
  ///
  /// In en, this message translates to:
  /// **'Echo mode'**
  String get audioTestEchoMode;

  /// Switch subtitle explaining echo mode.
  ///
  /// In en, this message translates to:
  /// **'Returns your voice to the other phone, to measure the delay.'**
  String get audioTestEchoModeHint;

  /// Name sent to the core until the name screen exists (phase 3).
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get audioTestDefaultName;

  /// Button that starts the audio test.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get audioTestStart;

  /// Button that stops the audio test.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get audioTestStop;

  /// Status: no test running.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get audioTestStatusIdle;

  /// Status: the test is starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get audioTestStatusStarting;

  /// Status: the test is running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get audioTestStatusActive;

  /// Status: the test is stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get audioTestStatusStopping;

  /// No packet from the other phone yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other phone…'**
  String get audioTestLinkWaiting;

  /// The other phone is reachable.
  ///
  /// In en, this message translates to:
  /// **'Connected to {peer}'**
  String audioTestLinkUp(String peer);

  /// The other phone stopped answering.
  ///
  /// In en, this message translates to:
  /// **'Connection lost with {peer}'**
  String audioTestLinkLost(String peer);

  /// Statistic: packet loss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get audioTestStatLoss;

  /// Statistic: network jitter.
  ///
  /// In en, this message translates to:
  /// **'Jitter'**
  String get audioTestStatJitter;

  /// Statistic: buffered audio and its target.
  ///
  /// In en, this message translates to:
  /// **'Jitter buffer'**
  String get audioTestStatBuffer;

  /// Statistic: keepalive round-trip time.
  ///
  /// In en, this message translates to:
  /// **'Round trip'**
  String get audioTestStatRtt;

  /// Statistic: microphone level.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get audioTestStatInput;

  /// Statistic: packets sent and received.
  ///
  /// In en, this message translates to:
  /// **'Sent / received'**
  String get audioTestStatPackets;

  /// Statistic: packets lost and late.
  ///
  /// In en, this message translates to:
  /// **'Lost / late'**
  String get audioTestStatLostLate;

  /// Statistic: frames rebuilt by FEC and concealed.
  ///
  /// In en, this message translates to:
  /// **'FEC / concealed'**
  String get audioTestStatRecovered;

  /// Statistic: times the speaker ran out of audio.
  ///
  /// In en, this message translates to:
  /// **'Speaker underruns'**
  String get audioTestStatUnderruns;

  /// A percentage value.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String audioTestValuePercent(String value);

  /// A duration in milliseconds.
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String audioTestValueMs(String value);

  /// Buffered audio and its target.
  ///
  /// In en, this message translates to:
  /// **'{depth} ms (target {target} ms)'**
  String audioTestValueBuffer(String depth, String target);

  /// Two counters side by side.
  ///
  /// In en, this message translates to:
  /// **'{first} / {second}'**
  String audioTestValuePair(String first, String second);

  /// A value not measured yet.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get audioTestValueUnknown;

  /// Error: a room is already running.
  ///
  /// In en, this message translates to:
  /// **'A test is already running.'**
  String get audioTestErrorAlreadyActive;

  /// Error: invalid configuration.
  ///
  /// In en, this message translates to:
  /// **'The voice core rejected the settings.'**
  String get audioTestErrorInvalidConfig;

  /// Error: audio device.
  ///
  /// In en, this message translates to:
  /// **'The microphone or the speaker could not be opened.'**
  String get audioTestErrorAudioDevice;

  /// Error: network socket.
  ///
  /// In en, this message translates to:
  /// **'The network could not be opened. Check the Wi-Fi.'**
  String get audioTestErrorNetwork;

  /// Error: any other failure.
  ///
  /// In en, this message translates to:
  /// **'The voice core is not available.'**
  String get audioTestErrorUnavailable;

  /// Title when a room permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get permissionDeniedTitle;

  /// Why the permissions are needed.
  ///
  /// In en, this message translates to:
  /// **'OffTopic needs the microphone, the connection to your Bluetooth intercom and, from Android 17, access to devices on the local network to talk over the hotspot.'**
  String get permissionDeniedBody;

  /// Button that opens the app settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionOpenSettings;

  /// Title of the choice between the voice detector and push to talk.
  ///
  /// In en, this message translates to:
  /// **'Talk mode'**
  String get talkModeLabel;

  /// Talk mode: the microphone opens when the rider speaks.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get talkModeVoice;

  /// Talk mode: the microphone opens only while a button is held.
  ///
  /// In en, this message translates to:
  /// **'Push to talk'**
  String get talkModePushToTalk;

  /// Title of the voice detector sensitivity choice.
  ///
  /// In en, this message translates to:
  /// **'Voice detection'**
  String get vadSensitivityLabel;

  /// Voice detector sensitivity: needs clear speech, best in strong wind.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get vadSensitivityLow;

  /// Voice detector sensitivity: the default.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get vadSensitivityMedium;

  /// Voice detector sensitivity: also opens on quiet speech.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get vadSensitivityHigh;

  /// Shown when a talk setting could not be stored on the phone.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be saved: it applies to this room only.'**
  String get talkSettingsSaveFailed;

  /// Label of the big push-to-talk button while it is released.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get pushToTalkHold;

  /// Label of the big push-to-talk button while it is held.
  ///
  /// In en, this message translates to:
  /// **'Talking…'**
  String get pushToTalkTalking;

  /// Where the room is heard and spoken into.
  ///
  /// In en, this message translates to:
  /// **'Audio: {route}'**
  String audioRouteLabel(String route);

  /// Audio route: the rider's Bluetooth intercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom (Bluetooth)'**
  String get audioRouteIntercom;

  /// Audio route: a wired or USB headset.
  ///
  /// In en, this message translates to:
  /// **'Headset'**
  String get audioRouteHeadset;

  /// Audio route: the phone's loudspeaker.
  ///
  /// In en, this message translates to:
  /// **'Loudspeaker'**
  String get audioRouteSpeaker;

  /// Audio route: the phone's earpiece.
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get audioRouteEarpiece;

  /// Audio route not known yet.
  ///
  /// In en, this message translates to:
  /// **'not routed yet'**
  String get audioRouteUnknown;

  /// The local microphone is being sent to the room.
  ///
  /// In en, this message translates to:
  /// **'Your microphone is on the air'**
  String get talkingOnAir;

  /// The local microphone is not being sent (no voice, button released or muted).
  ///
  /// In en, this message translates to:
  /// **'Your microphone is quiet'**
  String get talkingQuiet;

  /// The room is registered as a call with the phone, so the Bluetooth intercom treats it like a phone call.
  ///
  /// In en, this message translates to:
  /// **'Phone call mode: the intercom sees a call'**
  String get audioCallModeSystem;

  /// The phone did not accept the room as a call; the audio is only routed.
  ///
  /// In en, this message translates to:
  /// **'Direct audio routing (the phone refused the call mode)'**
  String get audioCallModeDirect;

  /// Shown when the system ended the room's call.
  ///
  /// In en, this message translates to:
  /// **'The phone ended the room: another call, or the headset\'s hang-up button.'**
  String get audioTestErrorEndedBySystem;

  /// Button that copies the room's report (delay, losses, route) to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get reportCopy;

  /// Confirmation after copying the room's report.
  ///
  /// In en, this message translates to:
  /// **'Report copied: paste it in the chat with the developers.'**
  String get reportCopied;

  /// Heading above the host phone's own IP addresses.
  ///
  /// In en, this message translates to:
  /// **'Your IP: the other riders type it to join'**
  String get hostAddressTitle;

  /// One of the host phone's IP addresses and the network it belongs to, e.g. 'Hotspot: 192.168.43.1'.
  ///
  /// In en, this message translates to:
  /// **'{network}: {address}'**
  String hostAddressEntry(String network, String address);

  /// Network kind: this phone's own Wi-Fi hotspot.
  ///
  /// In en, this message translates to:
  /// **'Hotspot'**
  String get hostAddressHotspot;

  /// Network kind: a Wi-Fi network this phone joined.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get hostAddressWifi;

  /// Network kind: another local network (USB or Ethernet tethering).
  ///
  /// In en, this message translates to:
  /// **'Other network'**
  String get hostAddressOther;

  /// The host phone has no address the other riders can reach.
  ///
  /// In en, this message translates to:
  /// **'No local network yet: turn on this phone\'s hotspot.'**
  String get hostAddressNone;

  /// The phone's network interfaces could not be listed.
  ///
  /// In en, this message translates to:
  /// **'Could not read this phone\'s IP.'**
  String get hostAddressUnavailable;

  /// Button that reads the host phone's IP addresses again.
  ///
  /// In en, this message translates to:
  /// **'Refresh IP'**
  String get hostAddressRefresh;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
