# Plano de implantação — OffTopic (sala de voz para motos)

## Contexto

O repositório `OffTopic` só tem a especificação (`docs/Sala de voz para motos — especificação para o Claude Code.md`, staged e sem nenhum commit). O objetivo é implementar o app descrito ali: uma sala de voz para 2 a 8 motociclistas, sem internet. Cada intercom se liga por Bluetooth HFP ao celular do próprio piloto, e os celulares trocam o áudio por UDP pelo hotspot de um deles. O anfitrião faz a mixagem mix-minus.

Requisitos adicionais do usuário:
- **Flutter**, com **todo o código em inglês**: identificadores, comentários, mensagens de commit, `CLAUDE.md` e `PROTOCOL.md`. A `SPEC.md` continua em português, como foi escrita. Os textos da interface ficam em ARB (`en` como base, `pt` como tradução), então nenhuma string fica fixa no código.
- **SOLID** e **Effective Dart / código limpo**. O mesmo rigor vale para C++ e Kotlin.
- **Android primeiro**, mas com tudo pronto para o iOS (fase 7) sem precisar refatorar.

Decisões já tomadas: nome do pacote `offtopic`, applicationId `com.isaacgeraldo.offtopic` e pacote Kotlin `com.isaacgeraldo.offtopic.voiceplatform`. O núcleo C++ é testado no desktop pelo **WSL2 + Ubuntu**.

Ambiente instalado hoje: Flutter 3.41.9 (Dart 3.11.5), NDK 28.2, CMake 3.22.1, plataforma 36.1 e JBR 21. **Está desatualizado**; as versões-alvo estão na seção abaixo, conferidas em 30/10/2026.

**Versão do Flutter pelo FVM:** o projeto fixa a sua versão do Flutter num `.fvmrc` versionado, e todos os comandos usam `fvm flutter …` e `fvm dart …`. O Flutter global da máquina não é atualizado, então outros projetos continuam na versão deles.

---

## Versões (as mais recentes compatíveis, conferidas em 30/10/2026)

Critério: a versão estável mais nova de cada item. Quando o Flutter limita a escolha, vale a maior versão que o `flutter_tools` 3.47.9 declara suportada (`gradle_utils.dart`: `maxKnownAndSupported*`). Versões acima disso são aceitas pelo Flutter só com um aviso, sem teste deles.

| Item | Instalado | Mais recente | **Usar** | Motivo |
| --- | --- | --- | --- | --- |
| Flutter / Dart | 3.41.9 / 3.11.5 | 3.47.9 / 3.13.7 | **3.47.9 / 3.13.7, fixada pelo FVM** | `very_good_analysis` 11 exige Dart ^3.13; Riverpod 3.4 e go_router 18 exigem ^3.12 |
| FVM | — | 4.3.2 | **4.3.2** | Versão do Flutter por projeto (`.fvmrc`), sem mexer no SDK global nem nos outros projetos |
| Gradle | — | 9.8.2 | **9.3.1** | Maior versão suportada pelo Flutter 3.47.9 |
| Android Gradle Plugin | — | 9.5.0 | **9.1.1** | O 9.2.1 exige Gradle ≥ 9.4.1, acima do 9.3.1 que o Flutter suporta (verificado na fase 0). O 9.1.1 é o patch mais novo da linha 9.1, a de "suporte completo a Kotlin" no Flutter |
| Kotlin Gradle Plugin | — | 2.4.21 | **2.4.0** | Maior versão conhecida pelo Flutter (é a do template) |
| compileSdk / targetSdk | 36 | 37 (Android 17) | **37 / 37** | `permission_handler_android` 14 já exige compileSdk 37. Ver a regra de `ACCESS_LOCAL_NETWORK` abaixo |
| minSdk | — | — | **29** | Exigência da spec |
| Build-tools | 36.1.0 | 37.0.0 | **37.0.0** | |
| NDK | 28.2.13676358 | 30.0.16248370 (r30) | **30.0.16248370** | Funciona com qualquer AGP via `ndkVersion`; páginas de 16 KB por padrão |
| CMake (Android e WSL) | 3.22.1 | 4.1.2 | **4.1.2** | Mesma versão nos dois ambientes. Todas as dependências declaram mínimo ≥ 3.5, compatível com o CMake 4 |
| JDK | JBR 21 | 25 LTS | **21 (JBR do Android Studio)** | É o JDK que o Flutter usa por padrão, e o Robolectric do SDK 37 exige Java 21. O `JAVA_HOME` do sistema aponta para um JDK 17, então o `verify.ps1` aponta o Gradle para o JDK que o `flutter doctor` informa |
| WSL | só docker-desktop | Ubuntu 26.04 LTS | **Ubuntu-26.04** | |
| Padrão C++ | — | — | **C++17** | O webrtc-apm 2.1 exige o Abseil compilado com o mesmo padrão, e o padrão dele é C++17 |

Submódulos C/C++, cada um com a tag fixada em `.gitmodules` e em `docs/DEPENDENCIES.md`:

| Biblioteca | Tag | Fase |
| --- | --- | --- |
| miniaudio | `0.11.25` | 1 |
| opus | `v1.6.1` | 1 |
| googletest | `v1.18.0` | 0 |
| nlohmann/json | `v3.12.0` | 3 |
| webrtc-audio-processing | `v2.1` | 2 |
| abseil-cpp | `20260817.0` (o webrtc-apm 2.1 pede ≥ 20240722; se a LTS nova quebrar, por exemplo pelo alvo `absl_bad_optional_access`, cair para a LTS mais nova que compilar) | 2 |
| oboe (só se o miniaudio falhar no SCO) | `1.11.0` | 2 |

Pacotes pub, todos na versão mais recente e compatíveis com Dart 3.13:

| Pacote | Versão | Uso |
| --- | --- | --- |
| `flutter_riverpod` | ^3.4.3 | Estado e injeção de dependência |
| `go_router` | ^18.1.2 | Navegação |
| `shared_preferences` | ^2.5.6 | Nome, configurações e `device_id` |
| `equatable` | ^3.0.0 | Igualdade de valor |
| `permission_handler` | ^13.0.2 | Permissões. A implementação Android já tem `ACCESS_LOCAL_NETWORK` |
| `mobile_scanner` | ^7.4.2 | Leitura de QR |
| `qr` | ^4.0.1 | Codificação QR. **Substitui o `qr_flutter`**, sem versão desde 05/2023, o que viola a regra de manutenção da spec. O desenho é um `QrCodeView` próprio com `CustomPainter` |
| `ffi` | ^2.2.0 | FFI |
| `ffigen` (dev) | ^23.0.0 | Bindings C |
| `pigeon` (dev) | ^29.1.0 | Canais Kotlin e Swift |
| `very_good_analysis` (dev) | ^11.0.0 | Lints |
| `mocktail` (dev) | ^1.0.5 | Mocks |
| `fake_async` (dev) | ^1.3.3 | Controle de timers nos testes (polling a 4 Hz, backoff) |
| `intl` | versão fixada pelo `flutter_localizations` | l10n |

Regra contínua: ao iniciar cada fase, rodar `fvm flutter pub outdated`, `fvm releases` (para ver se há Flutter estável mais novo) e conferir as tags dos submódulos. Mudar a versão do Flutter é um `fvm use <versão>` num commit próprio. Atualizar só quando a compatibilidade estiver documentada, e registrar em `docs/DEPENDENCIES.md`.

### Consequência do targetSdk 37: permissão de rede local (Android 17)
Num app com targetSdk 37, o sistema **bloqueia todo o tráfego de rede local**, inclusive o dos sockets do NDK: TCP de saída e de entrada, UDP unicast e broadcast, e mDNS. A exceção é quem tem a permissão de tempo de execução `ACCESS_LOCAL_NETWORK`, que pertence ao grupo `NEARBY_DEVICES`, o mesmo do `BLUETOOTH_CONNECT`. A spec não lista essa permissão, então ela entra como **adição obrigatória**:
- Declarar `ACCESS_LOCAL_NETWORK` no manifesto e pedi-la na mesma etapa do `BLUETOOTH_CONNECT` (mesmo grupo, uma única concessão), sempre antes de iniciar a sala.
- Se for negada, a sala não inicia e uma tela explica o motivo, com atalho para as configurações do app. A reconexão nunca fica tentando contra uma permissão negada.
- No diagnóstico, o C++ chama `android_getnetworkblockedreason()` para distinguir "bloqueado pela permissão" de "fora de alcance". Os sintomas típicos são `EPERM` no UDP e timeout no TCP.
- Registrar essa adição num adendo da `SPEC.md` e no `CLAUDE.md`.
- Em aparelhos com Android 16, o comportamento pode ser testado antes com `adb shell am compat enable RESTRICT_LOCAL_NETWORK com.isaacgeraldo.offtopic`.

---

## Decisões transversais (complementam a spec)

### 1. Duas portas de entrada para o mesmo `libvoice_core.so`
A spec diz que o service "carrega a biblioteca nativa e inicia o núcleo", e que a sala precisa sobreviver com a interface fechada. Por isso:
- **Kotlin → C++ via JNI** cuida do ciclo de vida e de tudo que muda a notificação: `init/start/stop`, `setNetworkHandle`, `pause/resume` (foco de áudio) e `setMute` (o botão da notificação).
- **Dart → C++ via FFI** cuida das leituras e dos controles finos: `vc_version`, `vc_get_stats` (4 Hz), eventos, snapshot, PTT, ganho de saída e sensibilidade do VAD.
- O mute pedido pelo Dart passa pelo Pigeon e chega ao Kotlin, que atualiza a notificação e chama o núcleo via JNI. O núcleo emite `mute_changed`, o que deixa uma única fonte de verdade.
- `src/platform/android/jni_bridge.cpp` usa `JNI_OnLoad` + `RegisterNatives` e aponta para `com.isaacgeraldo.offtopic.voiceplatform.core.NativeVoiceCore`. O nome da classe fica numa única constante.
- A API C é thread-safe, porque é chamada pelo main thread do Kotlin e pelo isolate do Dart.

### 2. Eventos via `NativeCallable.listener` (armadilha identificada)
O listener é assíncrono: o `const char* json` precisa continuar válido depois que a chamada nativa retorna. Regra: o núcleo aloca o payload e o Dart chama `vc_free_event_payload(ptr)` depois de decodificar. Quando a interface fecha, o Dart chama `vc_set_event_callback(NULL)`. Ao reabrir, chama `vc_get_snapshot_json()` para reconstruir a lista de participantes e o estado.

### 3. Extensões da API C (a spec chama a dela de "ponto de partida")
Entram `vc_version`, `vc_free_event_payload`, `vc_get_snapshot_json`, `vc_pause`/`vc_resume`, `vc_set_talk_mode`, `vc_set_vad_sensitivity` e `vc_set_echo_mode` (para medir RTT). A `vc_config` passa a espelhar a `CoreConfig` única: taxa, quadro, bitrate, limites do jitter buffer, portas e perda esperada do FEC.

### 4. Arquitetura Dart (clean architecture por feature + SOLID)
- `features/<x>/domain`: entidades imutáveis, contratos de repositório (abstratos) e casos de uso. Nada aqui importa Flutter, FFI ou Pigeon.
- `features/<x>/data`: implementações dos repositórios que adaptam `VoiceCoreClient` e `VoicePlatformGateway`, além de mappers de evento para entidade.
- `features/<x>/presentation`: telas, widgets e controllers (`Notifier`/`AsyncNotifier` do Riverpod 3, sem codegen).
- Como o SOLID se aplica aqui:
  - **S**: uma responsabilidade por classe.
  - **O**: estratégias escolhidas por fábrica, como `AudioRouter` por nível de API, `Session` por papel e `HostDiscovery` por plataforma.
  - **L**: os fakes de teste e a futura implementação iOS cumprem os mesmos contratos.
  - **I**: interfaces pequenas, como `VoiceCoreStats`, `VoiceCoreEvents` e `VoiceCoreControls`, e `RoomCommands` separado de `RoomStateSource`.
  - **D**: casos de uso dependem de abstrações, e os providers do Riverpod injetam as implementações.
- Código limpo:
  - `very_good_analysis`, com `public_member_api_docs` desligado só no app, e `strict-casts`, `strict-inference` e `strict-raw-types`.
  - `dart format`, um tipo público por arquivo, sem `dynamic`, sem números mágicos (constantes nomeadas) e funções curtas.
  - `sealed class` para eventos e estados, com `switch` exaustivo, e `Result<T>` (`Success`/`Failure`) para erros entre camadas.
  - `equatable` para igualdade de valor. O único codegen é ffigen + Pigeon.
- Pacotes: os da tabela de versões. São os da spec, com `qr` no lugar do `qr_flutter`, mais `go_router`, `shared_preferences`, `equatable`, `mocktail` e `very_good_analysis`. "Manter tela ligada" e o ID do dispositivo são feitos em código próprio: o primeiro pelo Pigeon com `FLAG_KEEP_SCREEN_ON`, o segundo com `Random.secure` persistido.

### 5. Arquitetura C++ (C++17)
Interfaces injetadas pelo construtor: `IAudioDevice` (miniaudio, Oboe como plano B, fake para testes), `IAudioProcessor` (webrtc APM, passthrough), `INetworkBinder` (Android via `android_setsocknetwork`, no-op nas outras plataformas), `IClock` e `IEventSink`. `HostSession` e `ClientSession` implementam `ISession`. Os sockets são só POSIX. Nada específico do Android sai de `src/platform/android/`. A `CoreConfig` é a única struct de parâmetros. RAII em todo recurso (encoder, decoder, socket). Formatação com `.clang-format` (Google) e análise com `.clang-tidy`.

### 6. Kotlin
Mesmo critério:
- `AudioRouter` (interface) com as implementações `CommunicationDeviceRouter` (API 31+) e `LegacyScoRouter` (API 29–30), escolhidas por `AudioRouterFactory`.
- Classes separadas para serviço, notificação, Wi-Fi, wake lock, foco de áudio e bateria.
- `if (Build.VERSION.SDK_INT >= …)` só dentro das fábricas, que recebem o `SdkLevel` por injeção para que cada ramo seja testável.
- Serviços do sistema (`AudioManager`, `ConnectivityManager`, `WifiManager`, `PowerManager`) só por fachadas finas. Toda a lógica é JVM pura e testável com MockK.
- ktlint via Gradle.

### 7. Prontidão para iOS (vira regra no `CLAUDE.md`)
- O app e os dois plugins são criados com `--platforms=android,ios` desde a fase 0.
- O Pigeon gera Kotlin, Swift e Dart a partir de uma única fonte. O host Swift vira um stub que compila e responde `unsupported`.
- `VoiceCoreLibraryLoader` encapsula o carregamento: `DynamicLibrary.open('libvoice_core.so')` no Android e `DynamicLibrary.process()` no iOS.
- `PlatformCapabilities` (`canHostRoom`, `supportsGatewayDiscovery`, `supportsHotspotSettings`, `supportsBatteryExemption`) vem do gateway. A interface consulta essas capacidades e nunca usa `Platform.isAndroid` em widgets ou casos de uso.
- `HostDiscovery` tem duas estratégias: `GatewayHostDiscovery` (Android) e `QrHostDiscovery` (as duas plataformas).
- `PermissionService` é um contrato de domínio, porque cada sistema pede um conjunto diferente de permissões.
- Não dá para compilar iOS no Windows. A fase 7 exige um Mac ou um runner macOS de CI.

---

## Estrutura do repositório (raiz = `OffTopic/`)

```
OffTopic/
├── CLAUDE.md                     # regras da spec + regras deste plano + comandos
├── .fvmrc                        # {"flutter": "3.47.9"}; vale para app/ e packages/*
├── pubspec.yaml                  # pub workspace: app, packages/*
├── analysis_options.yaml         # very_good_analysis + modos estritos
├── .gitmodules  .clang-format  .clang-tidy  .editorconfig
├── app/                          # pacote Dart "offtopic"
│   ├── l10n.yaml  lib/l10n/app_en.arb  lib/l10n/app_pt.arb
│   ├── lib/
│   │   ├── main.dart  app.dart
│   │   ├── core/ di/ theme/ routing/ result/ widgets/ permissions/
│   │   └── features/
│   │       ├── home/       presentation/
│   │       ├── room/       domain/ data/ presentation/
│   │       ├── settings/   domain/ data/ presentation/
│   │       └── diagnostics/presentation/
│   ├── test/                     # espelha lib/ + fakes/ + contracts/
│   ├── integration_test/
│   ├── android/  ios/
├── packages/
│   ├── voice_core/               # plugin FFI (ffiPlugin: android, ios)
│   │   ├── ffigen.yaml  CMakeLists.txt  CMakePresets.json
│   │   ├── include/voice_core.h
│   │   ├── lib/voice_core.dart  lib/src/{bindings.g.dart, voice_core_client.dart,
│   │   │      ffi_voice_core_client.dart, library_loader.dart, models/, event_decoder.dart}
│   │   ├── src/ api/ config/ audio/ dsp/ codec/ jitter/ mixer/ net/ session/ events/
│   │   │        platform/android/{jni_bridge.cpp, android_network_binder.cpp}
│   │   ├── third_party/          # submódulos com tag fixa
│   │   ├── tests/                # GoogleTest: espelha src/ + fakes/ + fixtures/ + fuzz/
│   │   │                         #   + support/allocation_guard.cpp
│   │   ├── test/                 # testes Dart do pacote
│   │   ├── android/build.gradle  # externalNativeBuild → ../CMakeLists.txt
│   │   └── ios/                  # podspec preparado (ativado na fase 7)
│   └── voice_platform/           # plugin Kotlin/Swift via Pigeon
│       ├── pigeons/voice_platform_api.dart
│       ├── lib/src/{voice_platform_api.g.dart, voice_platform_gateway.dart,
│       │            pigeon_voice_platform_gateway.dart, models/}
│       ├── android/src/main/kotlin/com/isaacgeraldo/offtopic/voiceplatform/
│       │   ├── VoicePlatformPlugin.kt  VoicePlatformApiImpl.kt  RoomController.kt
│       │   ├── core/NativeVoiceCore.kt
│       │   ├── service/{VoiceService.kt, RoomNotificationFactory.kt}
│       │   ├── audio/{AudioRouter.kt, AudioRouterFactory.kt, CommunicationDeviceRouter.kt,
│       │   │          LegacyScoRouter.kt, AudioFocusController.kt}
│       │   ├── network/{WifiBinder.kt, GatewayResolver.kt, HotspotStateMonitor.kt}
│       │   ├── power/{WakeLockHolder.kt, BatteryOptimizationHelper.kt}
│       │   └── system/           # fachadas: AudioManagerFacade, ConnectivityFacade, SdkLevel…
│       ├── android/src/test/kotlin/…   # JUnit + MockK + Robolectric (espelha main/)
│       ├── android/src/androidTest/    # instrumentados (JNI real)
│       ├── test/                 # testes Dart do pacote + contrato do gateway
│       └── ios/Classes/          # stub Swift
├── tools/
│   ├── verify.ps1  verify_core.sh
│   ├── coverage/coverage_gate.dart
│   └── loopback_sim/
└── docs/ SPEC.md  PROTOCOL.md  IMPLEMENTATION_PLAN.md  DEPENDENCIES.md
```

Submódulos, cada um com tag fixa registrada em `docs/DEPENDENCIES.md`: `miniaudio`, `opus`, `googletest` e `nlohmann_json` (JSON do controle, adição justificada). Na fase 2 entram `webrtc-audio-processing` e `abseil-cpp`. Nada é baixado durante o build.

---

## Testes unitários: cobertura máxima

Objetivo: todo código escrito por nós que pode rodar fora do aparelho tem teste unitário. O código que só roda no aparelho fica reduzido a adaptadores finos, que apenas repassam chamadas ao sistema. A cobertura funciona como gate: abaixo do limite, a fase não fecha.

### Princípios
1. **O teste nasce junto com o código, em TDD quando der.** Cada classe nova chega com o seu teste no mesmo commit. As pastas de teste espelham as de código: `test/` espelha `lib/`, `tests/` espelha `src/` e `src/test/kotlin` espelha `src/main/kotlin`.
2. **Núcleo funcional, casca fina.** A lógica vive em classes puras e determinísticas. Threads, relógio, sockets, dispositivo de áudio e APIs do Android ficam atrás de interfaces e entram por injeção. Só a casca, o código que apenas delega ao sistema, fica sem teste unitário; ela é coberta por testes instrumentados.
3. **Sem tempo real nos testes unitários.** O tempo vem de `IClock`/`FakeClock` no C++, `fake_async` no Dart e `runTest` com dispatcher de teste no Kotlin. A única rede real é a dos testes de socket POSIX em localhost.
4. **Testes de contrato (o L do SOLID).** Cada interface tem uma suíte que roda contra todas as implementações, inclusive os fakes. Assim, um fake que se comporte diferente da implementação real quebra o teste.
5. **Catraca:** o limite de cobertura de cada pacote só sobe. Um commit que baixa a cobertura falha no `verify`.
6. **Exclusão só da lista fechada abaixo.** As marcações são `// coverage:ignore-*` (Dart), `// GCOVR_EXCL_*` (C++) e a anotação `@CoverageExcluded` configurada no Kover (Kotlin). Cada marcação leva um comentário com o motivo.

### Mudanças de design que tornam isso possível
- **C++:**
  - `IDatagramSocket`, `IStreamSocket` e `ISocketFactory`, com implementação POSIX real e fakes em memória para os testes de sessão.
  - Sessões e mixer não criam threads. Eles expõem `onDatagram()`, `onControlBytes()` e `tick(now)`. Quem cria as threads e chama esses métodos é o `SessionRunner` (casca). Os testes chamam direto, com `FakeClock`.
  - Os callbacks do miniaudio só delegam para `CapturePipeline::onInput()` e `PlayoutPipeline::onOutput()`, que são testáveis com buffers sintéticos.
  - `AllocationGuard`: o binário de teste substitui `operator new/delete` e conta as alocações. Os testes do caminho de tempo real afirmam **zero alocações**, o que comprova por teste, e não só por revisão, a regra da spec de que o callback não aloca. No preset `desktop-tsan` o runtime do TSan já substitui o `operator new`, então esses testes são pulados (`GTEST_SKIP`) ali e valem nos presets debug, ASan e coverage.
  - `RecordingEventSink` grava os eventos emitidos para as asserções.
- **Dart:**
  - `FfiVoiceCoreClient` recebe a classe `VoiceCoreBindings` gerada pelo ffigen (estilo `DynamicLibrary`), que é mockada com mocktail nos testes. A interface extra `NativeVoiceCoreApi` prevista antes se mostrou desnecessária.
  - O `dartTestOut` do Pigeon está obsoleto na versão 29 ("Mock/fake the generated Dart API instead"). O gateway recebe a `VoicePlatformHostApi` gerada e a função do stream por injeção, e os testes usam mocks delas.
  - Timers são controlados por `fake_async`. A plataforma e o nível de API chegam num `PlatformInfo` injetado.
- **Kotlin:**
  - Fachadas finas sobre os serviços do sistema: `AudioManagerFacade`, `ConnectivityFacade`, `WifiFacade`, `PowerFacade` e `NotificationFacade`, além do `SdkLevel`, um valor injetado vindo de `Build.VERSION.SDK_INT`.
  - `VoiceCoreBridge` é a interface; `NativeVoiceCore` (JNI) é a casca.
  - Coroutines com dispatcher injetado.

### Ferramentas (versões mais recentes, conferidas em 31/10/2026)
| Camada | Ferramenta | Versão |
| --- | --- | --- |
| C++ | GoogleTest + GoogleMock | `v1.18.0` |
| C++ | Cobertura: preset `desktop-coverage` (GCC `--coverage -O0`) + gcovr | gcovr 8.8 (pip no WSL) |
| C++ | Sanitizers | presets `desktop-asan` (ASan + UBSan) e `desktop-tsan` |
| C++ | Fuzzing dos parsers (complemento) | libFuzzer do clang, preset `desktop-fuzz` |
| Dart | `flutter_test`, `mocktail`, `fake_async` | ^1.0.5, ^1.3.3 |
| Dart | Cobertura: `fvm flutter test --coverage` (lcov) + `tools/coverage/coverage_gate.dart` próprio, que filtra os gerados e aplica o limite por diretório | — |
| Kotlin | JUnit 4 (o runner que o Robolectric usa), `kotlin.test`, MockK, Robolectric (suporta o SDK 37), kotlinx-coroutines-test, Turbine, androidx.test core / ext-junit | 4.13.2, KGP 2.4.0, 1.14.11, 4.17, 1.11.0, 1.2.1, 1.7.0 / 1.3.0 |
| Kotlin | Cobertura: Kover (`koverVerifyDebug` com limite) | 0.9.11 |
| Kotlin | Estilo: ktlint-gradle (ktlint 1.8.0) | 14.2.0 |
| Swift (fase 7) | XCTest + cobertura do Xcode | — |

### Metas (gates)
| Escopo | Linhas | Ramos |
| --- | --- | --- |
| C++ `src/`, fora as exclusões | ≥ 95% | ≥ 90% |
| Dart: `domain/`, `data/`, controllers e `lib/src` dos dois pacotes (sem gerados) | **100%** | — |
| Dart: workspace inteiro, com widgets (sem gerados) | ≥ 95% | — |
| Kotlin `voice_platform`, sem o código gerado do Pigeon | ≥ 90% | ≥ 85% |

Os gates valem desde a fase 0. Com pouco código no começo, manter os limites é barato, e a catraca impede que caiam depois.

**Exclusões permitidas (lista fechada):**
- **Código gerado:** `*.g.dart`, `bindings.g.dart`, `app_localizations*.dart` e o Kotlin/Swift gerados pelo Pigeon.
- **Fora do produto:** `third_party/`, `tests/` e `tools/`.
- **Cascas que só existem no aparelho:** `src/platform/android/*` (JNI e `android_setsocknetwork`), a abertura do dispositivo em `MiniaudioDevice`, `FfiNativeVoiceCoreApi`, `NativeVoiceCore.kt` (`external fun`) e o bootstrap em `main.dart`. Essas são cobertas pelos testes instrumentados descritos em Complementos.

### Catálogo de testes por componente
O número da fase indica quando o teste passa a ser obrigatório. Cada fase só fecha com todos os itens dela verdes.

**C++ (`packages/voice_core/tests/`)**

| Componente | Fase | Casos obrigatórios |
| --- | --- | --- |
| `CoreConfig` | 1 | Defaults iguais aos da spec (16 kHz, 320 amostras, 24 kbps, FEC 10%, jitter 20/40/120 ms, portas 47800/47801, cauda 300 ms, ping 1 s, timeout 5 s, máximo 8). A validação rejeita cada campo inválido. Conversão a partir de `vc_config`: cliente sem `host_ip` dá erro, e no anfitrião o campo é ignorado |
| `SpscRingBuffer` | 1 | Vazio e cheio, volta do índice, push com o buffer cheio e pop com ele vazio falham, leitura e escrita parciais em bloco, estresse produtor/consumidor conferindo a sequência (sob TSan), zero alocação depois de construído |
| `SequenceNumber` | 1 | Comparação com volta (65535 vem antes de 0), distância, metade do intervalo |
| `AudioPacket` | 1 | Bytes exatos dos vetores do `PROTOCOL.md`, ida e volta, todas as combinações de flags, versão errada, cabeçalho com menos de 8 bytes, payload vazio (keepalive), limites de `participant_id`, `seq` e `timestamp` |
| `OpusEncoder` / `OpusDecoder` | 1 | Parâmetros aplicados (lidos de volta via `ctl`), quadro de 320 amostras, senoide em ida e volta com SNR mínimo, DTX no silêncio, recuperação pelo FEC do pacote seguinte, PLC com pacote nulo, erros propagados |
| `JitterBuffer` | 1 | Ordem normal, reordenação dentro da janela, duplicado descartado, atrasado descartado e contado, perda coberta por FEC ou PLC, volta do `seq`, alvo que começa em 40 ms, cresce até 120 e encolhe até 20, descarte e inserção por drift, reinício do fluxo, lacuna de DTX sem contar como perda |
| `JitterEstimator`, `LossTracker`, `RttEstimator` | 1 | Sequências conhecidas geram os valores esperados (RFC 3550), volta do `seq`, suavização, reset |
| `CapturePipeline` / `PlayoutPipeline` | 1 | Blocos sintéticos. Underrun vira silêncio, overrun vira descarte contado. **Zero alocação**, verificada pelo `AllocationGuard` |
| `PosixUdpSocket` / `PosixTcpSocket` | 1 / 3 | Em localhost: bind, envio e recebimento, poll com timeout, `EAGAIN`, socket fechado. O spy do `INetworkBinder` confirma que ele é chamado para cada socket |
| `ClientSession` mínima e modo eco | 1 | Cabeçalho correto, destino é o anfitrião, eco devolve o quadro, estatísticas preenchidas |
| `IAudioProcessor` (passthrough e WebRTC) | 2 | Suíte de contrato com `TYPED_TEST`. Quadro de 20 ms dividido em 2 blocos de 10 ms. Ruído branco perde energia. VAD verdadeiro numa fixture de voz gravada pelo grupo e falso no silêncio. AEC liga e desliga |
| `VoiceGate` | 2 | Abre com voz, mantém exatamente 300 ms de cauda (15 quadros) e fecha. PTT ignora o VAD. Mute vence tudo. Sensibilidade. Evento de "falando" em cada transição |
| DTX + keepalive | 2 | Em silêncio, com `FakeClock`: um keepalive por segundo e nenhum quadro de áudio |
| `LengthPrefixedFramer` | 3 | Um quadro, vários no mesmo buffer, quadro chegando byte a byte, tamanho zero, tamanho acima do máximo (erro e fechamento), ordem big-endian |
| `ControlMessageCodec` | 3 | Ida e volta de cada mensagem. Campo faltando, tipo desconhecido, versão incompatível, campos extras tolerados, JSON inválido |
| `ParticipantRegistry` | 3 | Atribuição de ids. O mesmo `device_id` recupera o mesmo id ao reconectar. O 9º participante é recusado. Remoção por BYE e por timeout. Id 0 reservado ao anfitrião. Reaproveitamento de ids |
| `LivenessMonitor` | 3 | PING a cada 1 s, remoção após 5 s sem PONG, PONG atualiza o RTT |
| `SoftLimiter` | 3 | Oito entradas em fundo de escala nunca passam do limite, transparente abaixo do limiar, sem descontinuidade |
| `MixMinusMixer` | 3 | Ninguém recebe a própria voz, com 2, 4 e 8 participantes. O anfitrião local entra na mistura. Participante sem quadro no tick. Participante sozinho recebe silêncio. Somas exatas com sinais inteiros |
| `HostSession` | 3 | HELLO gera WELCOME com parâmetros e roster. ROSTER em entrada, saída e mute. UDP de origem desconhecida é ignorado. Endereço atualizado na reconexão. Cadeia decodifica → mixa → codifica → envia, para cada participante. BYE, timeout, sala cheia e eventos emitidos |
| `ClientSession` completa | 3 / 4 | HELLO, WELCOME, ROSTER e MUTE. Perda detectada em 5 s. Reconexão com backoff de 0,5 a 2 s (`FakeClock`), recuperando o mesmo id pelo `device_id`. Pause e resume |
| `ReconnectPolicy` | 4 | Sequência de esperas, teto, reset depois de reconectar |
| Troca de rede | 4 | Handle novo recria os sockets e chama o `INetworkBinder` com ele |
| API C (`voice_core_api.cpp`) | 0–4 | `vc_version`. Códigos de erro: init inválido, start sem init, start duplo, stop idempotente, ponteiro nulo. Callback nulo aceito. **Cada payload de evento liberado exatamente uma vez** (ASan acusa vazamento). Chamadas concorrentes de duas threads (sob TSan). Conteúdo do snapshot JSON |
| `EventSerializer` | 1 / 3 | JSON exato de cada tipo de evento |
| Fuzz (complemento) | 1 / 3 | `AudioPacket::parse`, `LengthPrefixedFramer` e `ControlMessageCodec` sem crash nem UB com entrada arbitrária (ASan + UBSan). Corpus inicial versionado. Uma rodada curta em todo `verify` |

**Dart (`app/test/`, `packages/*/test/`)**

| Componente | Fase | Casos obrigatórios |
| --- | --- | --- |
| `EventDecoder` | 1 | JSON de cada evento vira o `CoreEvent` (sealed) certo. Tipo desconhecido é ignorado. JSON inválido vira `Failure` |
| `FfiVoiceCoreClient` | 0 / 1 | Versão. Struct de stats vira `CoreStats`. Código de erro vira `Failure`. **Payload liberado uma vez, mesmo quando o decode falha.** Callback registrado e removido no `dispose` |
| `VoiceCoreLibraryLoader` | 0 | Escolhe `open('libvoice_core.so')` ou `process()` conforme o `PlatformInfo` injetado. Os dois ramos são testáveis em qualquer host |
| `PigeonVoicePlatformGateway` | 0–4 | Com a `TestHostApi` gerada: cada método converte DTO ↔ modelo, `PlatformException` vira `Failure`, stream de estado, capacidades |
| Contrato `VoicePlatformGateway` | 0 | A mesma suíte roda contra o gateway Pigeon e contra o `FakeVoicePlatformGateway` usado no app |
| Value objects (`DisplayName`, `HostAddress`, `PortNumber`, `Bitrate`) | 1 | Tabela de valores válidos e inválidos, incluindo os limites. Normalização (trim) |
| Entidades (`Participant`, `RoomSession`, `CoreStats`…) | 1 / 3 | Igualdade, `copyWith`, invariantes |
| `ConnectionQualityClassifier` | 3 | Fronteiras de verde, amarelo e vermelho (no limite e no limite ± ε), por perda e por jitter |
| `JoinPayloadCodec` (QR) | 3 | Ida e volta, versão, esquema errado, campo faltando, porta inválida |
| `DeviceIdProvider` | 3 | Gera uma vez, persiste, reutiliza, formato |
| `HostDiscovery` (gateway, QR e composição) | 3 | Gateway presente e ausente, QR válido e inválido, ordem do fallback |
| `PermissionService` | 1–4 | Nos níveis de API 29, 30, 31, 33, 34 e 37: o conjunto pedido é o certo. Mapeamento de cada status: `granted`, `denied`, `permanentlyDenied`, `restricted` e `limited` |
| Casos de uso (`CreateRoom`, `JoinRoom`, `LeaveRoom`, `ToggleMute`, `SetTalkMode`, `PushToTalk`, `ReattachToRoom`…) | 1–4 | Sucesso, cada falha propagada, guardas (permissão negada, capacidade ausente, sala já ativa) |
| `RoomRepositoryImpl` | 1–4 | Ordem do início: permissões, depois `startRoom`, depois o callback. Parada. Roster montado a partir do snapshot e dos eventos (fora de ordem, duplicados sem efeito). Reconexão da interface |
| `SettingsRepositoryImpl` | 2 | Defaults, persistência, valor corrompido volta ao default |
| `StatsPoller` | 1 | Com `fake_async`: 4 leituras por segundo, para no `dispose`, não lê sem sala ativa |
| Controllers (Riverpod) | 0–4 | `ProviderContainer` com overrides. Todas as transições: idle → starting → active → leaving, e o caminho de erro. Mute confirmado pelo evento, PTT, reconexão exibida, manter tela ligada |
| Rotas (`go_router`) | 3 / 4 | Reabrir o app leva à sala ativa. Sem nome cadastrado, vai para a tela de nome |
| `QrCodeView` | 3 | `shouldRepaint`. Os módulos escuros pintados batem com a matriz do `qr` (verificação pela matriz, sem golden) |
| Widgets de cada tela | 0–5 | Todos os estados: Home; Criar sala com cada item do checklist; Entrar, automático e por QR; Sala com 1, 4 e 8 participantes, quem fala, cores de qualidade, mute e rota; Permissão negada; Guia de bateria por fabricante; Configurações com validação; Diagnóstico. Também `meetsGuideline(androidTapTargetGuideline)`, `textContrastGuideline` e botões de pelo menos 64 dp verificados com `tester.getSize` |
| l10n | 0 | Toda chave do `app_en.arb` existe no `app_pt.arb`, com os mesmos placeholders. As telas renderizam nos dois idiomas |

Não haverá golden tests de pixel: a renderização de fontes muda entre Windows e Linux e gera falsos positivos. Os testes de widget verificam estrutura, estados e as guidelines de acessibilidade.

**Kotlin (`packages/voice_platform/android/src/test/`)**

| Componente | Fase | Casos obrigatórios |
| --- | --- | --- |
| `AudioRouterFactory` | 2 | `SdkLevel` 29 e 30 dão `LegacyScoRouter`; 31, 34 e 37 dão `CommunicationDeviceRouter` |
| `CommunicationDeviceRouter` | 2 | Escolhe `TYPE_BLUETOOTH_SCO`. Sem intercom, cai no fallback e reporta a rota. Refaz a rota quando um dispositivo entra ou sai. No stop, chama `clearCommunicationDevice` e restaura o modo |
| `LegacyScoRouter` | 2 | Transições do broadcast de SCO (connecting → connected → disconnected), nova tentativa em caso de erro, stop |
| `AudioFocusController` | 4 | Ganho. Perda transitória e perda definitiva pausam. Ganho depois da ligação retoma e refaz a rota. Abandono do foco no stop |
| `WifiBinder` | 4 | `NetworkRequest` com `TRANSPORT_WIFI` e sem `INTERNET`. Rede disponível envia o handle, rede perdida limpa, rede nova envia o handle novo. Os locks são sempre liberados, inclusive depois de um erro |
| `GatewayResolver`, `HostAddressResolver`, `HotspotStateMonitor` | 3 | Tabelas: rota padrão presente e ausente, só IPv6, nomes de interface (`ap0`, `swlan0`, `wlan1`) |
| `RoomController` | 1–4 | Ordem do início: foco, rota, Wi-Fi, núcleo. Se o núcleo falhar, desfaz tudo (libera locks e rota). Stop idempotente. Mute atualiza a notificação e o núcleo. Pause e resume |
| `VoicePlatformApiImpl` | 0–4 | Conversão das mensagens Pigeon. Erros viram `FlutterError` com código. Emissões do stream, verificadas com Turbine |
| `BatteryOptimizationHelper` | 4 | Já isento: nenhum intent. Senão, intent correto com o pacote. Fabricante leva ao guia certo (Xiaomi/Redmi/POCO, Samsung, Motorola, outros) |
| `RoomNotificationFactory` (Robolectric) | 4 | Canal criado, ações de mute e sair com os `PendingIntent` certos, texto de mudo e ativo |
| `VoiceService` (Robolectric, `@Config(sdk = [29, 31, 34, 37])`) | 4 | `startForeground` com `microphone|connectedDevice`, ações MUTE e LEAVE, `onDestroy` libera tudo |
| `StatsCsvRecorder` | 5 | Formato das linhas, intervalo, rotação do arquivo |

**Swift (fase 7):** a suíte de contrato do gateway, reescrita em XCTest, mais os testes da configuração do `AVAudioSession` atrás de uma fachada.

### Complementos (não contam na cobertura unitária)
- **Instrumentados no aparelho (`androidTest`):** `NativeVoiceCore` carregando a `.so` real e chamando cada função JNI, e o `AndroidNetworkBinder` com rede real.
- **`integration_test` do Flutter:** iniciar e parar uma sala num aparelho.
- **`tools/loopback_sim`:** os cenários de perda e jitter descritos nas fases.

### Execução
- **`tools/verify.ps1`**, ponto único no Windows. Roda:
  1. `fvm dart format`, `fvm flutter analyze` e `fvm flutter test --coverage`, seguidos do `coverage_gate.dart`. O script falha logo no início se o `fvm` não estiver instalado ou se a versão ativa for diferente da do `.fvmrc`.
  2. `./gradlew :voice_platform:testDebugUnitTest koverVerify`.
  3. `wsl -d Ubuntu-26.04 -- tools/verify_core.sh`, que executa o preset `desktop-coverage` com o gcovr (`--fail-under-line 95 --fail-under-branch 90`), os presets `desktop-asan` e `desktop-tsan` e uma rodada curta de fuzz.
- **Relatórios HTML:** gcovr `--html-details` (C++), relatório HTML do Kover e `genhtml` do lcov no WSL (Dart).
- **Regras no `CLAUDE.md`:** nenhuma fase fecha com o `verify.ps1` vermelho. Todo código novo vem com teste no mesmo commit. Exclusões só da lista fechada.

---

## Fases

Cada fase termina com o aceite da spec cumprido em aparelho real e um resumo de "o que foi feito e como testar no celular".

### Fase 0: Esqueleto e fundações
0. **Preparar o ambiente, com as versões da tabela:**
   - Modo de Desenvolvedor do Windows, que permite ao FVM criar links simbólicos sem administrador: **já está ligado** nesta máquina (conferido em 01/11/2026). Para conferir em outra máquina: Configurações → Sistema → Avançado (`start ms-settings:developers`).
   - `dart pub global activate fvm 4.3.2`, `fvm install 3.47.9` e, na raiz do repositório, `fvm use 3.47.9`. O `use` cria o `.fvmrc` (vai para o git), cria a pasta `.fvm/` (o `.gitignore` recebe essa entrada), e o `dart.flutterSdkPath` do VS Code passa a apontar para o SDK do projeto.
   - `fvm flutter doctor --android-licenses`. Não rodar `flutter upgrade`: o Flutter global continua na 3.41.9.
   - `sdkmanager "ndk;30.0.16248370" "cmake;4.1.2" "build-tools;37.0.0"` e a plataforma 37.
   - `wsl --install Ubuntu-26.04`. Dentro do WSL: `build-essential`, `clang`, `ninja-build`, `pkg-config` e CMake 4.1.2, pelo apt se a versão bater ou por `pip install cmake==4.1.2`.
   - Registrar tudo em `docs/DEPENDENCIES.md`.
1. `git mv` da especificação para `docs/SPEC.md`. Criar o `CLAUDE.md` com as regras da spec, as decisões 1 a 7 acima, as regras de teste (teste no mesmo commit, gates, catraca, lista fechada de exclusões), a regra de sempre usar `fvm flutter` e `fvm dart` (nunca o `flutter` global), os comandos de build e teste e um link para a SPEC. Salvar este plano em `docs/IMPLEMENTATION_PLAN.md`.
2. Pub workspace, `analysis_options.yaml`, `.clang-format`, `.clang-tidy` e `.editorconfig`.
3. Criar os projetos:
   - `fvm flutter create --org com.isaacgeraldo --project-name offtopic --platforms=android,ios app`
   - `fvm flutter create --template=plugin_ffi --platforms=android,ios packages/voice_core`
   - `fvm flutter create --template=plugin --platforms=android,ios -a kotlin -i swift packages/voice_platform`
4. Gradle:
   - Gradle 9.3.1, AGP 9.1.1 e KGP 2.4.0 (o AGP 9.2.1 foi testado e recusado: exige Gradle 9.4.1).
   - `compileSdk 37`, `targetSdk 37`, `minSdk 29`.
   - `ndkVersion "30.0.16248370"` e `externalNativeBuild.cmake.version "4.1.2"`.
   - ABIs `arm64-v8a`, `armeabi-v7a` e `x86_64`.
   - Validar com `fvm flutter build apk` sem avisos de compatibilidade.
5. C++: `vc_version()` + `CMakePresets.json` com os presets `android`, `desktop-debug`, `desktop-asan`, `desktop-tsan`, `desktop-coverage` e `desktop-fuzz` (WSL). GoogleTest como submódulo, com um primeiro teste e o `AllocationGuard`.
5b. **Infraestrutura de testes, antes de qualquer funcionalidade:**
   - `tools/verify.ps1`, `tools/verify_core.sh` e `tools/coverage/coverage_gate.dart`, com os limites da seção de testes.
   - Kover com `koverVerifyDebug`, e Robolectric e MockK configurados.
   - `tools/codegen.ps1`, que regenera ffigen, Pigeon e l10n.
   - Fakes públicos em `lib/testing.dart` de cada pacote e suítes de contrato em `test/contracts/`.
   - As fachadas Kotlin (`SdkLevel` e afins) nascem aqui.
6. ffigen gerando `bindings.g.dart`. Pigeon com a API completa já declarada: `startRoom(RoomConfigMessage)`, `stopRoom`, `setMute`, `openHotspotSettings`, `requestBatteryExemption`, `setKeepScreenOn`, `getPlatformInfo`/capabilities, `getActiveRoom` e o stream `@EventChannelApi` de estado (rota, Wi-Fi, serviço). As implementações começam como stubs.
7. Dart: tema escuro de alto contraste (botões com 64 dp ou mais), l10n, go_router e uma Home que mostra `vc_version()`.
- **Testes:** itens da fase 0 do catálogo: API C (`vc_version`), `FfiVoiceCoreClient`, `VoiceCoreLibraryLoader`, gateway Pigeon e o contrato dele, `VoicePlatformApiImpl`, controller e widget da Home, l10n. `verify.ps1` verde com os gates.
- **Aceite:** o APK roda e mostra a versão vinda do C++.

### Fase 1: PoC de áudio, 2 celulares, sem Bluetooth
1. **Escrever `docs/PROTOCOL.md` antes de qualquer código de rede.** Ele cobre o cabeçalho UDP de 8 bytes big-endian (versão, flags DTX/FEC/keepalive, `participant_id`, `seq`, `timestamp`), o keepalive, o framing TCP de 4 bytes, os schemas JSON de todas as mensagens, o versionamento e as portas 47800/47801.
2. C++:
   - `CoreConfig` e `SpscRingBuffer<T>` (lock-free).
   - `MiniaudioDevice` com AAudio, usage e input preset em `VOICE_COMMUNICATION`, e um callback sem alocação, lock, I/O ou log.
   - Wrappers RAII de Opus (VOIP, 16 kHz, 20 ms, 24 kbps, FEC, perda esperada de 10%).
   - `AudioPacket` (serialize/parse), `UdpSocket` (poll, não bloqueante) e `JitterBuffer` adaptativo (alvo 40 ms, mínimo 20, máximo 120, volta do `seq`, FEC via pacote seguinte, PLC, descarte e inserção de quadros para compensar o drift de relógio).
   - Sessão mínima: o cliente envia para o `host_ip`. O anfitrião aprende o endereço do cliente pelo primeiro pacote e devolve o próprio microfone para ele. Há também um modo eco, para medir RTT.
   - Estatísticas: perda, jitter no estilo do RFC 3550, tamanho do jitter buffer e RTT pelo keepalive.
3. Kotlin: `NativeVoiceCore` (JNI) e `RoomController`, ainda sem service. Pigeon `startRoom`/`stopRoom` funcionando. `RECORD_AUDIO` e **`ACCESS_LOCAL_NETWORK`** via `permission_handler`, por trás de `PermissionService`, com a tela de permissão negada. Sem esta última, nenhum pacote sai no Android 17.
4. Dart: `NativeCallable.listener` com a regra de posse do payload, polling de stats a 4 Hz e uma tela de debug com papel, IP digitado, iniciar/parar e estatísticas.
5. `tools/loopback_sim` v1: duas sessões num processo, por localhost, com proxy de perda, jitter e reordenação configuráveis e `FakeAudioDevice` gerando pulsos para medir latência.
- **Testes:** todos os itens da fase 1 do catálogo, com destaque para `JitterBuffer`, `SpscRingBuffer` (TSan), pipelines com zero alocação, `AudioPacket` com os vetores do `PROTOCOL.md`, fuzz do parser, `EventDecoder`, `StatsPoller` e `PermissionService` (`ACCESS_LOCAL_NETWORK`). `verify.ps1` verde.
- **Aceite:** 10 min sem cortes, latência medida de até 150 ms e estatísticas na tela.
- **Desvios registrados na implementação (01/11/2026):**
  - miniaudio **0.11.26** (lançada em 31/10/2026), em vez da 0.11.25; Opus v1.6.1 sem DRED/OSCE, que exigiriam baixar modelos.
  - O modo eco é o campo `echo_mode` da `vc_config` (vale para a sessão inteira), em vez de uma função `vc_set_echo_mode`.
  - `vc_set_network_handle` fica para a fase 4, junto com o `WifiBinder`. A interface `INetworkBinder` e o `NoopNetworkBinder` já existem, e o spy confirma o vínculo de cada socket.
  - Eventos da fase 1: `VC_EVENT_STATE_CHANGED` e `VC_EVENT_LINK_CHANGED`. A fase 3 acrescenta participantes e "falando".
  - Os value objects `PortNumber` e `Bitrate` passam para a fase 2, com a tela de configurações. A fase 1 usa `HostAddress` e `DisplayName`, e portas e bitrate vêm de `vc_config_defaults` (uma só configuração).
  - Um roteador de áudio mínimo entrou já na fase 1 (`AudioRouterFactory` → `CommunicationDeviceRouter`/`LegacySpeakerRouter`, fone com fio ou alto-falante, `MODE_IN_COMMUNICATION`). Motivo: com o uso `VOICE_COMMUNICATION`, o Android manda o som para o alto-falante de ouvido (earpiece), baixo demais para o teste. A fase 2 acrescenta o SCO a esses roteadores.
  - O `loopback_sim` roda uma passagem curta (6 s, 5% de perda, jitter de 0 a 30 ms) dentro do `verify_core.sh`, como teste de ponta a ponta.
  - Os testes do `VoiceEngine` usam as threads reais do motor, com espera limitada; é a única exceção à regra de "sem tempo real".
  - A fila de reprodução (áudio já decodificado à espera do dispositivo) é adaptativa: mínimo de 20 ms (`playoutBufferMs`), crescendo até o maior volume que o dispositivo consumiu entre duas passadas do loop de mídia. Motivo, visto no emulador: o miniaudio em duplex sobre o AAudio enche um burst inteiro (até 100 ms) com vários callbacks seguidos. Num celular os bursts são de 5 a 20 ms, então a fila fica perto do mínimo. A latência real precisa ser medida no aceite.
  - A ponte JNI registra só os métodos que o `NativeVoiceCore.kt` declara. Uma entrada a mais derrubava o processo na primeira execução no emulador; agora uma falha de registro vira erro para o Dart. Os testes instrumentados (fase 4) vão cobrir essa ponte.
  - **Achados no celular real (Galaxy A54, Android 16, 01/11/2026):**
    - O AAudio de baixa latência abria streams MMAP. Nesse modo, o cancelador de eco e o redutor de ruído do sistema não se aplicam.
    - O Android aplica `setMode` e `setCommunicationDevice` de forma assíncrona, cerca de 250 ms depois. A rota chegava com o microfone já aberto e o desconectava no `requestStart` (`-899`).
    - Correção: o dispositivo usa o caminho normal (perfil `conservative`), o `CommunicationDeviceRouter` espera a rota (até 1 s) e o `VoiceEngine` tenta iniciar o dispositivo mais uma vez.
    - O APK release ganhou uma regra R8 (`consumer-rules.pro`) que preserva a classe JNI.
  - **Aceite da fase 1:** confirmado pelo usuário em 02/11/2026, com o APK 0.1.1 em celulares reais.

### Fase 2: Bluetooth e processamento
1. **Spike com prazo fixo:** compilar `webrtc-audio-processing` e `abseil-cpp` por CMake no NDK e no WSL. O projeto upstream usa Meson, então vai ser preciso um `cmake/webrtc_apm.cmake` próprio. Se não for viável, **parar e apresentar a alternativa** (por exemplo SpeexDSP para ruído, AGC e VAD), como manda a spec.
2. C++: `WebRtcAudioProcessor` em blocos de 10 ms (NS no nível alto, AGC, VAD e AEC opcional), `VoiceGate` (VAD com 300 ms de cauda) e PTT, DTX ligado com keepalive de 1/s.
3. Kotlin: `AudioRouterFactory` → `CommunicationDeviceRouter` (`setCommunicationDevice` com `TYPE_BLUETOOTH_SCO`) ou `LegacyScoRouter` (`startBluetoothSco`). `MODE_IN_COMMUNICATION`, `AudioDeviceCallback` para refazer a rota e `BLUETOOTH_CONNECT` em tempo de execução, pedido junto com `ACCESS_LOCAL_NETWORK` (grupo `NEARBY_DEVICES`). A rota vai para o stream de estado.
4. Dart: indicador de rota, modo de fala (voz/PTT) com um botão PTT grande e sensibilidade do VAD.
5. **Testar cedo com os intercomunicadores reais do grupo.** Considerar o HFP em 8 kHz (CVSD); nesse caso o miniaudio reamostra.
- **Testes:** todos os itens da fase 2 do catálogo: contrato `IAudioProcessor`, `VoiceGate`, DTX/keepalive, `AudioRouterFactory` e os dois routers, `SettingsRepositoryImpl`. Também o simulador com DTX. `verify.ps1` verde.
- **Aceite:** conversa pelos intercomunicadores reais, vento atenuado (teste com ventilador) e latência de até 250 ms.

### Fase 3: Anfitrião e grupo
1. C++:
   - `FramedTcpChannel` (lida com leituras parciais) e `ControlMessage` (HELLO, WELCOME, ROSTER, MUTE, PING/PONG a 1 s com remoção após 5 s, BYE).
   - `ParticipantRegistry` (o `device_id` mantém o mesmo `participant_id`; limite de 8).
   - `HostSession`: jitter buffer e decoder por participante, mais `MixMinusMixer` com tick de 20 ms e limitador suave, e um encoder por destino. O microfone e o alto-falante locais entram direto no mixer.
   - Eventos: entrou, saiu, falando, roster, conexão perdida e restabelecida.
2. Kotlin:
   - `GatewayResolver`: gateway da rede Wi-Fi por `LinkProperties`.
   - IP do próprio anfitrião, pela interface do hotspot.
   - `HotspotStateMonitor`: o Android não tem API pública para isso, então é melhor esforço com confirmação manual no checklist.
   - `openHotspotSettings`, com intent de tethering e fallback.
3. Dart:
   - Criar sala: checklist, botão de configurações e QR (`qr` + `QrCodeView` próprio) com IP, portas e versão do protocolo.
   - Entrar: automático pelo gateway, com QR via `mobile_scanner` como alternativa.
   - Sala: participantes, quem está falando, qualidade verde/amarela/vermelha via `ConnectionQualityClassifier`, mute grande, sair e rota.
4. Simulador com 4 participantes virtuais.
- **Testes:** todos os itens da fase 3 do catálogo: mixer, limitador, framer e codec de controle (com fuzz), registry, liveness, `HostSession`; no Dart, classifier, QR, discovery, roster e as telas Criar, Entrar e Sala; no Kotlin, os resolvers. `verify.ps1` verde.
- **Aceite:** 4 celulares, todos se ouvem, ninguém ouve a própria voz, 30 min sem cortes.

### Fase 4: Robustez
1. `VoiceService` (`microphone|connectedDevice`, iniciado em primeiro plano). O `RoomController` passa para dentro do service. Notificação com mute e sair, e `POST_NOTIFICATIONS` no 33+.
2. `WifiBinder`: `requestNetwork(TRANSPORT_WIFI)` sem exigir internet, passando `networkHandle` para `NativeVoiceCore.setNetworkHandle`. No C++, `AndroidNetworkBinder` chama `android_setsocknetwork` em cada socket e recria os sockets quando a rede muda. `WifiLock FULL_LOW_LATENCY` e wake lock parcial.
3. Reconexão no cliente: máquina de estados Connected → Lost → Reconnecting (backoff de 0,5 s até 2 s) → Connected, com HELLO reenviado usando o mesmo `device_id`. O anfitrião reserva a vaga. A meta é reconectar em até 10 s.
4. `AudioFocusController`: `AUDIOFOCUS_GAIN`. Na perda chama `vc_pause`, no retorno chama `vc_resume` e refaz a rota SCO.
5. Bateria: `requestBatteryExemption` e uma tela de orientação por fabricante (Xiaomi, Samsung, Motorola), usando o `manufacturer` de `getPlatformInfo`.
6. Reconexão da interface: na abertura, `getActiveRoom()` leva à tela da sala, registra o callback e lê o snapshot. Ao fechar, o callback é desregistrado. "Manter tela ligada" passa a funcionar.
- **Testes:** todos os itens da fase 4 do catálogo: `ReconnectPolicy`, troca de rede, `ClientSession` completa; `AudioFocusController`, `WifiBinder`, `RoomController`, `BatteryOptimizationHelper`, `VoiceService` e notificação no Robolectric (SDK 29 a 37); `ReattachToRoom` e as rotas no Dart. Mais o simulador com o link derrubado por 15 s e reconexão em até 10 s, e os instrumentados JNI no aparelho. `verify.ps1` verde.
- **Aceite:** 1 h com a tela bloqueada, reconexão em até 10 s sem tocar na tela e ligação recebida que pausa e retoma a sala sozinha.

### Fase 5: Teste de estrada e ajuste
Diagnóstico completo na tela. Gravador de estatísticas em CSV, feito no Kotlin, que registra perda, jitter, RTT, bateria e temperatura (`BatteryManager`) do anfitrião, e nunca áudio. Os ajustes de jitter buffer, bitrate e FEC são feitos só pela `CoreConfig` e pelas configurações. **Testes:** `StatsCsvRecorder` e widget do Diagnóstico; cada ajuste de parâmetro feito na estrada ganha um caso no teste do componente afetado. **Aceite:** `docs/ROAD_TEST_REPORT.md` com perda por distância e tempos de reconexão.

### Fase 6 (opcional): Fallback pela internet
Servidor relay UDP em `tools/relay_server`, reaproveitando `net/` e `session/`, com o mesmo protocolo. O núcleo já trata o anfitrião como um endereço qualquer. O Kotlin troca para dados móveis quando o Wi-Fi cai.

### Fase 7 (opcional): iPhone como cliente e LocalOnlyHotspot
- **iOS:**
  - Podspec compilando o núcleo.
  - Implementação Swift do Pigeon: `AVAudioSession` em `.playAndRecord`, `.voiceChat` e `.allowBluetooth`, com `UIBackgroundModes: audio` e `NSLocalNetworkUsageDescription`.
  - Entrada pelo QR (`QrHostDiscovery`) e `canHostRoom = false`.
  - Exige um Mac ou CI macOS.
- **Android:** `startLocalOnlyHotspot` com QR (SSID, senha e IP), pedindo `NEARBY_WIFI_DEVICES` no 33+ e localização no 32 ou anterior.

---

## Riscos adicionais identificados no planejamento
| Risco | Mitigação |
| --- | --- |
| `webrtc-audio-processing` usa Meson e depende do Abseil | Spike no início da fase 2. Se falhar, parar e propor SpeexDSP |
| targetSdk 37 bloqueia a rede local sem `ACCESS_LOCAL_NETWORK` | Pedir junto com o `BLUETOOTH_CONNECT`, tratar a negativa e diagnosticar com `android_getnetworkblockedreason()` |
| Versões acima do que o Flutter 3.47.9 conhece (AGP > 9.1, Gradle > 9.3.1, KGP > 2.4.0) | Não usar até um Flutter novo declarar suporte. Revisar a cada fase |
| Ponteiro do evento inválido no `NativeCallable.listener` assíncrono | Payload alocado pelo núcleo e liberado pelo Dart (`vc_free_event_payload`) |
| Callback chamado depois que o isolate morre | Desregistrar ao fechar a interface. O núcleo aceita callback nulo |
| Sem API pública para o estado do hotspot | Melhor esforço com confirmação manual no checklist |
| HFP em 8 kHz (CVSD) em intercomunicadores antigos | Reamostragem no miniaudio. Documentar a qualidade |
| Drift de relógio entre aparelhos | O jitter buffer descarta ou insere quadros |
| iOS não compila no Windows | Mac ou CI macOS na fase 7. Até lá, só o código Swift gerado |

---

## Verificação (a cada fase)
- **Tudo de uma vez:** `tools/verify.ps1`. Ele falha se qualquer teste falhar ou se qualquer gate de cobertura ficar abaixo do limite.
- **Dart:** `fvm dart format --set-exit-if-changed .`, `fvm flutter analyze` (zero avisos) e `fvm flutter test --coverage` em todo o workspace, seguido de `fvm dart run tools/coverage/coverage_gate.dart` (100% em domain, data, controllers e pacotes; ≥ 95% no total).
- **Codegen:** `fvm dart run ffigen` e `fvm dart run pigeon --input pigeons/voice_platform_api.dart` sem deixar diff no git.
- **C++ (WSL):**
  - `cmake --preset desktop-debug && cmake --build --preset desktop-debug && ctest --preset desktop-debug`.
  - Repetir com `desktop-asan` e `desktop-tsan`.
  - `desktop-coverage` + `gcovr --fail-under-line 95 --fail-under-branch 90 --html-details`.
  - Rodada curta de fuzz com `desktop-fuzz`.
- **Simulador:** `tools/loopback_sim` com perda de 0–20%, jitter de 0–80 ms e reordenação, reportando perda e latência.
- **Kotlin:** `./gradlew :voice_platform:testDebugUnitTest koverVerify ktlintCheck` (≥ 90% de linhas e ≥ 85% de ramos), mais `connectedAndroidTest` no aparelho para os instrumentados.
- **Aparelho:** `fvm flutter build apk --debug` e `fvm flutter run` em pelo menos dois fabricantes (um deles Xiaomi ou Samsung), seguindo o aceite da fase e medindo a latência como na spec (pulso e gravação com um terceiro aparelho, ou o modo eco).
