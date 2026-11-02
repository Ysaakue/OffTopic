import 'package:flutter/material.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/value_objects/display_name.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

enum _Role { host, join }

/// Role, host address or echo mode, and the big start/stop button.
class AudioTestForm extends StatefulWidget {
  const new({
    required this.enabled,
    required this.running,
    required this.onStart,
    required this.onStop,
    super.key,
  });

  /// Whether the fields and the start button accept input.
  final bool enabled;

  /// Whether the button stops a running test.
  final bool running;

  final ValueChanged<RoomRequest> onStart;
  final VoidCallback onStop;

  @override
  State<AudioTestForm> createState() => _AudioTestFormState();
}

class _AudioTestFormState extends State<AudioTestForm> {
  final _hostIp = TextEditingController();
  _Role _role = _Role.join;
  bool _echoMode = false;
  bool _showHostError = false;

  @override
  void dispose() {
    _hostIp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Role>(
          key: const Key('audioTest.role'),
          segments: [
            ButtonSegment(
              value: _Role.join,
              label: Text(l10n.audioTestRoleJoin),
            ),
            ButtonSegment(
              value: _Role.host,
              label: Text(l10n.audioTestRoleHost),
            ),
          ],
          selected: {_role},
          onSelectionChanged: widget.enabled
              ? (selection) => setState(() => _role = selection.single)
              : null,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        if (_role == _Role.join)
          TextField(
            key: const Key('audioTest.hostIp'),
            controller: _hostIp,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.audioTestHostIpLabel,
              errorText: _showHostError ? l10n.audioTestInvalidHost : null,
            ),
            onChanged: (_) => setState(() => _showHostError = false),
          )
        else
          SwitchListTile(
            key: const Key('audioTest.echo'),
            title: Text(l10n.audioTestEchoMode),
            subtitle: Text(l10n.audioTestEchoModeHint),
            value: _echoMode,
            onChanged: widget.enabled
                ? (value) => setState(() => _echoMode = value)
                : null,
          ),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (widget.running)
          FilledButton(
            key: const Key('audioTest.stop'),
            onPressed: widget.onStop,
            child: Text(l10n.audioTestStop),
          )
        else
          FilledButton(
            key: const Key('audioTest.start'),
            onPressed: widget.enabled ? () => _start(l10n) : null,
            child: Text(l10n.audioTestStart),
          ),
      ],
    );
  }

  void _start(AppLocalizations l10n) {
    // The rider name screen arrives in phase 3; until then a fixed name.
    final name = DisplayName.tryParse(l10n.audioTestDefaultName)!;
    switch (_role) {
      case _Role.host:
        widget.onStart(HostRoomRequest(name: name, echoMode: _echoMode));
      case _Role.join:
        final host = HostAddress.tryParse(_hostIp.text);
        if (host == null) {
          setState(() => _showHostError = true);
          return;
        }
        widget.onStart(JoinRoomRequest(name: name, host: host));
    }
  }
}
