import 'package:fpdart/fpdart.dart';

import 'dacal_client.dart';
import 'domain/domain.dart';
import 'usecases/usecases.dart';

/// A combined read snapshot of the library: every known device plus the slots
/// of one device (the first), so a single call yields all the records a list
/// view needs without two round-trips.
typedef LibrarySnapshot = ({
  List<Device> devices,
  List<Slot>? firstDeviceSlots,
});

/// Shared read-side service used by both the CLI and the TUI (and available
/// to the Flutter app) to fetch the same Decal CD library data.
///
/// This is the single place the two entry points agree on **how** records are
/// retrieved: it wires the domain use cases ([ListDevices], [ListSlotsForDevice])
/// over the injected [ILibraryRepository] and exposes each result as a lazy
/// fpdart [TaskEither]. Neither the CLI nor the TUI constructs use cases or
/// talks to the repository directly for the read path — they both call this,
/// so a fix or feature in data retrieval lands in both consumers at once.
///
/// Consumers call `.call().run()` (or `.load().run()`) to execute, exactly as
/// they would a domain use case, and fold the resulting `Either` themselves.
class LibraryService {
  /// The library repository backing every read.
  final ILibraryRepository repository;

  /// The carousel client, surfaced for status/move commands. Optional so a
  /// headless or test run works without hardware.
  final DacalClient? carousel;

  /// Creates a [LibraryService].
  const LibraryService({required this.repository, this.carousel});

  /// Lists every known device.
  TaskEither<DecalFailure, List<Device>> listDevices() =>
      ListDevices(repository).call();

  /// Lists a device's slots, in slot-number order.
  TaskEither<DecalFailure, List<Slot>> listSlots(String deviceId) =>
      ListSlotsForDevice(repository).call(deviceId: deviceId);

  /// Lists a device's slots, in slot-number order.
  TaskEither<DecalFailure, List<Slot>> listSlotsForDevice(String deviceId) =>
      ListSlotsForDevice(repository).call(deviceId: deviceId);

  /// Loads the devices plus, when at least one exists, the slots of the first
  /// device.
  ///
  /// A [Left] is returned when listing either the devices or the first
  /// device's slots fails. The snapshot carries a null slot list when there
  /// are no devices.
  TaskEither<DecalFailure, LibrarySnapshot> load() {
    final devicesTask = ListDevices(repository).call();
    return devicesTask.flatMap((devices) {
      if (devices.isEmpty) {
        return TaskEither.right((
          devices: const <Device>[],
          firstDeviceSlots: null,
        ));
      }
      return ListSlotsForDevice(repository)
          .call(deviceId: devices.first.meta.id)
          .map((slots) => (devices: devices, firstDeviceSlots: slots));
    });
  }
}
