import 'package:flutter/material.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Core version and phone summary.
class AppInfoPanel extends StatelessWidget {
  const new({required this.info, super.key});

  final AppInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.homeCoreVersion(info.coreVersion),
          key: const Key('home.coreVersion'),
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          l10n.homeDevice(
            info.manufacturer,
            info.model,
            _displayOsName(info.osName),
            info.osVersion,
          ),
          key: const Key('home.device'),
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static String _displayOsName(String osName) => switch (osName) {
    'android' => 'Android',
    'ios' => 'iOS',
    _ => osName,
  };
}
