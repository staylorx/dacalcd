import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// List the library's disc catalog.
///
/// Returns every [Disc] the library owns, independent of carousel placement.
/// The catalog is ordered by sku id then label so a list view renders stably.
class ListDiscs {
  /// Creates a [ListDiscs] use case.
  const ListDiscs(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, List<Disc>> call() => _repository.listDiscs();
}
