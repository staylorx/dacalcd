import 'package:sku_catalog/sku_catalog.dart' as cat;

/// Base of this layer's failure hierarchy — every way the library can fail.
///
/// It descends from the catalog's **shared root** ([cat.DomainFailure]) — the
/// shape sku_catalog 4.0.0 opened the root for. A product keeps its own failure
/// family and its failures travel the same channel as the catalog's, instead of
/// being translated into the catalog's vocabulary at every call. The catalog's
/// own closed set is `CatalogFailure`; ours is this one: `sealed`, so the leaves
/// stay exhaustively switchable, and the two families are **siblings** under the
/// root rather than members of one another.
///
/// [message] and the equality [props] come from the root; a leaf adds only what
/// it needs. Never thrown from the domain.
sealed class DecalFailure extends cat.DomainFailure {
  /// Creates a [DecalFailure].
  const DecalFailure(super.message);
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
