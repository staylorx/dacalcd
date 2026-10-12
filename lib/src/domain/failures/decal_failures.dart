import 'package:equatable/equatable.dart';

/// Base of this layer's failure hierarchy — every way the library can fail.
///
/// `sealed`, so the leaves are exhaustively switchable: a consumer can list
/// every failure this package can return and let the analyzer prove the list
/// complete. Never thrown from the domain.
sealed class DecalFailure extends Equatable {
  /// Message describing what went wrong.
  final String message;

  /// Creates a [DecalFailure].
  const DecalFailure(this.message);

  @override
  List<Object> get props => [message];
}

/// A requested entity was not found.
final class NotFoundFailure extends DecalFailure {
  /// Creates a [NotFoundFailure].
  const NotFoundFailure(super.message);
}

/// An entity that would create a duplicate already exists.
final class AlreadyExistsFailure extends DecalFailure {
  /// Creates an [AlreadyExistsFailure].
  const AlreadyExistsFailure(super.message);
}

/// An operation would leave the model in an invalid state.
final class InvalidInputFailure extends DecalFailure {
  /// Creates an [InvalidInputFailure].
  const InvalidInputFailure(super.message);
}

/// An operation failed because the entity is still in use.
final class InUseFailure extends DecalFailure {
  /// Creates an [InUseFailure].
  const InUseFailure(super.message);
}

/// An unexpected persistence / storage error surfaced by a repository adapter.
///
/// Storage adapters never throw and never swallow: a third-party storage
/// fault (sembast, file I/O) is converted at the adapter boundary into this
/// value so callers can switch on it like any other [DecalFailure].
final class StorageFailure extends DecalFailure {
  /// Creates a [StorageFailure].
  const StorageFailure(super.message);
}
