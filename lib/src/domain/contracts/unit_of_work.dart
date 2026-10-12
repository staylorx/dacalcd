import 'package:fpdart/fpdart.dart';

/// Transaction seam — transactional adapters implement it over their store.
///
/// The unit of work is the only place a multi-write operation (insert disc,
/// remove disc) can be made atomic. A store that cannot roll back implements
/// it as [NoOpUnitOfWork] and callers pass nothing.
///
/// **Rollback is a value, not an exception.** A `Left` returned by [runEither]
/// means "undo the writes"; the adapter — the only code that owns a
/// transaction — does the undoing. Nothing in the domain ever throws.
abstract interface class IUnitOfWork {
  /// Runs [body] inside the store's transaction.
  ///
  /// A `Left` result rolls the transaction back — its writes are undone — and
  /// the failure is handed straight back. A `Right` commits.
  Future<Either<F, T>> runEither<F, T>({
    required Future<Either<F, T>> Function() body,
  });
}
