import 'package:fpdart/fpdart.dart';

import '../entities/device.dart';
import '../entities/disc.dart';
import '../entities/slot.dart';
import '../failures/decal_failures.dart';

/// Contract for library persistence.
///
/// Implement this over whatever you have (a map, sembast, sqlite3/drift, an
/// HTTP service). Every method returns an FP-style tuple; nothing throws.
abstract interface class ILibraryRepository {
  /// Fetch all known devices.
  TaskEither<DecalFailure, List<Device>> fetchDevices();

  /// Fetch a single device by its unique [serialCode].
  TaskEither<DecalFailure, Device> fetchDeviceBySerialCode({
    required String serialCode,
  });

  /// Fetch a device by its opaque id.
  TaskEither<DecalFailure, Device> fetchDeviceById({required String id});

  /// Save (create or update) a device.
  TaskEither<DecalFailure, Device> saveDevice({required Device device});

  /// List every slot of the device identified by [deviceId].
  TaskEither<DecalFailure, List<Slot>> listSlots({required String deviceId});

  /// Fetch one slot by device id and slot number.
  TaskEither<DecalFailure, Slot> fetchSlot({
    required String deviceId,
    required int slotNumber,
  });

  /// Persist a slot (e.g. after its disc changes).
  TaskEither<DecalFailure, Slot> updateSlot({required Slot slot});

  /// Locate the slot containing the disc identified by [discId].
  ///
  /// Returns null when the disc is not currently placed in any slot.
  TaskEither<DecalFailure, Slot?> locateDisc({required String discId});

  /// Save (create or update) a [Disc] in the library catalog.
  ///
  /// The catalog is the library's own collection of discs, independent of
  /// whether a disc is currently placed in a carousel slot. Saving a disc by
  /// a new id creates it; saving over an existing id updates it (upsert).
  TaskEither<DecalFailure, Disc> saveDisc({required Disc disc});

  /// Fetch one [Disc] from the library catalog by its id.
  ///
  /// Returns [NotFoundFailure] when no such disc is catalogued.
  TaskEither<DecalFailure, Disc> fetchDisc({required String discId});

  /// List every [Disc] in the library catalog, ordered by sku id then label.
  TaskEither<DecalFailure, List<Disc>> listDiscs();

  /// Remove a [Disc] from the library catalog by id.
  ///
  /// Callers are responsible for the invariant that the disc is not currently
  /// placed in a carousel slot (see [RemoveDiscFromLibrary]); the adapter just
  /// deletes the catalog record. Returns [NotFoundFailure] when missing.
  TaskEither<DecalFailure, void> deleteDisc({required String discId});
}
