import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';
import 'sembast_schema.dart';
import 'sembast_transaction_scope.dart';

/// A sembast-backed [ILibraryRepository].
///
/// **Machines** are stored the catalog-backed way: a machine's identity lands
/// in the shared sku_catalog stores — its machine [cat.Sku] in `skuStore` and
/// its physical unit as a [cat.Instance] in `instanceStore` — while its typed
/// connection config goes to the `machineConfigStore` sidecar keyed by the
/// instance id ([MachineConfig]). This is the same storage the catalog
/// repositories ([SembastSkuRepository], [SembastInstanceRepository]) read, so
/// a machine written here is a first-class catalog record, not a private blob.
///
/// **Slots** (with their embedded [Disc] copy) and the disc catalog still ride
/// in `slotStore`/`discStore`; re-pointing those onto the catalog stores is a
/// later slice. Every public method returns an fpdart [TaskEither] and never
/// throws: a genuine storage fault becomes a [StorageFailure] via
/// `TaskEither.tryCatch`, and an absent record a [NotFoundFailure].
///
/// A caller that wants a group of writes to be atomic passes a
/// [SembastUnitOfWork] built on the **same** [SembastTransactionScope] as this
/// repository; while the unit of work is active, this repository routes every
/// read and write through the scope's transaction instead of the bare
/// [Database].
class SembastLibraryRepository implements ILibraryRepository {
  /// Creates a repository over [database] whose writes join the transaction
  /// exposed through [scope] (shared with any [SembastUnitOfWork] that should
  /// keep this repository's writes transactional).
  SembastLibraryRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  final Database _database;
  final SembastTransactionScope _scope;

  /// The client (transaction when one is active, else the database) that all
  /// store operations target.
  DatabaseClient get _client => _scope.active ?? _database;

  @override
  TaskEither<DecalFailure, List<Device>> fetchDevices() =>
      TaskEither.tryCatch(() async {
        final records = await instanceStore.find(_client);
        final devices = <Device>[];
        for (final record in records) {
          final device = await _deviceFromInstanceRecord(record.value);
          if (device != null) devices.add(device);
        }
        return devices;
      }, _storageError);

  @override
  TaskEither<DecalFailure, Device> fetchDeviceBySerialCode({
    required String serialCode,
  }) => TaskEither.tryCatch(() async {
    final records = await instanceStore.find(
      _client,
      finder: Finder(filter: Filter.equals('serial_number', serialCode)),
    );
    for (final record in records) {
      final device = await _deviceFromInstanceRecord(record.value);
      if (device != null) return device;
    }
    throw _NotFound('Device with serial code "$serialCode" not found');
  }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Device> fetchDeviceById({required String id}) =>
      TaskEither.tryCatch(() async {
        final record = await instanceStore.record(id).get(_client);
        if (record == null) {
          throw _NotFound('Device "$id" not found');
        }
        final device = await _deviceFromInstanceRecord(record);
        if (device == null) {
          throw _NotFound('Device "$id" not found');
        }
        return device;
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Device> saveDevice({required Device device}) =>
      TaskEither.tryCatch(() async {
        // Identity: the machine SKU and its physical instance go into the
        // shared catalog stores; the typed connection config into the sidecar.
        final sku = device.machineSku;
        if (sku != null) {
          await skuStore.record(sku.meta.id).put(_client, sku.toJson());
        }
        await instanceStore
            .record(device.meta.id)
            .put(_client, device.toInstance().toJson());
        await machineConfigStore
            .record(device.meta.id)
            .put(_client, device.config.toJson());
        return device;
      }, _storageError);

  @override
  TaskEither<DecalFailure, void> deleteDevice({required String id}) =>
      TaskEither.tryCatch(() async {
        final deleted = await instanceStore.record(id).delete(_client);
        if (deleted == null) {
          throw _NotFound('Device "$id" not found');
        }
        // Drop the machine's sidecar config too, so no orphan is left behind.
        await machineConfigStore.record(id).delete(_client);
        // Cascade: remove every slot belonging to the deleted machine so it
        // leaves no orphaned records.
        final slots = await slotStore.find(
          _client,
          finder: Finder(filter: Filter.equals('device_id', id)),
        );
        for (final slot in slots) {
          await slotStore.record(slot.key).delete(_client);
        }
      }, _failureOrStorageError);

  /// Reassembles a [Device] from a stored catalog instance record: reads the
  /// machine [cat.Sku] it points at and its sidecar config, then joins them.
  ///
  /// Returns null when the record is not a machine instance (e.g. a disc
  /// instance placed at a location), so callers skip it. Machine-ness is judged
  /// by the referenced SKU carrying the `serializable` trait — falling back to a
  /// non-empty instance serial number when the SKU row is absent.
  Future<Device?> _deviceFromInstanceRecord(Map<String, dynamic> json) async {
    final instance = cat.Instance.fromJson(json);
    final skuJson = await skuStore.record(instance.skuId).get(_client);
    final sku = skuJson == null ? null : cat.Sku.fromJson(skuJson);
    if (!_isMachine(instance, sku)) return null;
    final configJson =
        await machineConfigStore.record(instance.meta.id).get(_client);
    final config =
        configJson == null ? null : MachineConfig.fromJson(configJson);
    return Device.fromParts(instance: instance, machineSku: sku, config: config);
  }

  @override
  TaskEither<DecalFailure, List<Slot>> listSlots({required String deviceId}) =>
      TaskEither.tryCatch(() async {
        final device = await instanceStore.record(deviceId).get(_client);
        if (device == null) {
          throw _NotFound('Device "$deviceId" not found');
        }
        final records = await slotStore.find(
          _client,
          finder: Finder(
            filter: Filter.equals('device_id', deviceId),
            sortOrders: [SortOrder('slot_number')],
          ),
        );
        return records.map((r) => Slot.fromJson(r.value)).toList();
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Slot> fetchSlot({
    required String deviceId,
    required int slotNumber,
  }) => TaskEither.tryCatch(() async {
    final record = await slotStore.findFirst(
      _client,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('device_id', deviceId),
          Filter.equals('slot_number', slotNumber),
        ]),
      ),
    );
    if (record == null) {
      throw _NotFound('Slot $slotNumber on device "$deviceId" not found');
    }
    return Slot.fromJson(record.value);
  }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Slot> updateSlot({required Slot slot}) =>
      TaskEither.tryCatch(() async {
        await slotStore.record(slot.meta.id).put(_client, slot.toJson());
        return slot;
      }, _storageError);

  @override
  TaskEither<DecalFailure, Slot?> locateDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final records = await slotStore.find(
          _client,
          finder: Finder(filter: Filter.equals('disc.id', discId)),
        );
        if (records.isEmpty) return null;
        return Slot.fromJson(records.first.value);
      }, _storageError);

  @override
  TaskEither<DecalFailure, Disc> saveDisc({required Disc disc}) =>
      TaskEither.tryCatch(() async {
        await discStore.record(disc.meta.id).put(_client, disc.toJson());
        return disc;
      }, _storageError);

  @override
  TaskEither<DecalFailure, Disc> fetchDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final record = await discStore.record(discId).get(_client);
        if (record == null) {
          throw _NotFound('Disc "$discId" not found');
        }
        return Disc.fromJson(record);
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, List<Disc>> listDiscs() =>
      TaskEither.tryCatch(() async {
        final records = await discStore.find(
          _client,
          finder: Finder(sortOrders: [
            SortOrder('sku_id'),
            SortOrder('label'),
          ]),
        );
        return records.map((r) => Disc.fromJson(r.value)).toList();
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, void> deleteDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final deleted = await discStore.record(discId).delete(_client);
        if (deleted == null) {
          throw _NotFound('Disc "$discId" not found');
        }
      }, _failureOrStorageError);
}

/// A repository-internal "not found" signal. It is caught by
/// [_failureOrStorageError] and mapped to a [NotFoundFailure]; it is not a
/// storage fault.
class _NotFound implements Exception {
  const _NotFound(this.message);
  final String message;
}

/// Maps a caught [_NotFound] back to a domain [NotFoundFailure], and any other
/// exception to a [StorageFailure]. Used on read paths that must distinguish
/// "absent" from "the store broke".
DecalFailure _failureOrStorageError(Object error, StackTrace stackTrace) {
  if (error is _NotFound) return NotFoundFailure(error.message);
  return _storageError(error, stackTrace);
}

/// Maps any storage exception to a [StorageFailure].
DecalFailure _storageError(Object error, StackTrace stackTrace) =>
    StorageFailure('Storage operation failed: $error');

/// Whether a stored instance record is a CD library **machine** rather than
/// some other instance (e.g. a disc placed in a slot).
///
/// A machine's SKU carries the `serializable` trait (every machine has a serial
/// number, captured on that trait). When the SKU row is absent the instance's
/// own non-empty serial number is the fallback signal.
bool _isMachine(cat.Instance instance, cat.Sku? sku) {
  if (sku != null) return sku.traitIds.contains(kDcSerializableTrait.meta.id);
  final serial = instance.serialNumber;
  return serial != null && serial.isNotEmpty;
}
