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
}
