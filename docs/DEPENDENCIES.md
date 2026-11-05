# Dependencies and toolchain

Every version below is pinned. Policy: at the start of each phase run
`fvm flutter pub outdated` and `fvm releases`, and check the submodule tags;
upgrade only when compatibility is documented, in a dedicated commit, and update
this file. Reasons for every choice: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) ("Versões").

Last checked: 2026-11-01.

## Windows host

| Tool | Version | Notes |
| --- | --- | --- |
| FVM | 4.3.2 | `dart pub global activate fvm 4.3.2`; `%LOCALAPPDATA%\Pub\Cache\bin` on the user `PATH` |
| Flutter / Dart | 3.47.9 / 3.13.7 | Pinned in `.fvmrc`; use `fvm flutter` / `fvm dart`. The global Flutter SDK is not used |
| Android platform | `platforms;android-37.0` | `compileSdk 37`, `targetSdk 37`, `minSdk 29` |
| Build-tools | 37.0.0 | |
| NDK | 30.0.16248370 (r30) | Also provides `libclang.dll` for ffigen |
| CMake (Android SDK) | 4.1.2 | Used by Gradle `externalNativeBuild` |
| JDK | Android Studio JBR 21 | Required by Robolectric for SDK 37. `tools/verify.ps1` points Gradle to the JDK reported by `fvm flutter doctor -v` (the system `JAVA_HOME` is JDK 17) |
| Gradle | 9.3.1 | Wrapper in `app/android`; highest version Flutter 3.47.9 supports |
| Android Gradle Plugin | 9.1.1 | 9.2.x needs Gradle ≥ 9.4.1 |
| Kotlin Gradle Plugin | 2.4.0 | Highest version Flutter 3.47.9 knows |
| Windows Developer Mode | on | Lets FVM create symlinks without admin rights |

Android SDK packages: `sdkmanager "ndk;30.0.16248370" "cmake;4.1.2" "build-tools;37.0.0" "platforms;android-37.0"`.

## WSL (`Ubuntu-26.04`) — C++ core tests

| Tool | Version | Install |
| --- | --- | --- |
| GCC / G++ | 15.2 | `apt install build-essential` |
| Clang / LLVM (+ libFuzzer runtime) | 21.1 | `apt install clang llvm lld libclang-rt-21-dev` |
| Ninja | 1.13.2 | `apt install ninja-build` |
| CMake | 4.1.2 | `pipx install cmake==4.1.2` (same version as the Android SDK) |
| gcovr | 8.8 | `pipx install gcovr==8.8` |
| lcov / genhtml | 2.x | `apt install lcov` |

`pipx` installs into `~/.local/bin`; `tools/verify_core.sh` adds it to `PATH`.
Desktop build trees live in `~/.cache/offtopic/voice_core/<preset>` (fast ext4).

## C/C++ submodules (`packages/voice_core/third_party/`)

| Library | Tag | Phase | Status |
| --- | --- | --- | --- |
| googletest (+ gmock) | `v1.18.0` | 0 | added |
| miniaudio | `0.11.26` | 1 | added (low-level device API only: `MA_NO_ENGINE` and friends) |
| opus | `v1.6.1` | 1 | added (DRED/OSCE off: they need downloaded model files) |
| nlohmann/json | `v3.12.0` | 3 | planned |
| webrtc-audio-processing | `v2.1` | 2 | added (Meson upstream: built by our `cmake/webrtc_apm.cmake`, which mirrors its source lists) |
| abseil-cpp | `20250127.2` | 2 | added: the newest LTS that builds webrtc-apm 2.1 (from 20250512 on, `absl::Nullable`/`absl::Nonnull` are gone) |
| oboe | `1.11.0` | 2 | only if miniaudio fails on Bluetooth SCO |

Nothing is downloaded during the build. After cloning: `git submodule update --init --recursive`.

## Dart packages

| Package | Constraint | Where |
| --- | --- | --- |
| `flutter_riverpod` | ^3.4.3 | app |
| `go_router` | ^18.1.2 | app |
| `equatable` | ^3.0.0 | app, voice_core, voice_platform |
| `intl` | pinned by `flutter_localizations` | app |
| `ffi` | ^2.2.0 | voice_core |
| `ffigen` (dev) | ^23.0.0 | voice_core (`tool/ffigen.dart`, Dart API — the YAML config is deprecated) |
| `pigeon` (dev) | ^29.1.0 | voice_platform |
| `very_good_analysis` (dev) | ^11.0.0 | workspace root |
| `mocktail` (dev) | ^1.0.5 | all |
| `fake_async` (dev) | ^1.3.3 | app |
| `permission_handler` | ^13.0.2 | app (Android 14.1.1 implementation: `Permission.accessLocalNetwork` for API 37) |
| `permission_handler_platform_interface` (dev) | ^4.4.1 | app (fake platform in tests) |
| `plugin_platform_interface` (dev) | ^2.1.8 | app (`MockPlatformInterfaceMixin`) |
| `shared_preferences` | ^2.5.6 | app (talk settings; asynchronous API) |
| `shared_preferences_platform_interface` (dev) | ^2.4.2 | app (in-memory store in tests) |

Added in later phases: `mobile_scanner` ^7.4.2, `qr` ^4.0.1 (replaces the
unmaintained `qr_flutter`).

## Kotlin / Gradle (`packages/voice_platform/android`)

| Dependency | Version |
| --- | --- |
| kotlinx-coroutines-android (needed by Pigeon `suspend` host methods) | 1.11.0 |
| androidx.core:core-telecom (the room as a self-managed call; stable 1.1.0 of 2026-11-04) | 1.1.0 |
| JUnit | 4.13.2 |
| kotlin-test-junit | KGP 2.4.0 |
| MockK | 1.14.11 |
| Robolectric (supports SDK 37) | 4.17 |
| androidx.test core / ext-junit | 1.7.0 / 1.3.0 |
| kotlinx-coroutines-test | 1.11.0 |
| Kover (Gradle plugin) | 0.9.11 |
| ktlint-gradle (ktlint 1.8.0) | 14.2.0 |

## Fresh machine setup

1. Android Studio (for the SDK manager and JBR 21), Windows Developer Mode on.
2. `dart pub global activate fvm 4.3.2`, then in the repository: `fvm install` and `fvm use 3.47.9`.
3. `sdkmanager` packages above, then `fvm flutter doctor --android-licenses`.
4. `wsl --install Ubuntu-26.04` and the WSL tools above.
5. `git submodule update --init --recursive`, `fvm flutter pub get`, `./tools/verify.ps1`.
