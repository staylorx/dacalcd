import '../dacal_serial_transport.dart';
import '../domain/domain.dart';
import '../usecases/list_devices.dart';
import '../usecases/update_device_serial_config.dart';

/// Migrates a legacy app-wide selected COM port onto per-machine storage.
///
/// Before serial config became per machine, the app kept a single selected
/// COM port in one shared spot (e.g. a SharedPreferences key). This applies
/// that legacy [legacyPort] to the first machine that has no per-machine
/// serial config yet — the usual single-machine case — so a device that
/// previously talked on [legacyPort] keeps working after the change.
///
/// Returns the machine that received the migrated port, or `null` when there
/// is nothing to migrate (a blank port, no machines, or every machine already
/// has its own config). The caller is responsible for forgetting the legacy
/// value once migration succeeds so it is not re-applied.
Future<Device?> migrateLegacySerialConfig({
  required ILibraryRepository repository,
  required String legacyPort,
}) async {
  if (legacyPort.trim().isEmpty) return null;
  final devicesResult = await ListDevices(repository).call().run();
  final devices = devicesResult.getOrElse((_) => const <Device>[]);
  final target = devices.where((d) => d.serialConfig == null).firstOrNull;
  if (target == null) return null;
  final updated = await UpdateDeviceSerialConfig(repository: repository)
      .call(
        deviceId: target.meta.id,
        serialConfig: SerialConfig(
          portName: legacyPort,
          baudRate: DacalSerialSettings.baudRate,
        ),
      )
      .run();
  return updated.toNullable();
}
