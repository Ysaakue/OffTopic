import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/home_providers.dart';

/// Loads the [AppInfo] for the home screen. Failures surface as an
/// [AsyncError] carrying the AppFailure.
final class HomeController extends AsyncNotifier<AppInfo> {
  @override
  Future<AppInfo> build() async {
    final result = await ref.watch(getAppInfoProvider).call();
    return switch (result) {
      Success(:final value) => value,
      Failure(:final failure) => throw failure,
    };
  }

  /// Loads everything again, e.g. after a failure.
  void retry() => ref.invalidateSelf();
}
