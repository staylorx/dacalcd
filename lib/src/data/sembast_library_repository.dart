import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';

import '../domain/domain.dart';
import 'sembast_schema.dart';
import 'sembast_transaction_scope.dart';

/// A sembast-backed [ILibraryRepository].
///
/// Persists [Device]s and [Slot]s (a slot's embedded [Disc] rides along on the
/// slot row) in two sembast string-keyed stores. Every public method returns
/// an fpdart [TaskEither] and never throws. A genuine storage fault
/// (a sembast / file-I/O exception) is converted at this boundary into a
/// [StorageFailure] value via `TaskEither.tryCatch`.
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
        final records = await deviceStore.find(_client);
        return records.map((r) => Device.fromJson(r.value)).toList();
      }, _storageError);

  @override
  TaskEither<DecalFailure, Device> fetchDeviceBySerialCode({
    required String serialCode,
  }) => TaskEither.tryCatch(() async {
    final records = await deviceStore.find(
      _client,
      finder: Finder(filter: Filter.equals('serial_code', serialCode)),
    );
    if (records.isEmpty) {
      throw _NotFound('Device with serial code "$serialCode" not found');
    }
    return Device.fromJson(records.first.value);
  }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Device> fetchDeviceById({required String id}) =>
      TaskEither.tryCatch(() async {
        final record = await deviceStore.record(id).get(_client);
        if (record == null) {
          throw _NotFound('Device "$id" not found');
        }
        return Device.fromJson(record);
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Device> saveDevice({required Device device}) =>
      TaskEither.tryCatch(() async {
        await deviceStore.record(device.meta.id).put(_client, device.toJson());
        return device;
      }, _storageError);

  @override
  TaskEither<DecalFailure, List<Slot>> listSlots({required String deviceId}) =>
      TaskEither.tryCatch(() async {
        final device = await deviceStore.record(deviceId).get(_client);
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
