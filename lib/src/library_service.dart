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

  /// Fetches one machine by its opaque id. [NotFoundFailure] when absent.
  TaskEither<DecalFailure, Device> getDeviceById(String id) =>
      GetDeviceById(repository).call(id: id);

  /// Fetches one machine by its serial number. [NotFoundFailure] when absent.
  TaskEither<DecalFailure, Device> getDeviceBySerialCode(String serialCode) =>
      GetDeviceBySerialCode(repository).call(serialCode: serialCode);

  /// Registers a new machine, minting its id.
  ///
  /// [InvalidInputFailure] on a blank serial / non-positive capacity;
  /// [AlreadyExistsFailure] when another machine already has [serialNumber].
  TaskEither<DecalFailure, Device> addDevice({
    required String manufacturer,
    required String sku,
    required String model,
    required String serialNumber,
    required int capacity,
    String? name,
    SerialConfig? serialConfig,
  }) => AddDevice(repository: repository).call(
    manufacturer: manufacturer,
    sku: sku,
    model: model,
    serialNumber: serialNumber,
    capacity: capacity,
    name: name,
    serialConfig: serialConfig,
  );

  /// Updates a machine's identity fields by [deviceId].
  ///
  /// `null` fields are left unchanged; [NotFoundFailure] when the machine is
  /// absent, [AlreadyExistsFailure] when the new serial collides with a
  /// different machine.
  TaskEither<DecalFailure, Device> updateDevice({
    required String deviceId,
    String? manufacturer,
    String? sku,
    String? model,
    String? serialNumber,
    int? capacity,
    String? name,
  }) => UpdateDevice(repository: repository).call(
    deviceId: deviceId,
    manufacturer: manufacturer,
    sku: sku,
    model: model,
    serialNumber: serialNumber,
    capacity: capacity,
    name: name,
  );

  /// Deletes a machine and its slots by [deviceId].
  ///
  /// [NotFoundFailure] when the machine is absent.
  TaskEither<DecalFailure, void> deleteDevice(String deviceId) =>
      DeleteDevice(repository).call(deviceId: deviceId);

  /// Lists a device's slots, in slot-number order.
  TaskEither<DecalFailure, List<Slot>> listSlots(String deviceId) =>
      ListSlotsForDevice(repository).call(deviceId: deviceId);

  /// Lists a device's slots, in slot-number order.
  TaskEither<DecalFailure, List<Slot>> listSlotsForDevice(String deviceId) =>
      ListSlotsForDevice(repository).call(deviceId: deviceId);

  /// Lists the library's disc catalog, ordered by sku id then label.
  ///
  /// This is the read side of the library's own collection of discs, distinct
  /// from the carousel placements (see [listSlotsForDevice]). A catalogue disc
  /// may or may not be currently placed in a machine slot.
  TaskEither<DecalFailure, List<Disc>> listDiscs() =>
      ListDiscs(repository).call();

  /// Fetches one catalogued disc by id. [NotFoundFailure] when absent.
  TaskEither<DecalFailure, Disc> getDisc(String discId) =>
      GetDisc(repository).call(discId: discId);

  /// Adds a new disc to the library catalog.
  ///
  /// [AlreadyExistsFailure] when a disc for [skuId] is already catalogued.
  TaskEither<DecalFailure, Disc> addDisc({
    required String skuId,
    String? label,
    String? serialNumber,
  }) => AddDiscToLibrary(repository: repository).call(
    skuId: skuId,
    label: label,
    serialNumber: serialNumber,
  );

  /// Removes a catalogued disc from the library.
  ///
  /// [InUseFailure] when the disc is currently placed in a carousel slot.
  TaskEither<DecalFailure, Disc> removeDiscFromLibrary(String discId) =>
      RemoveDiscFromLibrary(repository).call(discId: discId);

  /// Changes a catalogued disc's attributes.
  ///
  /// `null` fields are left unchanged; [AlreadyExistsFailure] when the new sku
  /// id would collide with a different disc.
  TaskEither<DecalFailure, Disc> changeDisc({
    required String discId,
    String? skuId,
    String? label,
    String? serialNumber,
  }) => ChangeDiscInLibrary(repository: repository).call(
    discId: discId,
    skuId: skuId,
    label: label,
    serialNumber: serialNumber,
  );

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
