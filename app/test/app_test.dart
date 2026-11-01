import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/app.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/home/presentation/screens/home_screen.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_platform/testing.dart';

import 'helpers/fixtures.dart';

void main() {
  late FakeVoicePlatformGateway platform;

  setUp(
    () => platform = FakeVoicePlatformGateway(platformInfo: samplePlatformInfo),
  );
  tearDown(() => platform.dispose());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceCoreClientProvider.overrideWithValue(
          FakeVoiceCoreClient(version: '0.1.0'),
        ),
        voicePlatformGatewayProvider.overrideWithValue(platform),
      ],
      // A runtime key makes the constructor run at runtime; a const-only
      // instance is built at compile time and coverage may miss it.
      child: OffTopicApp(key: UniqueKey()),
    ),
  );

  testWidgets('opens on the home screen with the app title', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('OffTopic'), findsOneWidget);
    expect(find.text('Voice core 0.1.0'), findsOneWidget);
  });

  testWidgets('uses the dark high-contrast theme only', (tester) async {
    await pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme?.brightness, Brightness.dark);
    expect(app.debugShowCheckedModeBanner, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('follows the device language', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Núcleo de voz 0.1.0'), findsOneWidget);
  });

  testWidgets('falls back to English for other languages', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Voice core 0.1.0'), findsOneWidget);
  });
}
