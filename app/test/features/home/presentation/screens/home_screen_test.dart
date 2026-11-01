import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/home/presentation/screens/home_screen.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late FakeVoiceCoreClient voiceCore;
  late FakeVoicePlatformGateway platform;

  setUp(() {
    voiceCore = FakeVoiceCoreClient(version: '0.1.0');
    platform = FakeVoicePlatformGateway(platformInfo: samplePlatformInfo);
  });

  tearDown(() => platform.dispose());

  Future<void> pumpHome(WidgetTester tester, {Locale? locale}) =>
      tester.pumpLocalized(
        // Runtime key: see app_test.dart (coverage of const constructors).
        HomeScreen(key: UniqueKey()),
        locale: locale ?? const Locale('en'),
        overrides: [
          voiceCoreClientProvider.overrideWithValue(voiceCore),
          voicePlatformGatewayProvider.overrideWithValue(platform),
        ],
      );

  testWidgets('shows a loading state first', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('home.loading')), findsOneWidget);
    expect(find.text('Checking the voice core…'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the core version and the device', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Voice core 0.1.0'), findsOneWidget);
    expect(find.text('Xiaomi Redmi Note 13 · Android 17'), findsOneWidget);
    expect(find.byKey(const Key('home.loading')), findsNothing);
  });

  testWidgets('explains a core failure and recovers on retry', (tester) async {
    voiceCore.versionError = const VoiceCoreException('not loaded');
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('The voice core did not respond.'), findsOneWidget);

    voiceCore.versionError = null;
    await tester.tap(find.byKey(const Key('home.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Voice core 0.1.0'), findsOneWidget);
  });

  testWidgets('explains a platform failure', (tester) async {
    platform.failWith(
      PlatformCall.getPlatformInfo,
      const VoicePlatformException(code: 'channel-error'),
    );
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not read the phone information.'), findsOneWidget);
  });

  testWidgets('is translated to Portuguese', (tester) async {
    await pumpHome(tester, locale: const Locale('pt'));
    await tester.pumpAndSettle();

    expect(find.text('Núcleo de voz 0.1.0'), findsOneWidget);
    expect(
      find.text('Sala de voz em grupo para motociclistas, sem internet'),
      findsOneWidget,
    );
  });

  testWidgets('meets the tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    voiceCore.versionError = const VoiceCoreException('not loaded');
    await pumpHome(tester);
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the retry button is at least 64 dp tall', (tester) async {
    voiceCore.versionError = const VoiceCoreException('not loaded');
    await pumpHome(tester);
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byKey(const Key('home.retry')));
    expect(size.height, greaterThanOrEqualTo(64));
  });

  testWidgets('keeps the loading state while the platform is slow', (
    tester,
  ) async {
    final pending = Completer<void>();
    platform.holdUntil(PlatformCall.getPlatformInfo, pending.future);
    await pumpHome(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('home.loading')), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Voice core 0.1.0'), findsOneWidget);
  });
}
