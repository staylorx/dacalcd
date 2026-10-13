import 'package:fpdart/fpdart.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';

/// Set or clear a CD library machine's per-machine serial connection config.
///
/// Serial port/comm settings belong to a single machine (each CD library
/// machine talks on its own COM port), so they are stored on the machine —
/// [Device.serialConfig] — not in a shared app-wide config. This use case
/// updates just that field on the machine identified by [deviceId], leaving
/// its identity (machine SKU + instance) untouched.
///
/// Pass a [SerialConfig] to set the machine's connection, or `null` to clear
/// it. [NotFoundFailure] when no machine has [deviceId]. The machine's
/// `updatedAt` is refreshed for every change (inject [clock] to make it
/// deterministic).
class UpdateDeviceSerialConfig {
  /// Creates an [UpdateDeviceSerialConfig] use case.
  const UpdateDeviceSerialConfig({
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
    required SerialConfig? serialConfig,
  }) => _repository.fetchDeviceById(id: deviceId).flatMap((current) {
    final updated = current.rebuild(
      meta: cat.Meta(
        id: current.meta.id,
        notes: current.meta.notes,
        createdAt: current.meta.createdAt,
        updatedAt: _clock().toUtc().toIso8601String(),
      ),
      serialConfig: serialConfig,
    );
    return _repository.saveDevice(device: updated);
  });
}
