import 'package:equatable/equatable.dart';
import 'package:offtopic/core/result/app_failure.dart';

/// Outcome of an operation that can fail, returned across layers instead of
/// throwing.
sealed class Result<T> extends Equatable {
  const new();
}

/// The operation succeeded with [value].
final class Success<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

/// The operation failed with [failure].
final class Failure<T> extends Result<T> {
  const new(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
