import 'package:equatable/equatable.dart';

/// The name other riders see: 1 to 32 characters after trimming (the limit
/// of the HELLO message in docs/PROTOCOL.md).
final class DisplayName extends Equatable {
  const new _(this.value);

  /// The name, or null when [input] is empty or too long.
  static DisplayName? tryParse(String input) {
    final text = input.trim();
    final characters = text.runes.length;
    if (characters == 0 || characters > maxCharacters) {
      return null;
    }
    return DisplayName._(text);
  }

  /// Longest accepted name, in characters (Unicode code points).
  static const maxCharacters = 32;

  /// The trimmed name.
  final String value;

  @override
  List<Object?> get props => [value];
}
