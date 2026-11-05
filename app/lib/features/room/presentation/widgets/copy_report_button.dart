import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/presentation/formatters/session_report_formatter.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Copies the room's report to the clipboard, for the rider to paste in a
/// chat with the developers. Hidden before the first room.
class CopyReportButton extends ConsumerWidget {
  const new({super.key});

  static const _formatter = SessionReportFormatter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(sessionReportControllerProvider);
    if (report == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const Key('audioTest.copyReport'),
      icon: const Icon(Icons.copy),
      label: Text(l10n.reportCopy),
      onPressed: () {
        final text = _formatter.format(report, ref.read(clockProvider)());
        unawaited(Clipboard.setData(ClipboardData(text: text)));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.reportCopied)));
      },
    );
  }
}
