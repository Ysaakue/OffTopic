# OffTopic — group voice room for motorcycle riders

Hands-free voice room for 2–8 riders without internet. Each intercom pairs over
Bluetooth HFP with its rider's phone only; the phones exchange audio over UDP
through one phone's Wi-Fi hotspot, and the host phone mixes (mix-minus).

- Specification (Portuguese, source of truth): [docs/SPEC.md](docs/SPEC.md)
- Implementation plan, phases, test catalog: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)
- Pinned toolchain and dependencies: [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)
- Wire protocol: `docs/PROTOCOL.md` (written at the start of phase 1, before any network code)

## Layout

| Path | What |
| --- | --- |
| `app/` | Flutter app (`offtopic`): clean architecture per feature (`domain/`, `data/`, `presentation/`), Riverpod 3, go_router, ARB localization |
| `packages/voice_core/` | C++17 core (CMake) + Dart FFI client. Builds `libvoice_core.so` |
| `packages/voice_platform/` | Kotlin (and later Swift) platform services through Pigeon |
| `tools/` | `verify.ps1`, `codegen.ps1`, `verify_core.sh`, coverage gate, loopback simulator (phase 1) |

## Commands

Always use the pinned SDK: `fvm flutter …` / `fvm dart …`, never the global `flutter`.

| Task | Command |
| --- | --- |
| Everything (a phase only closes when green) | `./tools/verify.ps1` (`-SkipCore`, `-SkipAndroid`, `-SkipCodegen` for faster loops) |
| Regenerate ffigen / Pigeon / l10n | `./tools/codegen.ps1` |
| C++ core only (inside WSL `Ubuntu-26.04`) | `bash tools/verify_core.sh` |
| Dart tests of one package | `fvm flutter test` in `app/` or `packages/<name>/` |
| Kotlin tests | `./tools/verify.ps1 -SkipCore` (sets `JAVA_HOME` to Flutter's JDK 21) |
| Debug APK | `fvm flutter build apk --debug` in `app/` |

## Rules from the specification

- Work phase by phase; do not start the next phase before the current acceptance criteria pass on real phones. At the end of each phase, summarize what was done and how to test it on the phone.
- Write `docs/PROTOCOL.md` with the exact packet formats before implementing the network.
- No audio sample ever goes through Dart or platform channels.
- The audio callback never allocates, locks, does I/O or logs; use lock-free SPSC ring buffers.
- The C++ core builds and runs its tests on desktop (Linux in WSL), not only on Android.
- C/C++ dependencies are git submodules pinned to a tag; nothing is downloaded during the build.
- Before adding a pub.dev package, check recent maintenance and real Android support; prefer own native code over small audio packages.
- `minSdk 29`, current `targetSdk`; handle API 31, 33, 34 and 37 differences with version checks (only inside factories that receive `SdkLevel`).
- Audio and network parameters live in a single configuration struct (`CoreConfig`), never scattered.
- When a requirement proves infeasible, stop and explain the alternative instead of working around it silently.

## Rules from the implementation plan

- **Language:** all code, comments, identifiers, commit messages, this file and `PROTOCOL.md` are in English. `SPEC.md` stays in Portuguese. User-facing text lives only in ARB files (`app/lib/l10n/app_en.arb` is the template, `app_pt.arb` the translation) — no hard-coded UI strings.
- **SOLID / clean code:** one responsibility per class; strategies chosen by factories; depend on abstractions injected through constructors or Riverpod providers; small interfaces (`PlatformInfoSource`, `RoomServiceControl`, …). Effective Dart with `very_good_analysis` (zero issues), `sealed` types with exhaustive `switch`, `Result<T>` across layers, no `dynamic`, no magic numbers. Same rigor for C++ (`.clang-format`, `.clang-tidy`, RAII) and Kotlin (ktlint).
- **Two entry points into `libvoice_core.so`:** Kotlin (JNI) owns the lifecycle and everything the notification shows (`init/start/stop`, network handle, pause/resume, mute); Dart (FFI) reads state and sends fine-grained controls. The C API is thread-safe.
- **Event payloads** delivered through `NativeCallable.listener` are allocated by the core and freed by Dart with `vc_free_event_payload` after decoding.
- **iOS readiness:** nothing Android-specific outside `src/platform/android/` (C++); Pigeon generates Kotlin and Swift from one definition; widgets and use cases ask `PlatformCapabilities`, never `Platform.isAndroid`.
- **Android 17 (`targetSdk 37`):** local network traffic needs the runtime permission `ACCESS_LOCAL_NETWORK` (group `NEARBY_DEVICES`), requested together with `BLUETOOTH_CONNECT`. See the addendum in `docs/SPEC.md`.

## Testing rules

- Every new class ships with its tests in the same commit. Test folders mirror source folders.
- Logic lives in pure, deterministic classes; threads, clock, sockets, audio devices and Android services sit behind interfaces. No real time in unit tests (`FakeClock`, `fake_async`, `runTest`).
- Each interface has a contract suite run against every implementation, fakes included (`test/contracts/`). Public fakes live in each package's `lib/testing.dart`.
- Coverage gates (enforced by `verify.ps1`; they may only go up):
  - C++ `src/`: lines ≥ 95 %, branches ≥ 90 % (gcovr).
  - Dart `domain/`, `data/`, controllers, `core/result/` and the packages' `lib/src/`: 100 % lines. Whole Dart workspace: ≥ 95 %.
  - Kotlin `voice_platform` (without Pigeon output): lines ≥ 90 %, branches ≥ 85 % (Kover).
- Closed exclusion list: generated code (`*.g.dart`, `l10n/generated`, Pigeon Kotlin/Swift), `third_party/`, `tests/`, `tools/`, and device-only shells (`src/platform/android/*`, the device-opening part of `MiniaudioDevice`, `NativeVoiceCore.kt`, `main.dart`). Each exclusion marker (`// coverage:ignore-*`, `// GCOVR_EXCL_*`, `@CoverageExcluded`) carries a comment explaining why.

## Known pitfalls (learned in phase 0)

- **Gradle JDK:** the system `JAVA_HOME` points to JDK 17, but Robolectric for SDK 37 needs Java 21. Run Gradle through `verify.ps1`, or point `JAVA_HOME` to the JDK shown by `fvm flutter doctor -v`.
- **Robolectric on SDK 37** needs `--add-opens java.base/java.io` and `--add-exports java.base/jdk.internal.access` (already in `voice_platform/android/build.gradle.kts`).
- **AGP:** 9.2.x requires Gradle ≥ 9.4.1, above what Flutter 3.47.9 supports (9.3.1). Stay on AGP 9.1.x until a newer Flutter raises the limit.
- **ffigen on Windows** loads `libclang.dll` from the pinned NDK and needs that directory on `PATH`: always run it through `tools/codegen.ps1`. Top-level declarations are excluded by default; the `Visitor` in `tool/ffigen.dart` keeps the `vc_` symbols.
- **Pigeon 29:** `dartTestOut` is deprecated — mock the generated `VoicePlatformHostApi` instead. `@async` host methods become Kotlin `suspend fun`s (needs `kotlinx-coroutines-android`).
- **ThreadSanitizer** replaces `operator new`, so `AllocationGuard` tests skip themselves in `desktop-tsan`; zero-allocation checks run in the debug, ASan and coverage presets.
- **Riverpod 3** retries failing providers automatically; screens with an explicit retry button pass `retry: noAutomaticRetry`.
- **Coverage of `const` constructors:** an instance created only in `const` contexts is built at compile time, so its constructor line may show as uncovered and make the gate flaky. Instantiate the widget at least once at runtime in a test (e.g. `OffTopicApp(key: UniqueKey())`).
- **`StreamController.close()`** never completes for a stream nobody listened to: do not await it in test teardown.
- **Dart 3.13 lints** (`very_good_analysis` 11) prefer `new(...)` / `factory name(...)` constructors and private named parameters; `fvm dart fix --apply` converts them. Pigeon's definition file keeps classic constructors (it is parser input).
