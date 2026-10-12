import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Remove the disc from a device's slot, leaving it empty.
///
/// Returns [NotFoundFailure] when the device or slot does not exist, and
/// [InvalidInputFailure] when the slot is already empty (there is nothing to
/// remove).
class RemoveDisc {
  /// Creates a [RemoveDisc] use case.
  const RemoveDisc(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, Slot> call({
    required String deviceId,
    required int slotNumber,
  }) => _repository
      .fetchSlot(deviceId: deviceId, slotNumber: slotNumber)
      .flatMap((slot) {
        if (slot.isEmpty) {
          return TaskEither.left(
            InvalidInputFailure(
              'Slot $slotNumber on device $deviceId is already empty',
            ),
          );
        }
        return _repository.updateSlot(slot: slot.empty());
      });
}
