import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/domain/repositories/app_info_repository.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/voice_platform.dart';

/// [AppInfoRepository] reading the voice core and the platform.
final class AppInfoRepositoryImpl implements AppInfoRepository {
  const new({required this._voiceCore, required this._platformInfo});

  final VoiceCoreClient _voiceCore;
  final PlatformInfoSource _platformInfo;

  @override
  Future<Result<AppInfo>> getAppInfo() async {
    try {
      final coreVersion = _voiceCore.version;
      final platform = await _platformInfo.getPlatformInfo();
      return Success(
        AppInfo(
          coreVersion: coreVersion,
          manufacturer: platform.manufacturer,
          model: platform.model,
          osName: platform.osName,
          osVersion: platform.osVersion,
        ),
      );
    } on VoiceCoreException catch (exception) {
      return Failure(CoreFailure(exception.message));
    } on VoicePlatformException catch (exception) {
      return Failure(
        PlatformFailure(code: exception.code, message: exception.message),
      );
    }
  }
}
