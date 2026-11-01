import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/domain/repositories/app_info_repository.dart';
import 'package:offtopic/features/home/home_providers.dart';

import '../../../../helpers/fixtures.dart';

class _MockAppInfoRepository extends Mock implements AppInfoRepository;

void main() {
  late _MockAppInfoRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockAppInfoRepository();
    container = ProviderContainer.test(
      overrides: [appInfoRepositoryProvider.overrideWithValue(repository)],
    );
  });

  test('starts loading, then exposes the app info', () async {
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Success(sampleAppInfo));

    expect(
      container.read(homeControllerProvider),
      isA<AsyncLoading<AppInfo>>(),
    );
    expect(await container.read(homeControllerProvider.future), sampleAppInfo);
  });

  test('exposes a failure as an error carrying the AppFailure', () async {
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Failure(CoreFailure('down')));

    await expectLater(
      container.read(homeControllerProvider.future),
      throwsA(const CoreFailure('down')),
    );
    expect(
      container.read(homeControllerProvider).error,
      const CoreFailure('down'),
    );
  });

  test('does not retry automatically after a failure', () async {
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Failure(CoreFailure('down')));

    await expectLater(
      container.read(homeControllerProvider.future),
      throwsA(isA<CoreFailure>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    verify(repository.getAppInfo).called(1);
  });

  test('retry loads again and recovers', () async {
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Failure(CoreFailure('down')));
    await expectLater(
      container.read(homeControllerProvider.future),
      throwsA(isA<CoreFailure>()),
    );
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Success(sampleAppInfo));

    container.read(homeControllerProvider.notifier).retry();

    expect(await container.read(homeControllerProvider.future), sampleAppInfo);
    verify(repository.getAppInfo).called(2);
  });
}
