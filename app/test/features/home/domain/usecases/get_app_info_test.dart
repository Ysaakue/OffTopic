import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/domain/repositories/app_info_repository.dart';
import 'package:offtopic/features/home/domain/usecases/get_app_info.dart';

import '../../../../helpers/fixtures.dart';

class _MockAppInfoRepository extends Mock implements AppInfoRepository;

void main() {
  late _MockAppInfoRepository repository;
  late GetAppInfo getAppInfo;

  setUp(() {
    repository = _MockAppInfoRepository();
    getAppInfo = GetAppInfo(repository);
  });

  test('returns the repository success', () async {
    when(repository.getAppInfo)
        .thenAnswer((_) async => const Success(sampleAppInfo));

    expect(await getAppInfo(), const Success(sampleAppInfo));
    verify(repository.getAppInfo).called(1);
  });

  test('returns the repository failure unchanged', () async {
    const failure = Failure<AppInfo>(CoreFailure('down'));
    when(repository.getAppInfo).thenAnswer((_) async => failure);

    expect(await getAppInfo(), failure);
  });
}
