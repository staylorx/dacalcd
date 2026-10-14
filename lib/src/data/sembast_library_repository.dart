import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';
import 'sembast_schema.dart';
import 'sembast_transaction_scope.dart';

/// A sembast-backed [ILibraryRepository].
///
/// Everything persistent here is a catalog record:
///
/// * a **machine**'s identity lands in the shared sku_catalog stores — its
///   machine [cat.Sku] in `skuStore` and its physical unit as a [cat.Instance]
///   in `instanceStore` — while its typed connection config goes to the
///   `machineConfigStore` sidecar keyed by the instance id ([MachineConfig]);
/// * a **disc** is the same shape: its media [cat.Sku] in `skuStore`, the
///   physical disc as a [cat.Instance] in `instanceStore`;
/// * a **slot** row is the machine's carousel *layout* only (which slots
///   exist). Placement is not a copy of the disc held by the slot — it is a
///   value on the disc instance: `locateId` is the machine it sits in and the
///   `slot_number` attribute is the position. A slot read back is therefore
///   hydrated from the instance store, and slotting a disc *is* reifying it as
///   an instance placed at that position.
///
/// This is the same storage the catalog repositories ([SembastSkuRepository],
/// [SembastInstanceRepository]) read, so a machine or disc written here is a
/// first-class catalog record, not a private blob.
///
/// Every public method returns an fpdart [TaskEither] and never throws: a
/// genuine storage fault becomes a [StorageFailure] via `TaskEither.tryCatch`,
/// and an absent record a [NotFoundFailure].
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

  // ---------------------------------------------------------------- machines

  @override
  TaskEither<DecalFailure, List<Device>> fetchDevices() =>
      TaskEither.tryCatch(() async {
        final records = await instanceStore.find(_client);
        final devices = <Device>[];
        for (final record in records) {
          final device = await _deviceFromInstance(record.value);
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
      final device = await _deviceFromInstance(record.value);
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
        final device = await _deviceFromInstance(record);
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
        // Cascade: remove the machine's carousel layout rows…
        final slots = await slotStore.find(
          _client,
          finder: Finder(filter: Filter.equals('device_id', id)),
        );
        for (final slot in slots) {
          await slotStore.record(slot.key).delete(_client);
        }
        // …and unplace any disc that sat in it — the discs stay catalogued,
        // they are simply no longer in a machine.
        for (final instance in await _instancesLocatedAt(id)) {
          await instanceStore
              .record(instance.meta.id)
              .put(_client, _unplace(instance).toJson());
        }
      }, _failureOrStorageError);

  /// Reassembles a [Device] from a stored catalog instance record: reads the
  /// machine [cat.Sku] it points at and its sidecar config, then joins them.
  ///
  /// Returns null when the record is not a machine instance (e.g. a disc
  /// instance placed in a slot), so callers skip it.
  Future<Device?> _deviceFromInstance(Map<String, dynamic> json) async {
    final instance = cat.Instance.fromJson(json);
    final sku = await _skuFor(instance.skuId);
    if (!_isMachine(instance, sku)) return null;
    final configJson = await machineConfigStore
        .record(instance.meta.id)
        .get(_client);
    final config = configJson == null
        ? null
        : MachineConfig.fromJson(configJson);
    return Device.fromParts(instance: instance, machineSku: sku, config: config);
  }

  // ------------------------------------------------------------------- slots

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
        final slots = <Slot>[];
        for (final record in records) {
          slots.add(await _slotFromLayout(record.value));
        }
        return slots;
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
    return _slotFromLayout(record.value);
  }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, Slot> updateSlot({required Slot slot}) =>
      TaskEither.tryCatch(() async {
        // The row is the carousel layout only — placement lives on the disc
        // instance, so this writes both the layout and the placement.
        await slotStore
            .record(slot.meta.id)
            .put(_client, _slotLayoutJson(slot));
        await _applyPlacement(slot: slot);
        return slot;
      }, _storageError);

  @override
  TaskEither<DecalFailure, Slot?> locateDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final record = await instanceStore.record(discId).get(_client);
        if (record == null) return null;
        final instance = cat.Instance.fromJson(record);
        final disc = await _discFor(instance);
        if (disc == null) return null; // a machine, not a disc
        final deviceId = instance.locateId;
        final slotNumber = _slotNumberOf(instance);
        if (deviceId == null || slotNumber == null) return null;
        // Prefer the machine's own layout row for the slot's identity.
        final layout = await slotStore.findFirst(
          _client,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('device_id', deviceId),
              Filter.equals('slot_number', slotNumber),
            ]),
          ),
        );
        final meta = layout == null
            ? Meta(
                id: 'slot:$deviceId:$slotNumber',
                notes: '',
                createdAt: '',
                updatedAt: '',
              )
            : Meta.fromJson(layout.value);
        return Slot(
          meta: meta,
          deviceId: deviceId,
          slotNumber: slotNumber,
          disc: disc,
        );
      }, _storageError);

  /// Writes the placement a [Slot] describes onto the catalog stores: the disc
  /// instance gets `locateId` = the machine and its `slot_number` attribute,
  /// and whatever used to sit at that position is unplaced.
  ///
  /// An empty slot unplaces the disc currently at that position. Placing a disc
  /// reifies it: the disc is written as an instance *at that position*.
  Future<void> _applyPlacement({required Slot slot}) async {
    final seated = await _instancePlacedAt(slot.deviceId, slot.slotNumber);
    final disc = slot.disc;
    if (disc == null) {
      if (seated != null) {
        await instanceStore
            .record(seated.meta.id)
            .put(_client, _unplace(seated).toJson());
      }
      return;
    }
    // Anything different that was sitting here is displaced first.
    if (seated != null && seated.meta.id != disc.meta.id) {
      await instanceStore
          .record(seated.meta.id)
          .put(_client, _unplace(seated).toJson());
    }
    final mediaSku = disc.discSku;
    if (mediaSku != null) {
      await skuStore.record(mediaSku.meta.id).put(_client, mediaSku.toJson());
    }
    final placed = disc.toInstance().copyWith(
      locateId: slot.deviceId,
      attributeValues: {
        ...disc.attributeValues,
        kSlotNumberTraitAttributeKey: slot.slotNumber,
      },
    );
    await instanceStore.record(placed.meta.id).put(_client, placed.toJson());
  }

  /// Rebuilds a [Slot] from its layout row plus whatever disc instance is
  /// placed at that position.
  Future<Slot> _slotFromLayout(Map<String, dynamic> json) async {
    final deviceId = json['device_id'] as String? ?? '';
    final slotNumber = (json['slot_number'] as num?)?.toInt() ?? 0;
    final seated = await _instancePlacedAt(deviceId, slotNumber);
    return Slot(
      meta: Meta.fromJson(json),
      deviceId: deviceId,
      slotNumber: slotNumber,
      disc: seated == null ? null : await _discFor(seated),
    );
  }

  /// The carousel-layout record for a slot: which slot exists on which
  /// machine. Deliberately carries no copy of the disc — placement is the
  /// instance's, not the slot's.
  Map<String, dynamic> _slotLayoutJson(Slot slot) => {
    ...slot.meta.toJson(),
    'device_id': slot.deviceId,
    'slot_number': slot.slotNumber,
  };

  /// The instance placed at ([deviceId], [slotNumber]) — the disc whose
  /// `locateId` is the machine and whose `slot_number` attribute is the
  /// position.
  Future<cat.Instance?> _instancePlacedAt(
    String deviceId,
    int slotNumber,
  ) async {
    final records = await instanceStore.find(
      _client,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('locate_id', deviceId),
          Filter.equals(
            'attribute_values.$kSlotNumberTraitAttributeKey',
            slotNumber,
          ),
        ]),
      ),
    );
    if (records.isEmpty) return null;
    return cat.Instance.fromJson(records.first.value);
  }

  /// Every instance placed at [deviceId] (used by the delete cascade).
  Future<List<cat.Instance>> _instancesLocatedAt(String deviceId) async {
    final records = await instanceStore.find(
      _client,
      finder: Finder(filter: Filter.equals('locate_id', deviceId)),
    );
    return records
        .map((r) => cat.Instance.fromJson(r.value))
        .toList(growable: false);
  }

  // ------------------------------------------------------------------- discs

  @override
  TaskEither<DecalFailure, Disc> saveDisc({required Disc disc}) =>
      TaskEither.tryCatch(() async {
        await _putDisc(disc);
        return disc;
      }, _storageError);

  @override
  TaskEither<DecalFailure, Disc> fetchDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final record = await instanceStore.record(discId).get(_client);
        if (record == null) {
          throw _NotFound('Disc "$discId" not found');
        }
        final instance = cat.Instance.fromJson(record);
        final disc = await _discFor(instance);
        if (disc == null) {
          throw _NotFound('Disc "$discId" not found');
        }
        return disc;
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, List<Disc>> listDiscs() =>
      TaskEither.tryCatch(() async {
        final records = await instanceStore.find(_client);
        final discs = <Disc>[];
        for (final record in records) {
          final disc = await _discFor(cat.Instance.fromJson(record.value));
          if (disc != null) discs.add(disc);
        }
        discs.sort((a, b) {
          final bySku = a.skuId.compareTo(b.skuId);
          if (bySku != 0) return bySku;
          return (a.label ?? '').compareTo(b.label ?? '');
        });
        return discs;
      }, _failureOrStorageError);

  @override
  TaskEither<DecalFailure, void> deleteDisc({required String discId}) =>
      TaskEither.tryCatch(() async {
        final deleted = await instanceStore.record(discId).delete(_client);
        if (deleted == null) {
          throw _NotFound('Disc "$discId" not found');
        }
      }, _failureOrStorageError);

  /// Writes a disc as its two catalog halves: the media [cat.Sku] to
  /// `skuStore` and the physical disc instance to `instanceStore`.
  Future<void> _putDisc(Disc disc) async {
    final sku = disc.discSku;
    if (sku != null) {
      await skuStore.record(sku.meta.id).put(_client, sku.toJson());
    }
    await instanceStore
        .record(disc.meta.id)
        .put(_client, disc.toInstance().toJson());
  }

  /// Reassembles a [Disc] from a stored instance, or null when the instance is
  /// a machine rather than a disc.
  Future<Disc?> _discFor(cat.Instance instance) async {
    final sku = await _skuFor(instance.skuId);
    if (_isMachine(instance, sku)) return null;
    return Disc.fromParts(instance: instance, discSku: sku);
  }

  /// The catalog SKU named by [skuId], or null when the row is absent.
  Future<cat.Sku?> _skuFor(String skuId) async {
    final json = await skuStore.record(skuId).get(_client);
    return json == null ? null : cat.Sku.fromJson(json);
  }
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
/// some other instance (a disc placed in a slot).
///
/// A machine's SKU carries the `serializable` trait (every machine has a serial
/// number, captured on that trait). When the SKU row is absent the instance's
/// own non-empty serial number is the fallback signal.
bool _isMachine(cat.Instance instance, cat.Sku? sku) {
  if (sku != null) return sku.traitIds.contains(kDcSerializableTrait.meta.id);
  final serial = instance.serialNumber;
  return serial != null && serial.isNotEmpty;
}

/// The slot an instance occupies, from its `slot_number` attribute; null when
/// it is not slotted.
int? _slotNumberOf(cat.Instance instance) =>
    (instance.attributeValues[kSlotNumberTraitAttributeKey] as num?)?.toInt();

/// The instance with its placement cleared: no [cat.Instance.locateId] and no
/// `slot_number` attribute.
cat.Instance _unplace(cat.Instance instance) {
  final values = {...instance.attributeValues}
    ..remove(kSlotNumberTraitAttributeKey);
  return instance.copyWith(locateId: null, attributeValues: values);
}
