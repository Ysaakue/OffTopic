import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/home/home_providers.dart';
import 'package:offtopic/features/home/presentation/widgets/app_info_panel.dart';
import 'package:offtopic/features/home/presentation/widgets/home_error_view.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Start screen. In phase 0 it proves the Dart <-> C++ and Dart <-> Kotlin
/// paths by showing the core version and the phone summary.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appInfo = ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.homeTagline,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                switch (appInfo) {
                  AsyncData(:final value) => AppInfoPanel(info: value),
                  AsyncError(:final error) => HomeErrorView(
                    error: error,
                    onRetry: ref.read(homeControllerProvider.notifier).retry,
                  ),
                  _ => _Loading(label: l10n.homeLoading),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home.loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(label),
      ],
    );
  }
}
