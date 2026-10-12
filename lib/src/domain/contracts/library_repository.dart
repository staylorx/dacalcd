import 'package:fpdart/fpdart.dart';

import '../entities/device.dart';
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
}
