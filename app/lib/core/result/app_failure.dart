import 'package:equatable/equatable.dart';

/// A failure the domain and presentation layers understand.
///
/// The data layer converts every infrastructure exception into one of these,
/// so no package exception ever reaches a widget.
sealed class AppFailure extends Equatable implements Exception {
  const new(this.message);

  /// Technical detail for logs; never shown to the rider as is.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// The native voice core failed or is unavailable.
final class CoreFailure extends AppFailure {
  const new(super.message);
}

/// The platform layer (Kotlin / Swift) failed.
final class PlatformFailure extends AppFailure {
  const new({required this.code, String? message}) : super(message ?? code);

  /// Machine readable code reported by the platform.
  final String code;

  @override
  List<Object?> get props => [code, message];
}
