// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'OffTopic';

  @override
  String get homeTagline =>
      'Sala de voz em grupo para motociclistas, sem internet';

  @override
  String homeCoreVersion(String version) {
    return 'Núcleo de voz $version';
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
  String get homeLoading => 'Verificando o núcleo de voz…';

  @override
  String get homeCoreError => 'O núcleo de voz não respondeu.';

  @override
  String get homePlatformError =>
      'Não foi possível ler as informações do celular.';

  @override
  String get retryButton => 'Tentar de novo';
}
