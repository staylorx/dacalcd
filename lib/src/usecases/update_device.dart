import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';
import 'list_devices.dart';

/// Update a CD library machine's identity fields.
///
/// Updates [manufacturer], [sku], [model], [serialNumber], [capacity] and
/// [name] on the machine identified by [deviceId]. Fields passed as `null`
/// are left unchanged; the machine's per-unit [SerialConfig] is preserved.
///
/// [NotFoundFailure] when no machine has [deviceId]. A blank serial is
/// refused with [InvalidInputFailure]; a serial already used by a *different*
/// machine with [AlreadyExistsFailure]; a non-positive [capacity] with
/// [InvalidInputFailure]. The machine's `updatedAt` is refreshed for every
/// change (inject [clock] to make it deterministic).
class UpdateDevice {
  /// Creates an [UpdateDevice] use case.
  const UpdateDevice({
    required ILibraryRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? _systemNow;

  final ILibraryRepository _repository;
  final DateTime Function() _clock;

  static DateTime _systemNow() => DateTime.now();

  /// Executes the use case, returning the updated [Device].
  TaskEither<DecalFailure, Device> call({
    required String deviceId,
    String? manufacturer,
    String? sku,
    String? model,
    String? serialNumber,
    int? capacity,
    String? name,
  }) {
    final currentTask = _repository.fetchDeviceById(id: deviceId);
    final allTask = ListDevices(_repository).call();
    return currentTask.flatMap((current) {
      final newSerial = serialNumber ?? current.serialNumber;
      if (newSerial.trim().isEmpty) {
        return TaskEither.left(
          InvalidInputFailure('A machine must have a non-empty serial number'),
        );
      }
      final newCapacity = capacity ?? current.capacity;
      if (newCapacity < 1) {
        return TaskEither.left(
          InvalidInputFailure('A machine must have a positive capacity'),
        );
      }
      return allTask.flatMap((devices) {
        final clash = devices.any(
          (d) => d.meta.id != deviceId && d.serialNumber == newSerial,
        );
        if (clash) {
          return TaskEither.left(
            AlreadyExistsFailure(
              'Another machine already uses serial "$newSerial"',
            ),
          );
        }
        final updated = Device(
          meta: Meta(
            id: current.meta.id,
            notes: current.meta.notes,
            createdAt: current.meta.createdAt,
            updatedAt: _clock().toUtc().toIso8601String(),
          ),
          manufacturer: manufacturer ?? current.manufacturer,
          sku: sku ?? current.sku,
          model: model ?? current.model,
          serialNumber: newSerial,
          capacity: newCapacity,
          name: name ?? current.name,
          demoMode: current.demoMode,
          serialConfig: current.serialConfig,
        );
        return _repository.saveDevice(device: updated);
      });
    });
  }
}
