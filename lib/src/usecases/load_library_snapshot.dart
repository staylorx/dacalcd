import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';
import 'list_devices.dart';
import 'list_slots_for_device.dart';

/// A combined read snapshot of the library: every known device plus the slots
/// of one device (the first), so a single call yields all the records a list
/// view needs without two round-trips.
typedef LibrarySnapshot = ({
  List<Device> devices,
  List<Slot>? firstDeviceSlots,
});

/// Load the library snapshot a list view needs: every machine, plus the slots
/// of the first one.
///
/// A composition of [ListDevices] and [ListSlotsForDevice]. The outer rings
/// (GUI, TUI, CLI) act **only** through use cases, so the one combined read
/// they need is a use case in its own right — not a method bolted onto a
/// service sitting above this layer, which the rings could then act through
/// without passing a use case at all.
///
/// A [Left] is returned when listing either the devices or the first device's
/// slots fails. The snapshot carries a null slot list when there are no
/// devices.
class LoadLibrarySnapshot {
  /// Creates a [LoadLibrarySnapshot] use case.
  const LoadLibrarySnapshot(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case, returning the combined snapshot.
  TaskEither<DecalFailure, LibrarySnapshot> call() {
    final devicesTask = ListDevices(_repository).call();
    return devicesTask.flatMap((devices) {
      if (devices.isEmpty) {
        return TaskEither<DecalFailure, LibrarySnapshot>.right((
          devices: const <Device>[],
          firstDeviceSlots: null,
        ));
      }
      return ListSlotsForDevice(_repository)
          .call(deviceId: devices.first.meta.id)
          .map((slots) => (devices: devices, firstDeviceSlots: slots));
    });
  }
}
