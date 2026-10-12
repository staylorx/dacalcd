import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Fetch one catalogued [Disc] by id.
///
/// Returns [NotFoundFailure] when the disc is not in the library catalog.
class GetDisc {
  /// Creates a [GetDisc] use case.
  const GetDisc(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, Disc> call({required String discId}) =>
      _repository.fetchDisc(discId: discId);
}
