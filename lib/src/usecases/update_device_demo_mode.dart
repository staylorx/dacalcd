import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Set or exit a CD library machine's per-machine demo mode.
///
/// Demo mode is a per-machine fallback: when auto-detection of a physical
/// machine fails, the machine enters demo mode so the UI still operates
/// against simulated hardware, and the machine's page shows a clear demo-mode
/// indicator (banner) that can be toggled off again by this use case.
///
/// The flag lives on the machine — [Device.demoMode] — not in a shared
/// app-wide setting. This use case updates just that field on the machine
/// identified by [deviceId], leaving its identity fields and per-machine
/// [SerialConfig] untouched. [NotFoundFailure] when no machine has
/// [deviceId]. The machine's `updatedAt` is refreshed for every change
/// (inject [clock] to make it deterministic).
class UpdateDeviceDemoMode {
  /// Creates an [UpdateDeviceDemoMode] use case.
  const UpdateDeviceDemoMode({
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
    required bool demoMode,
  }) => _repository.fetchDeviceById(id: deviceId).flatMap((current) {
    final updated = Device(
      meta: Meta(
        id: current.meta.id,
        notes: current.meta.notes,
        createdAt: current.meta.createdAt,
        updatedAt: _clock().toUtc().toIso8601String(),
      ),
      manufacturer: current.manufacturer,
      sku: current.sku,
      model: current.model,
      serialNumber: current.serialNumber,
      capacity: current.capacity,
      name: current.name,
      demoMode: demoMode,
      serialConfig: current.serialConfig,
    );
    return _repository.saveDevice(device: updated);
  });
}
