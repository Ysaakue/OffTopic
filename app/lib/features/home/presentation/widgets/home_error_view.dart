import 'package:flutter/material.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Explains a failed load and offers a retry.
class HomeErrorView extends StatelessWidget {
  const new({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _message(l10n),
          key: const Key('home.error'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        FilledButton(
          key: const Key('home.retry'),
          onPressed: onRetry,
          child: Text(l10n.retryButton),
        ),
      ],
    );
  }

  String _message(AppLocalizations l10n) => switch (error) {
    PlatformFailure() => l10n.homePlatformError,
    _ => l10n.homeCoreError,
  };
}
