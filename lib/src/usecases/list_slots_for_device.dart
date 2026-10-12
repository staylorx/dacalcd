import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// List the slots of a device, in slot-number order.
class ListSlotsForDevice {
  /// Creates a [ListSlotsForDevice] use case.
  const ListSlotsForDevice(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  ///
  /// Returns [NotFoundFailure] when the device does not exist.
  TaskEither<DecalFailure, List<Slot>> call({required String deviceId}) =>
      _repository.listSlots(deviceId: deviceId);
}
