# Sala de voz para motos — especificação para o Claude Code

Oct 30, 2026 · @Isaac

## Objetivo e contexto

O objetivo é um app Android que cria uma sala de voz em grupo para 2 a 8 motociclistas sem depender de internet, usando o hotspot de um dos celulares como rede local.

Os intercomunicadores do grupo só conseguem se conectar a um outro intercomunicador por vez. A solução é que cada intercom se conecte por Bluetooth (perfil HFP) apenas ao celular do próprio piloto, e os celulares troquem o áudio entre si por Wi-Fi.

| Requisito | Meta |
| --- | --- |
| Participantes por sala | 2 a 8 |
| Latência boca–ouvido | até 250 ms (alvo 150–200 ms) |
| Funcionar sem internet | Obrigatório |
| Operação | Mãos livres, tela bloqueada, app em segundo plano |
| Reconexão | Automática, sem tocar na tela |
| Plataforma | Android 10+ (API 29) primeiro; iPhone como cliente numa fase posterior |

Fora do escopo inicial: música e GPS em alta qualidade durante a sala, mensagens de texto, gravação de áudio.

## Decisões de arquitetura

Cada celular é a ponte entre o intercom do piloto (Bluetooth) e a rede do grupo (Wi-Fi), e o celular anfitrião mistura as vozes de todos.

&#91;embedded content: arquitetura da sala · 4 pilotos, 1 anfitrião\]

A linha tracejada é local: no anfitrião, o próprio microfone e alto-falante entram no mixer sem passar pela rede.

| Decisão | Escolha | Motivo |
| --- | --- | --- |
| Ligação intercom ↔ celular | Bluetooth HFP, só com o celular do próprio piloto | Contorna o limite de uma conexão dos intercomunicadores |
| Ligação entre celulares | Wi-Fi pelo hotspot de um dos celulares | Bluetooth entre celulares não serve: rádio já ocupado pelo HFP, máximo de 7 dispositivos, alcance curto |
| Topologia | Estrela, com o anfitrião mixando (mix-minus) | Cada celular envia 1 e recebe 1 fluxo, qualquer que seja o tamanho do grupo; malha não ajuda porque no hotspot todo tráfego já passa pelo anfitrião |
| Transporte de áudio | UDP unicast | Multicast no Wi-Fi não tem retransmissão, vai na taxa básica e muitos hotspots descartam |
| Codec | Opus 16 kHz mono, quadros de 20 ms, 24 kbps, FEC e DTX | Mesma banda do HFP; FEC e ocultação de perda cobrem pacotes perdidos |
| Wi-Fi Direct | Não usar | Confirmações na tela e comportamento diferente em cada fabricante |
| Dono da sessão | Núcleo C++ dentro do foreground service | A sala sobrevive com a interface fechada |

## Stack e estrutura do repositório

Flutter cuida da interface, um núcleo C++ faz todo o áudio e a rede em tempo real (chamado via `dart:ffi`) e um plugin Kotlin dá acesso às APIs do Android. Regra central: nenhuma amostra de áudio passa pelo Dart nem por platform channels.

| Camada | Tecnologia | Responsabilidade |
| --- | --- | --- |
| Interface | Flutter (Dart 3), Riverpod | Telas, criar/entrar na sala, QR code, configurações, exibir estado |
| Núcleo de sessão, áudio e rede | C++17, CMake via NDK | Controle TCP, áudio UDP, captura, processamento, Opus, jitter buffer, mixagem |
| Plataforma | Kotlin (plugin Flutter, canais tipados com Pigeon) | Foreground service, rota Bluetooth, Wi-Fi, permissões |

O núcleo C++ é dono da sessão inteira (controle e áudio) e roda dentro do foreground service. A interface Flutter pode ser fechada e reaberta sem derrubar a sala.

Bibliotecas do núcleo, todas como submódulos git com versão fixada:

- miniaudio: captura e reprodução (AAudio no Android, Core Audio no iOS), roda também no desktop para testes.
- libopus: codec de voz.
- webrtc-audio-processing (extração do WebRTC mantida pelo projeto PulseAudio): supressão de ruído, controle de ganho, cancelamento de eco, detecção de voz.
- GoogleTest: testes unitários do núcleo.

Pacotes Flutter: `ffigen` (gera os bindings do C), `pigeon` (canais Kotlin tipados), `flutter_riverpod`, `mobile_scanner` (ler QR), `qr_flutter` (gerar QR), `permission_handler`.

```
moto-voice/
├── app/                         # app Flutter (interface)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── features/room/       # criar/entrar, lista de participantes
│   │   ├── features/settings/
│   │   └── core/                # wrappers do voice_core e voice_platform
│   └── android/
├── packages/
│   ├── voice_core/              # plugin FFI em C++
│   │   ├── include/voice_core.h # API C pública
│   │   ├── src/                 # engine, apm, codec, jitter, mixer, net, session
│   │   ├── third_party/         # miniaudio, opus, webrtc-audio-processing
│   │   ├── tests/               # GoogleTest
│   │   └── CMakeLists.txt
│   └── voice_platform/          # plugin Kotlin (Pigeon)
│       └── android/src/main/kotlin/
│           ├── VoiceService.kt  # foreground service
│           ├── AudioRouter.kt   # rota Bluetooth HFP
│           └── WifiBinder.kt    # WifiLock + vínculo com a rede Wi-Fi
├── tools/loopback_sim/          # roda o núcleo no desktop com perda e jitter simulados
└── docs/
    ├── SPEC.md                  # este documento
    └── PROTOCOL.md              # formato exato dos pacotes
```

## Núcleo de áudio em C++

O núcleo trabalha em 16 kHz mono do início ao fim, com quadros Opus de 20 ms (320 amostras), que é a mesma banda que o Bluetooth HFP entrega (mSBC).

Caminho de envio:

1. Captura com miniaudio (backend AAudio), usage `VOICE_COMMUNICATION` e input preset `VOICE_COMMUNICATION`, para o Android rotear para o intercom.
2. Ring buffer SPSC sem lock entre o callback de áudio e a thread de processamento.
3. webrtc-audio-processing em blocos de 10 ms: supressão de ruído no nível alto (vento), controle automático de ganho, detecção de voz; cancelamento de eco opcional.
4. Portão de voz: só transmite quando há fala, com 300 ms de cauda; modo push-to-talk como alternativa.
5. Opus: aplicação VOIP, 16 kHz, 24 kbps, FEC in-band ligado, perda esperada configurada em 10%, DTX ligado.
6. Envio por UDP ao anfitrião.

Caminho de recepção (cliente):

1. Recebe pelo UDP um único fluxo já mixado pelo anfitrião.
2. Jitter buffer adaptativo: alvo inicial 40 ms, mínimo 20 ms, máximo 120 ms; descarta pacotes atrasados demais.
3. Decodificação Opus; pacote perdido é reconstruído pelo FEC do pacote seguinte ou pela ocultação de perda (PLC).
4. Reprodução com miniaudio no intercom.

No anfitrião, o mixer roda a cada 20 ms:

- Um jitter buffer e um decoder Opus por participante.
- Para cada participante, soma todas as vozes menos a dele (mix-minus), aplica um limitador suave contra clipping, codifica e envia.
- O anfitrião também é participante: o microfone e o alto-falante dele entram direto no mixer, sem passar pela rede.

Regras de tempo real:

- O callback de áudio não aloca memória, não usa lock, não faz I/O e não escreve log.
- Threads separadas para áudio, rede e mixagem, conversando por ring buffers SPSC.
- Todos os parâmetros (taxa, quadro, bitrate, limites do jitter buffer, portas) ficam numa única struct de configuração.

API C exposta ao Dart (`voice_core.h`), ponto de partida:

```
typedef enum { VC_ROLE_CLIENT = 0, VC_ROLE_HOST = 1 } vc_role;

typedef struct {
  vc_role     role;
  const char* host_ip;      // ignorado no anfitrião
  uint16_t    control_port; // TCP
  uint16_t    audio_port;   // UDP
  const char* display_name;
  int         bitrate_bps;  // padrão 24000
} vc_config;

typedef struct {
  int   participants;
  float loss_pct;
  float jitter_ms;
  int   jitter_buffer_ms;
  int   rtt_ms;
  float input_level;
} vc_stats;

int  vc_init(const vc_config* cfg);
int  vc_start(void);
void vc_stop(void);
void vc_set_mute(int muted);
void vc_set_ptt(int pressed);
void vc_set_output_gain(float gain);
int  vc_get_stats(vc_stats* out);
void vc_set_network_handle(uint64_t net_handle); // vem do Kotlin
void vc_set_event_callback(void (*cb)(int event, const char* json));
```

Eventos do núcleo (participante entrou/saiu, quem está falando, conexão perdida/restabelecida) chegam ao Dart por `NativeCallable.listener`, que é seguro para chamadas vindas de threads nativas.

## Rede e protocolo

O anfitrião liga o hotspot do sistema; o controle vai por TCP e o áudio por UDP unicast, sempre com o anfitrião no centro.

Rede:

- Hotspot normal do Android, em 2,4 GHz, com nome e senha fixos definidos pelo grupo (cada amigo salva uma vez). O app não consegue ligar esse hotspot sozinho: ele detecta o estado e abre a tela de configurações para o usuário.
- Fase posterior: LocalOnlyHotspot, que o app liga sozinho, mas sem internet e com nome e senha aleatórios a cada início; exige compartilhar por QR code e pede a permissão `NEARBY_WIFI_DEVICES` no Android 13+ (localização no 12 ou anterior).
- Descoberta: o cliente usa o gateway padrão da rede Wi-Fi (`LinkProperties`) como IP do anfitrião. Alternativa: QR code com IP e portas.
- Portas padrão: TCP 47800 (controle) e UDP 47801 (áudio), configuráveis.
- Proibido usar multicast ou broadcast para áudio: no Wi-Fi não há retransmissão, a taxa é a básica e muitos hotspots descartam esses pacotes.

Canal de controle (TCP, mensagens JSON com prefixo de tamanho de 4 bytes):

| Mensagem | Direção | Conteúdo |
| --- | --- | --- |
| `HELLO` | cliente → anfitrião | nome, `device_id` estável, versão do protocolo |
| `WELCOME` | anfitrião → cliente | `participant_id`, parâmetros do codec, lista de participantes |
| `ROSTER` | anfitrião → todos | lista atualizada (entrou, saiu, mute) |
| `MUTE` | cliente → anfitrião | estado de mute |
| `PING` / `PONG` | ambos | a cada 1 s; sem resposta por 5 s = participante removido |
| `BYE` | ambos | saída voluntária |

Na reconexão, o cliente reenvia `HELLO` com o mesmo `device_id` e recupera o mesmo `participant_id`.

Pacote de áudio (UDP), cabeçalho de 8 bytes em ordem de rede (big-endian):

| Campo | Bytes | Descrição |
| --- | --- | --- |
| versão + flags | 1 | 4 bits de versão; flags: DTX, FEC, keepalive |
| `participant_id` | 1 | 0–255 |
| `seq` | 2 | número de sequência, com volta a zero |
| `timestamp` | 4 | em amostras de 16 kHz |
| payload | n | um quadro Opus |

Em silêncio (DTX), o cliente envia um keepalive UDP por segundo, usado para detectar queda e medir RTT.

Banda: cerca de 40 kbps por fluxo com cabeçalhos; com 8 participantes o anfitrião recebe e envia em torno de 0,3 Mbps em cada sentido.

Segurança: a rede já é protegida pelo WPA2 do hotspot; criptografia na aplicação fica fora do escopo inicial.

Fase futura: um servidor relay na internet com o mesmo protocolo, para trocar automaticamente para os dados móveis quando o Wi-Fi cair. Por isso o núcleo deve tratar o anfitrião como um endereço qualquer, sem supor que está na rede local.

## Integração Android (plugin Kotlin)

O plugin `voice_platform` garante três coisas ao núcleo C++: um processo que sobrevive em segundo plano, o áudio roteado para o intercom e o tráfego saindo pelo Wi-Fi.

Foreground service (`VoiceService`):

- `foregroundServiceType="microphone|connectedDevice"`, iniciado enquanto o app está em primeiro plano (exigência do Android 14+).
- Notificação persistente com botões de mute e sair; carrega a biblioteca nativa e inicia o núcleo.
- Pedir exclusão da otimização de bateria (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) e mostrar orientações por fabricante (Xiaomi, Samsung, Motorola), que matam serviços em segundo plano.

Rota de áudio (`AudioRouter`):

- `AudioManager.MODE_IN_COMMUNICATION`.
- API 31+: `setCommunicationDevice()` com o dispositivo `TYPE_BLUETOOTH_SCO`; API 29–30: `startBluetoothSco()`.
- Monitorar `AudioDeviceCallback` e refazer a rota quando o intercom desconectar e voltar.
- Foco de áudio `AUDIOFOCUS_GAIN`; ao perder o foco (ligação telefônica), pausar a sala e retomar sozinho no fim.

Wi-Fi (`WifiBinder`):

- `WifiLock` em modo `WIFI_MODE_FULL_LOW_LATENCY` (API 29+) e wake lock parcial.
- O Android marca a rede do hotspot como "sem internet" e pode mandar o tráfego pelos dados móveis. Solução: `ConnectivityManager.requestNetwork()` com `TRANSPORT_WIFI` (sem exigir internet), passar `network.getNetworkHandle()` ao núcleo e, no C++, vincular cada socket com `android_setsocknetwork()` (NDK, `android/multinetwork.h`).

Permissões no manifesto: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT` (API 31+), `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE` e `FOREGROUND_SERVICE_CONNECTED_DEVICE` (API 34+), `POST_NOTIFICATIONS` (API 33+), `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`, `WAKE_LOCK`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. `NEARBY_WIFI_DEVICES` só quando entrar o LocalOnlyHotspot.

Interface Pigeon (Dart ↔ Kotlin): `startRoom(role, hostIp?)`, `stopRoom()`, `setMute(bool)`, `openHotspotSettings()`, `requestBatteryExemption()` e um stream de estado (rota de áudio, Wi-Fi, serviço ativo).

## Interface Flutter

A interface é mínima, feita para ser usada de relance e com luva; ela só mostra estado e envia comandos.

1. Início: nome do piloto e dois botões grandes, "Criar sala" (sou o anfitrião) e "Entrar na sala".
2. Criar sala: checklist com hotspot ligado e intercom conectado, botão que abre as configurações do hotspot e QR code com IP e portas.
3. Entrar na sala: entra automaticamente pelo gateway da rede Wi-Fi; leitura de QR como alternativa.
4. Sala: lista de participantes com indicador de quem está falando e da qualidade da conexão (verde, amarelo ou vermelho conforme perda e jitter), botão de mute grande, botão de sair e a rota de áudio atual (intercom ou alto-falante).
5. Configurações: modo de fala (voz ou push-to-talk), sensibilidade do detector de voz, bitrate, portas e uma tela de diagnóstico (perda, jitter, tamanho do jitter buffer, RTT).

Regras:

- Estado vem do núcleo por eventos (`NativeCallable.listener`) e por leitura de `vc_get_stats` a 4 Hz.
- Fechar a interface não encerra a sala; reabrir o app reconecta a interface à sessão em andamento.
- Botões com pelo menos 64 dp, tema escuro de alto contraste, opção de manter a tela ligada.

## Fases de implementação

A implementação segue fase a fase; uma fase só termina quando o critério de aceite é cumprido em aparelhos reais.

1. Fase 0 — Esqueleto
   - Repositório com o app Flutter, o plugin FFI compilando o C++ pelo CMake/NDK e o plugin Kotlin com Pigeon.
   - Aceite: o APK roda e mostra a versão retornada por uma função do C++ (`vc_version()`).
2. Fase 1 — Prova de conceito de áudio, 2 celulares, sem Bluetooth
   - Captura com miniaudio, Opus, UDP, jitter buffer e reprodução; IP digitado à mão; áudio no fone com fio ou alto-falante.
   - Aceite: 10 minutos de conversa contínua sem cortes; latência medida de até 150 ms; estatísticas na tela.
3. Fase 2 — Bluetooth e processamento
   - Rota HFP para o intercom, webrtc-audio-processing (ruído e ganho), portão de voz e DTX.
   - Aceite: conversa pelos intercomunicadores reais do grupo; ruído de vento atenuado (teste com a moto parada e ventilador); latência de até 250 ms.
4. Fase 3 — Anfitrião e grupo
   - Canal de controle TCP, lista de participantes, mixer mix-minus, descoberta pelo gateway.
   - Aceite: 4 celulares, todos se ouvem, ninguém ouve a própria voz, 30 minutos sem cortes.
5. Fase 4 — Robustez
   - Foreground service, `WifiLock`, vínculo com a rede Wi-Fi, reconexão automática, foco de áudio, sala independente da interface.
   - Aceite: 1 hora com a tela bloqueada; sair do alcance e voltar reconecta em até 10 s sem tocar na tela; uma ligação recebida pausa e a sala volta sozinha.
6. Fase 5 — Teste de estrada e ajuste
   - Medir alcance, perda, bateria e temperatura do anfitrião; ajustar jitter buffer, bitrate e FEC.
   - Aceite: relatório com perda por distância entre motos e tempo de reconexão.
7. Fase 6 (opcional) — Fallback pela internet
   - Servidor relay UDP com o mesmo protocolo e troca automática entre Wi-Fi e dados móveis.
8. Fase 7 (opcional) — iPhone como cliente e LocalOnlyHotspot
   - Plugin Swift (`AVAudioSession` em `playAndRecord` com Bluetooth, modo de áudio em segundo plano) reaproveitando o núcleo C++; LocalOnlyHotspot com QR no Android.

## Limitações conhecidas e riscos

O maior risco é o alcance do hotspot entre motos em movimento; os demais têm mitigação conhecida.

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Alcance do hotspot: dezenas de metros a cerca de 100–200 m com visada livre | Quedas quando o grupo se espalha | Anfitrião no meio do comboio, celulares no suporte do guidão, 2,4 GHz, reconexão rápida, fallback pela internet |
| Limite de clientes do hotspot (5 a 10, varia por fabricante) | Grupos maiores não entram | Limitar a sala a 8 e avisar na interface |
| Bateria e calor do anfitrião | O sistema pode desligar o hotspot | Anfitrião no carregador, rodízio de anfitrião |
| Latência do Bluetooth HFP (60–150 ms ida e volta) | Total de 150–250 ms | Fora do nosso controle; minimizar o resto da cadeia |
| HFP é qualidade de voz | Música e GPS mono ou interrompidos durante a sala | Documentar; fora do escopo |
| Intercomunicadores baratos com comportamento estranho no modo telefone | Rota falha ou VOX não aciona | Testar cedo, na fase 2, com os modelos do grupo |
| Fabricantes que matam serviços em segundo plano | Sala cai sozinha | Exclusão da otimização de bateria e guia por fabricante |
| Android marca o hotspot como "sem internet" | Tráfego sai pelos dados móveis | `requestNetwork` + `android_setsocknetwork` |
| miniaudio não rotear para o Bluetooth SCO em algum aparelho | Sem áudio no intercom | Backend alternativo com Oboe só no Android |
| Ligações telefônicas | Interrompem a sala | Foco de áudio e retomada automática |

## Testes e medições

O núcleo é testado primeiro no desktop, com rede simulada, e só depois nos celulares e na estrada.

- Testes unitários C++ (GoogleTest): jitter buffer (reordenação, perda, atraso, volta do `seq`), mixer (mix-minus, limitador), parser e montagem de pacotes.
- Simulador `tools/loopback_sim`: roda o núcleo no Linux ou macOS com perda de 0–20%, jitter de 0–80 ms e reordenação configuráveis.
- Latência ponta a ponta: emitir um pulso curto no celular A e gravar, com um terceiro aparelho, o som saindo de A e de B; a diferença é a latência. Um modo eco no anfitrião serve para medir o RTT de áudio sozinho.
- Diagnóstico em tela: perda, jitter, tamanho do jitter buffer, RTT e número de participantes.
- Teste de estrada: anotar a distância entre as motos (GPS) contra a perda, a bateria e a temperatura do anfitrião a cada 15 minutos e o tempo de cada reconexão.
- Aparelhos: pelo menos dois fabricantes diferentes, um deles Xiaomi ou Samsung.

## Regras de trabalho para o Claude Code

Exporte este documento em Markdown, salve como `docs/SPEC.md` e crie um `CLAUDE.md` na raiz com as regras abaixo e um link para a especificação.

- Trabalhar fase a fase; não começar a próxima sem cumprir o aceite da atual. Ao fim de cada fase, resumir o que foi feito e como testar no celular.
- Escrever `docs/PROTOCOL.md` com o formato exato dos pacotes antes de implementar a rede.
- Nenhuma amostra de áudio passa pelo Dart nem por platform channels.
- O callback de áudio não aloca, não usa lock, não faz I/O e não escreve log; usar ring buffers SPSC sem lock.
- O núcleo C++ compila e roda os testes também no desktop (Linux ou macOS), não só no Android.
- Dependências C/C++ como submódulos git com versão fixada; nada é baixado durante o build.
- Antes de adicionar um pacote do pub.dev, conferir manutenção recente e suporte real a Android; preferir código nativo próprio a pacotes pequenos de áudio.
- `minSdk 29`, `targetSdk` atual; tratar as diferenças das APIs 31, 33 e 34 com verificação de versão.
- Parâmetros de áudio e rede numa única struct de configuração, nunca espalhados pelo código.
- Quando um requisito desta especificação se mostrar inviável, parar e explicar a alternativa em vez de contornar silenciosamente.

## Referências

Bibliotecas e ferramentas:

- [miniaudio](https://miniaud.io)
- [Opus](https://opus-codec.org)
- [webrtc-audio-processing (PulseAudio)](https://gitlab.freedesktop.org/pulseaudio/webrtc-audio-processing)
- [Oboe](https://github.com/google/oboe) (backend alternativo no Android)
- [Dart: interoperabilidade com C](https://dart.dev/interop/c-interop)
- [ffigen](https://pub.dev/packages/ffigen) · [pigeon](https://pub.dev/packages/pigeon)

Android:

- [AudioManager](https://developer.android.com/reference/android/media/AudioManager) (`setCommunicationDevice`, `MODE_IN_COMMUNICATION`)
- [WifiManager](https://developer.android.com/reference/android/net/wifi/WifiManager) (`WifiLock`, `startLocalOnlyHotspot`)
- [NDK: rede com múltiplas interfaces](https://developer.android.com/ndk/reference/group/networking) (`android_setsocknetwork`)
- [Tipos de foreground service](https://developer.android.com/develop/background-work/services/fg-service-types)
- [Don't kill my app](https://dontkillmyapp.com) (comportamento de bateria por fabricante)
- [LocalOnlyHotspot: nome e senha aleatórios, sem internet (B4X)](https://www.b4x.com/android/forum/posts/622194/)

Pesquisa feita durante o planejamento:

- [audio\_io](https://pub.dev/documentation/audio_io/0.6.0/): plugin Flutter que oferece isolate dedicado ao áudio para evitar travadas do isolate principal.
- [Baremetal Audio Engine](https://pub.dev/documentation/baremetal_audio/latest): exemplo de núcleo C++ com miniaudio lido pelo Dart via FFI, sem platform channels.
- [flutter\_opus](https://pub.dev/packages/flutter_opus): exemplo de pacote pequeno e imaturo; motivo para manter o Opus no núcleo C++.
- [EmCon](https://hunted.space/dashboard/emcon) e [Infinite iNtercom](https://spark.mwm.ai/us/apps/infinite-intercom/1206022901): apps de voz local existentes, para comparar a experiência.

## Adendo da implementação (01/11/2026)

Mudanças em relação ao texto acima, decididas durante o planejamento e a fase 0. Os detalhes estão em [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

- **Permissão de rede local (Android 17).** Com `targetSdk 37`, o Android bloqueia todo o tráfego de rede local (TCP e UDP, entrada e saída, inclusive dos sockets do NDK) de quem não tem a permissão de tempo de execução `ACCESS_LOCAL_NETWORK`, do grupo `NEARBY_DEVICES`. Ela entra na lista de permissões do manifesto e é pedida junto com `BLUETOOTH_CONNECT`, antes de iniciar a sala. Se for negada, a sala não inicia e a interface explica o motivo. O diagnóstico usa `android_getnetworkblockedreason()` para separar "bloqueado pela permissão" de "fora de alcance".
- **Versões.** `targetSdk 37`, NDK r30, CMake 4.1.2, Flutter 3.47.9 fixado pelo FVM. O AGP fica na linha 9.1, porque o 9.2 exige um Gradle que o Flutter 3.47.9 ainda não suporta. Lista completa em [DEPENDENCIES.md](DEPENDENCIES.md).
- **QR code.** O pacote `qr_flutter` está sem versão desde 2023, o que viola a regra de manutenção desta especificação. A geração usa o pacote `qr`, mantido, com um widget próprio de desenho.
- **Dependências C++ extras.** `nlohmann/json`, para as mensagens JSON do controle, e `abseil-cpp`, exigido pelo `webrtc-audio-processing` 2.1. Os dois entram como submódulos com versão fixada.
- **Testes no desktop.** O núcleo C++ roda os testes no Linux dentro do WSL (Ubuntu 26.04), já que a máquina de desenvolvimento é Windows.
