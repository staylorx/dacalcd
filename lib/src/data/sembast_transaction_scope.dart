import 'package:sembast/sembast.dart';

/// The seam that lets a [SembastUnitOfWork] hand its active transaction to a
/// [SembastLibraryRepository] so repository writes join the same atomic
/// transaction instead of committing on their own.
///
/// A transaction is a value ([Transaction] implements [DatabaseClient]), not
/// ambient state — this scope is the only place the "current transaction" is
/// held. The unit of work [attach]es when it opens a transaction and
/// [detach]es when it finishes; the repository asks the scope for the active
/// [DatabaseClient] on every operation and falls back to the plain
/// [Database] when there is none.
class SembastTransactionScope {
  /// Creates an empty scope with no active transaction.
  SembastTransactionScope();

  Transaction? _active;

  /// The currently active transaction, or null outside a unit of work.
  Transaction? get active => _active;

  /// Records [transaction] as the active one. Callers must pair every call
  /// with [detach].
  void attach(Transaction transaction) {
    assert(
      _active == null,
      'attach() called while a transaction is already active',
    );
    _active = transaction;
  }

  /// Clears the active transaction.
  void detach() {
    _active = null;
  }
}
