import 'package:fpdart/fpdart.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';
import 'list_devices.dart';

/// Update a CD library machine's identity fields.
///
/// Under the catalog-backed model, the machine's identity ([manufacturer],
/// [sku]/model number, [model], [capacity]) lives on its machine [cat.Sku],
/// while [serialNumber] and [name] live on the machine [cat.Instance] (the
/// [Device]). This use case rebuilds both and refreshes the instance's
/// `updatedAt`. Fields passed as `null` are left unchanged; the machine's
/// per-unit [SerialConfig] is preserved.
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
      final newSerial = serialNumber ?? current.serialNumber ?? '';
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
        final baseSku = current.machineSku ??
            dacalMachineSku(
              meta: cat.Meta(
                id: 'dc:sku:machine:${current.meta.id}',
                notes: '',
                createdAt: '',
                updatedAt: '',
              ),
              modelNumber: current.sku,
              capacity: current.capacity,
            );
        final newSku = baseSku.copyWith(
          modelNumber: sku ?? baseSku.modelNumber,
          attributeValues: {
            ...baseSku.attributeValues,
            'capacity': newCapacity,
            'model': model ?? current.model,
            'manufacturer': manufacturer ?? current.manufacturer,
          },
        );
        final updated = current.rebuild(
          meta: cat.Meta(
            id: current.meta.id,
            notes: current.meta.notes,
            createdAt: current.meta.createdAt,
            updatedAt: _clock().toUtc().toIso8601String(),
          ),
          serialNumber: newSerial,
          name: name,
          machineSku: newSku,
        );
        return _repository.saveDevice(device: updated);
      });
    });
  }
}
