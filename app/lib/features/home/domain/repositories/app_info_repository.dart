import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';

/// Source of the [AppInfo] shown on the home screen.
abstract interface class AppInfoRepository {
  Future<Result<AppInfo>> getAppInfo();
}
