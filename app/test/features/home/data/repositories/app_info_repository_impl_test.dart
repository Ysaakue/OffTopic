import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/data/repositories/app_info_repository_impl.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  late FakeVoiceCoreClient voiceCore;
  late FakeVoicePlatformGateway platform;
  late AppInfoRepositoryImpl repository;

  setUp(() {
    voiceCore = FakeVoiceCoreClient(version: '0.1.0');
    platform = FakeVoicePlatformGateway(platformInfo: samplePlatformInfo);
    repository = AppInfoRepositoryImpl(
      voiceCore: voiceCore,
      platformInfo: platform,
    );
  });

  tearDown(() => platform.dispose());

  test('combines the core version with the platform description', () async {
    expect(await repository.getAppInfo(), const Success(sampleAppInfo));
  });

  test('maps a core exception to CoreFailure', () async {
    voiceCore.versionError = const VoiceCoreException('not loaded');

    expect(
      await repository.getAppInfo(),
      const Failure<AppInfo>(CoreFailure('not loaded')),
    );
  });

  test('does not ask the platform when the core already failed', () async {
    voiceCore.versionError = const VoiceCoreException('not loaded');

    await repository.getAppInfo();

    expect(platform.calls, isEmpty);
  });

  test('maps a platform exception to PlatformFailure', () async {
    platform.failWith(
      PlatformCall.getPlatformInfo,
      const VoicePlatformException(code: 'channel-error', message: 'no host'),
    );

    expect(
      await repository.getAppInfo(),
      const Failure<AppInfo>(
        PlatformFailure(code: 'channel-error', message: 'no host'),
      ),
    );
  });
}
