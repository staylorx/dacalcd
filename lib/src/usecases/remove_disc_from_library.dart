import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Remove a [Disc] from the library catalog.
///
/// Refuses with [InUseFailure] when the disc is currently placed in a carousel
/// slot — you must remove it from the machine ([RemoveDisc]) first, so the
/// catalog and the machine never disagree about a disc's whereabouts. Returns
/// [NotFoundFailure] when the disc is not catalogued.
class RemoveDiscFromLibrary {
  /// Creates a [RemoveDiscFromLibrary] use case.
  const RemoveDiscFromLibrary(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case, returning the removed [Disc].
  TaskEither<DecalFailure, Disc> call({required String discId}) =>
      _repository.fetchDisc(discId: discId).flatMap((disc) {
        final placed = _repository.locateDisc(discId: discId);
        return placed.flatMap((slot) {
          if (slot != null) {
            return TaskEither.left(
              InUseFailure(
                'Disc "$discId" is in slot ${slot.slotNumber} on device '
                '"${slot.deviceId}"; remove it from the machine first',
              ),
            );
          }
          return _repository.deleteDisc(discId: discId).map((_) => disc);
        });
      });
}
