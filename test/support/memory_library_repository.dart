import 'package:decalcd/decalcd.dart';
import 'package:fpdart/fpdart.dart';

/// In-memory [ILibraryRepository] — test double backed by maps.
///
/// TEST-ONLY. Deliberately not part of the published package; consumers build
/// their own backend against the contract.
class MemoryLibraryRepository implements ILibraryRepository, MemoryBacked {
  /// Creates an empty [MemoryLibraryRepository].
  MemoryLibraryRepository();

  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, Map<String, dynamic>> _slots = {};

  @override
  Map<String, Map<String, dynamic>> get rows => {..._devices, ..._slots};

  @override
  void replaceAll(Map<String, Map<String, dynamic>> rows) {
    _devices.clear();
    _slots.clear();
    for (final entry in rows.entries) {
      if (entry.value.containsKey('serial_code')) {
        _devices[entry.key] = entry.value;
      } else {
        _slots[entry.key] = entry.value;
      }
    }
  }

  @override
  TaskEither<DecalFailure, List<Device>> fetchDevices() =>
      TaskEither.of(_devices.values.map(Device.fromJson).toList());

  @override
  TaskEither<DecalFailure, Device> fetchDeviceBySerialCode({
    required String serialCode,
  }) {
    for (final d in _devices.values) {
      if (Device.fromJson(d).serialCode == serialCode) {
        return TaskEither.of(Device.fromJson(d));
      }
    }
    return TaskEither.left(
      NotFoundFailure('Device with serial code "$serialCode" not found'),
    );
  }

  @override
  TaskEither<DecalFailure, Device> fetchDeviceById({required String id}) {
    final record = _devices[id];
    if (record == null) {
      return TaskEither.left(NotFoundFailure('Device "$id" not found'));
    }
    return TaskEither.of(Device.fromJson(record));
  }

  @override
  TaskEither<DecalFailure, Device> saveDevice({required Device device}) {
    _devices[device.meta.id] = device.toJson();
    return TaskEither.of(device);
  }

  @override
  TaskEither<DecalFailure, List<Slot>> listSlots({required String deviceId}) {
    if (!_devices.containsKey(deviceId)) {
      return TaskEither.left(NotFoundFailure('Device "$deviceId" not found'));
    }
    final slots =
        _slots.values
            .map(Slot.fromJson)
            .where((s) => s.deviceId == deviceId)
            .toList()
          ..sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    return TaskEither.of(slots);
  }

  @override
  TaskEither<DecalFailure, Slot> fetchSlot({
    required String deviceId,
    required int slotNumber,
  }) {
    for (final s in _slots.values) {
      final slot = Slot.fromJson(s);
      if (slot.deviceId == deviceId && slot.slotNumber == slotNumber) {
        return TaskEither.of(slot);
      }
    }
    return TaskEither.left(
      NotFoundFailure('Slot $slotNumber on device "$deviceId" not found'),
    );
  }

  @override
  TaskEither<DecalFailure, Slot> updateSlot({required Slot slot}) {
    _slots[slot.meta.id] = slot.toJson();
    return TaskEither.of(slot);
  }

  @override
  TaskEither<DecalFailure, Slot?> locateDisc({required String discId}) {
    for (final s in _slots.values) {
      final slot = Slot.fromJson(s);
      if (slot.isOccupied && slot.disc?.meta.id == discId) {
        return TaskEither.of(slot);
      }
    }
    return TaskEither.of(null);
  }
}

/// Common surface for test doubles that back [MemoryLibraryRepository].
abstract interface class MemoryBacked {
  /// Raw rows, for tests that need to inspect or seed the store directly.
  Map<String, Map<String, dynamic>> get rows;

  /// Replaces all rows (used to restore a known state between tests).
  void replaceAll(Map<String, Map<String, dynamic>> rows);
}
