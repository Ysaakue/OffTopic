import 'package:flutter/material.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// The big push-to-talk area: the microphone is sent while a finger (or a
/// glove) is on it. Leaving the screen while it is held releases it.
class PushToTalkButton extends StatefulWidget {
  const new({required this.onChanged, super.key});

  /// Called with true when pressed and false when released.
  final ValueChanged<bool> onChanged;

  @override
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton> {
  // Fingers on the button: it stays pressed until the last one leaves.
  final Set<int> _pointers = {};

  bool get _pressed => _pointers.isNotEmpty;

  @override
  void dispose() {
    if (_pressed) {
      widget.onChanged(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = _pressed ? l10n.pushToTalkTalking : l10n.pushToTalkHold;
    return Semantics(
      button: true,
      label: label,
      child: Listener(
        key: const Key('talk.pushToTalk'),
        onPointerDown: (event) => _update(() => _pointers.add(event.pointer)),
        onPointerUp: (event) => _update(() => _pointers.remove(event.pointer)),
        onPointerCancel: (event) =>
            _update(() => _pointers.remove(event.pointer)),
        child: Container(
          height: AppDimensions.pushToTalkHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed ? colors.primary : colors.surface,
            border: Border.all(color: colors.primary, width: 2),
            borderRadius: BorderRadius.circular(AppDimensions.largeRadius),
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _pressed ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _update(void Function() change) {
    final before = _pressed;
    setState(change);
    if (_pressed != before) {
      widget.onChanged(_pressed);
    }
  }
}
