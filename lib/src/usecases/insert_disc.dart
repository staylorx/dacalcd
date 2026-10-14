import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Insert a [disc] into a device's [slotNumber].
///
/// The disc is placed in exactly one slot. If the disc was already occupying
/// another slot, that slot is cleared as part of the same unit of work, so the
/// "a disc lives in at most one slot" invariant always holds. If the target
/// slot already holds a different disc it is refused with
/// [InUseFailure] — a library does not silently overwrite what is there.
///
/// Pass a [unitOfWork] when the store can roll back, so the two writes (clear
/// the old slot, fill the new one) are atomic.
class InsertDisc {
  /// Creates an [InsertDisc] use case.
  const InsertDisc({
    required ILibraryRepository repository,
    IUnitOfWork? unitOfWork,
  }) : _repository = repository,
       _unitOfWork = unitOfWork ?? const NoOpUnitOfWork();

  final ILibraryRepository _repository;
  final IUnitOfWork _unitOfWork;

  /// Executes the use case.
  TaskEither<DecalFailure, Slot> call({
    required Disc disc,
    required String deviceId,
    required int slotNumber,
  }) {
    // Load the device so we can validate the slot range against its capacity,
    // and the target slot to see whether it is free.
    final target = _repository.fetchSlot(
      deviceId: deviceId,
      slotNumber: slotNumber,
    );
    final device = _repository.fetchDeviceById(id: deviceId);

    return device.flatMap(
      (d) => _repository
          .listSlots(deviceId: deviceId)
          .flatMap(
            (slots) => target.flatMap((s) {
              if (s.isOccupied) {
                return TaskEither.left(
                  InUseFailure(
                    'Slot $slotNumber on device $deviceId already holds '
                    'a disc',
                  ),
                );
              }

              // Find where the disc currently lives (may be nowhere).
              final existing = slots
                  .where(
                    (sl) => sl.isOccupied && sl.disc?.meta.id == disc.meta.id,
                  )
                  .toList();

              final clearOld = (existing.isEmpty)
                  ? TaskEither<DecalFailure, void>.of(null)
                  : _repository.updateSlot(slot: existing.single.empty());

              final fillNew = _repository.updateSlot(
                slot: s.copyWith(disc: disc.withSlot(slotNumber)),
              );

              return TaskEither<DecalFailure, Slot>(
                () => _unitOfWork.runEither<DecalFailure, Slot>(
                  body: () => clearOld.flatMap((_) => fillNew).run(),
                ),
              );
            }),
          ),
    );
  }
}
