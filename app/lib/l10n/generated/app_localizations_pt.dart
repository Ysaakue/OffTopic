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

  @override
  String get homeAudioTestButton => 'Teste de áudio';

  @override
  String get audioTestTitle => 'Teste de áudio';

  @override
  String get audioTestRoleHost => 'Anfitrião';

  @override
  String get audioTestRoleJoin => 'Entrar';

  @override
  String get audioTestHostIpLabel => 'IP do anfitrião';

  @override
  String get audioTestInvalidHost =>
      'Digite o IPv4 do anfitrião, por exemplo 192.168.43.1.';

  @override
  String get audioTestEchoMode => 'Modo eco';

  @override
  String get audioTestEchoModeHint =>
      'Devolve a voz ao outro celular, para medir o atraso.';

  @override
  String get audioTestDefaultName => 'Piloto';

  @override
  String get audioTestStart => 'Iniciar';

  @override
  String get audioTestStop => 'Parar';

  @override
  String get audioTestStatusIdle => 'Parado';

  @override
  String get audioTestStatusStarting => 'Iniciando…';

  @override
  String get audioTestStatusActive => 'Em andamento';

  @override
  String get audioTestStatusStopping => 'Parando…';

  @override
  String get audioTestLinkWaiting => 'Aguardando o outro celular…';

  @override
  String audioTestLinkUp(String peer) {
    return 'Conectado a $peer';
  }

  @override
  String audioTestLinkLost(String peer) {
    return 'Conexão perdida com $peer';
  }

  @override
  String get audioTestStatLoss => 'Perda';

  @override
  String get audioTestStatJitter => 'Jitter';

  @override
  String get audioTestStatBuffer => 'Jitter buffer';

  @override
  String get audioTestStatRtt => 'Ida e volta';

  @override
  String get audioTestStatInput => 'Microfone';

  @override
  String get audioTestStatPackets => 'Enviados / recebidos';

  @override
  String get audioTestStatLostLate => 'Perdidos / atrasados';

  @override
  String get audioTestStatRecovered => 'FEC / ocultados';

  @override
  String get audioTestStatUnderruns => 'Faltas no alto-falante';

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
    return '$depth ms (alvo $target ms)';
  }

  @override
  String audioTestValuePair(String first, String second) {
    return '$first / $second';
  }

  @override
  String get audioTestValueUnknown => '—';

  @override
  String get audioTestErrorAlreadyActive => 'Já existe um teste em andamento.';

  @override
  String get audioTestErrorInvalidConfig =>
      'O núcleo de voz recusou as configurações.';

  @override
  String get audioTestErrorAudioDevice =>
      'Não foi possível abrir o microfone ou o alto-falante.';

  @override
  String get audioTestErrorNetwork =>
      'Não foi possível abrir a rede. Confira o Wi-Fi.';

  @override
  String get audioTestErrorUnavailable =>
      'O núcleo de voz não está disponível.';

  @override
  String get permissionDeniedTitle => 'Permissão necessária';

  @override
  String get permissionDeniedBody =>
      'O OffTopic precisa do microfone, da conexão com o seu intercomunicador Bluetooth e, a partir do Android 17, do acesso a dispositivos na rede local para conversar pelo hotspot.';

  @override
  String get permissionOpenSettings => 'Abrir configurações';

  @override
  String get talkModeLabel => 'Modo de fala';

  @override
  String get talkModeVoice => 'Voz';

  @override
  String get talkModePushToTalk => 'Apertar para falar';

  @override
  String get vadSensitivityLabel => 'Detecção de voz';

  @override
  String get vadSensitivityLow => 'Baixa';

  @override
  String get vadSensitivityMedium => 'Média';

  @override
  String get vadSensitivityHigh => 'Alta';

  @override
  String get talkSettingsSaveFailed =>
      'Não foi possível salvar esta configuração: ela vale só para esta sala.';

  @override
  String get pushToTalkHold => 'Segure para falar';

  @override
  String get pushToTalkTalking => 'Falando…';

  @override
  String audioRouteLabel(String route) {
    return 'Áudio: $route';
  }

  @override
  String get audioRouteIntercom => 'Intercomunicador (Bluetooth)';

  @override
  String get audioRouteHeadset => 'Fone de ouvido';

  @override
  String get audioRouteSpeaker => 'Alto-falante';

  @override
  String get audioRouteEarpiece => 'Alto-falante de ouvido';

  @override
  String get audioRouteUnknown => 'ainda sem rota';

  @override
  String get talkingOnAir => 'Seu microfone está no ar';

  @override
  String get talkingQuiet => 'Seu microfone está em silêncio';

  @override
  String get audioCallModeSystem =>
      'Modo chamada do celular: o intercomunicador vê uma ligação';

  @override
  String get audioCallModeDirect =>
      'Roteamento direto do áudio (o celular recusou o modo chamada)';

  @override
  String get audioTestErrorEndedBySystem =>
      'O celular encerrou a sala: outra ligação ou o botão de desligar do fone.';

  @override
  String get reportCopy => 'Copiar relatório';

  @override
  String get reportCopied =>
      'Relatório copiado: cole na conversa com os desenvolvedores.';

  @override
  String get hostAddressTitle =>
      'Seu IP: os outros pilotos digitam este para entrar';

  @override
  String hostAddressEntry(String network, String address) {
    return '$network: $address';
  }

  @override
  String get hostAddressHotspot => 'Hotspot';

  @override
  String get hostAddressWifi => 'Wi-Fi';

  @override
  String get hostAddressOther => 'Outra rede';

  @override
  String get hostAddressNone =>
      'Nenhuma rede local ainda: ligue o hotspot deste celular.';

  @override
  String get hostAddressUnavailable =>
      'Não foi possível ler o IP deste celular.';

  @override
  String get hostAddressRefresh => 'Atualizar IP';
}
