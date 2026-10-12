import 'package:fpdart/fpdart.dart';

import 'unit_of_work.dart';

/// A unit of work that runs immediately, with no rollback.
///
/// For stores that cannot undo a write: every operation commits as it happens,
/// so a `Left` simply passes through.
class NoOpUnitOfWork implements IUnitOfWork {
  /// Creates a no-op unit of work.
  const NoOpUnitOfWork();

  @override
  Future<Either<F, T>> runEither<F, T>({
    required Future<Either<F, T>> Function() body,
  }) => body();
}
