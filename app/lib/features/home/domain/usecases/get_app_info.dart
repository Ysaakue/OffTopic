import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/domain/repositories/app_info_repository.dart';

/// Reads the core version and the phone description.
final class GetAppInfo {
  const new(this._repository);

  final AppInfoRepository _repository;

  Future<Result<AppInfo>> call() => _repository.getAppInfo();
}
