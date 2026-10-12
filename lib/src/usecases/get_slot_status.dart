import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Get the status (occupied / empty and, when occupied, its disc) of a slot.
class GetSlotStatus {
  /// Creates a [GetSlotStatus] use case.
  const GetSlotStatus(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  ///
  /// Returns [NotFoundFailure] when the device or slot does not exist.
  TaskEither<DecalFailure, Slot> call({
    required String deviceId,
    required int slotNumber,
  }) => _repository.fetchSlot(deviceId: deviceId, slotNumber: slotNumber);
}
