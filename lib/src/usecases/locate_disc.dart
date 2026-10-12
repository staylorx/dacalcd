import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Locate the slot currently holding a given disc.
///
/// Returns null when the disc is not placed in any slot (e.g. it is on a desk,
/// being imported, or not yet catalogued).
class LocateDisc {
  /// Creates a [LocateDisc] use case.
  const LocateDisc(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, Slot?> call({required String discId}) =>
      _repository.locateDisc(discId: discId);
}
