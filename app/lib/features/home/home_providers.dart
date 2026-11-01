import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/home/data/repositories/app_info_repository_impl.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/domain/repositories/app_info_repository.dart';
import 'package:offtopic/features/home/domain/usecases/get_app_info.dart';
import 'package:offtopic/features/home/presentation/controllers/home_controller.dart';

final appInfoRepositoryProvider = Provider<AppInfoRepository>(
  (ref) => AppInfoRepositoryImpl(
    voiceCore: ref.watch(voiceCoreClientProvider),
    platformInfo: ref.watch(voicePlatformGatewayProvider),
  ),
);

final getAppInfoProvider = Provider<GetAppInfo>(
  (ref) => GetAppInfo(ref.watch(appInfoRepositoryProvider)),
);

final homeControllerProvider = AsyncNotifierProvider<HomeController, AppInfo>(
  HomeController.new,
  retry: noAutomaticRetry,
);
