import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';

import '../domain/domain.dart';
import 'sembast_transaction_scope.dart';

/// Carries a `Left` result out of a rolled-back sembast transaction.
///
/// Thrown inside the transaction when the body returns `Left`; sembast treats
/// the throw as an error, rolls the transaction back and rethrows, and
/// [SembastUnitOfWork.runEither] catches it here and hands the original
/// `Left` (the rollback reason) back to the caller as a value.
class _SembastRollback implements Exception {
  const _SembastRollback(this.failure);
  final DecalFailure failure;
}

/// A [IUnitOfWork] over a real sembast transaction.
///
/// [runEither] opens a transactional scope on the database, exposes it to a
/// shared [SembastTransactionScope] so the repository's writes join the same
/// transaction, and runs [body]. A `Left` from the body throws
/// [_SembastRollback] — which sembast's transaction treats as an error and
/// rolls back (its writes are undone) — then is caught here and handed back
/// as the same `Left`. A `Right` commits.
///
/// Reports its own storage faults as [StorageFailure]; the rolling back /
/// committing is delegated to sembast.
class SembastUnitOfWork implements IUnitOfWork {
  /// Creates a unit of work over [database], sharing [scope] with its
  /// repository.
  SembastUnitOfWork({
    required Database database,
    required SembastTransactionScope scope,
  }) : _database = database,
       _scope = scope;

  final Database _database;
  final SembastTransactionScope _scope;

  @override
  Future<Either<F, T>> runEither<F, T>({
    required Future<Either<F, T>> Function() body,
  }) async {
    try {
      return await _database.transaction((txn) async {
        _scope.attach(txn);
        try {
          final result = await body();
          if (result.isLeft()) {
            final failure = result.fold(
              (l) => l,
              (_) => throw StateError('Unreachable: Right with isLeft()'),
            );
            throw _SembastRollback(failure as DecalFailure);
          }
          return result;
        } finally {
          _scope.detach();
        }
      });
    } on _SembastRollback catch (rollback) {
      // The transaction rolled back because the body returned Left; hand the
      // original failure back to the caller.
      return Left<F, T>(rollback.failure as F);
    } catch (error) {
      return Left(StorageFailure('Storage transaction failed: $error') as F);
    }
  }
}
