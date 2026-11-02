import 'package:flutter/material.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Shown when the room cannot start because a permission was refused.
class PermissionDeniedView extends StatelessWidget {
  const new({
    required this.permanently,
    required this.onOpenSettings,
    required this.onDismiss,
    super.key,
  });

  /// Only the app settings can grant the permission now.
  final bool permanently;

  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('permissionDenied'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.permissionDeniedTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(l10n.permissionDeniedBody),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (permanently)
          FilledButton(
            key: const Key('permissionDenied.settings'),
            onPressed: onOpenSettings,
            child: Text(l10n.permissionOpenSettings),
          ),
        const SizedBox(height: AppDimensions.spacingMedium),
        OutlinedButton(
          key: const Key('permissionDenied.retry'),
          onPressed: onDismiss,
          child: Text(l10n.retryButton),
        ),
      ],
    );
  }
}
