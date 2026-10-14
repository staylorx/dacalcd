import 'package:sembast/sembast.dart';

import '../domain/domain.dart';

/// The store that holds every persistent [Device] row, keyed by the device's
/// opaque [Meta.id].
final StoreRef<String, Map<String, Object?>> deviceStore = stringMapStoreFactory
    .store('devices');

/// The store that holds every persistent [Slot] row, keyed by the slot's
/// opaque [Meta.id].
final StoreRef<String, Map<String, Object?>> slotStore = stringMapStoreFactory
    .store('slots');

/// The legacy store that held every catalogued [Disc] row, keyed by the disc's
/// opaque [Meta.id].
///
/// Superseded: the disc catalog now lives in the shared catalog stores (the
/// media [Sku] in [skuStore], the physical disc as an [Instance] in
/// [instanceStore]). Kept so the v3 migration can read and retire the old rows.
final StoreRef<String, Map<String, Object?>> discStore = stringMapStoreFactory
    .store('discs');

/// The store that backs the shared sku_catalog model: every catalog [Sku]
/// row (machines and discs), keyed by its sku_catalog [Meta.id].
final StoreRef<String, Map<String, Object?>> skuStore = stringMapStoreFactory
    .store('skus');

/// The store that backs the shared sku_catalog trait model — every [Trait]
/// (e.g. `hid`, `serializable`, `cd`, `dvd`), keyed by its sku_catalog
/// [Meta.id].
final StoreRef<String, Map<String, Object?>> traitStore = stringMapStoreFactory
    .store('traits');

/// The store that backs sku_catalog trait-attribute definitions (e.g. the
/// `serial_number` attribute on the `serializable` trait).
final StoreRef<String, Map<String, Object?>> traitAttributeDefinitionStore =
    stringMapStoreFactory.store('trait_attribute_definitions');

/// The store that backs sku_catalog [Instance] rows — the physical machines at
/// each site (e.g. serial `67808`), keyed by their sku_catalog [Meta.id].
final StoreRef<String, Map<String, Object?>> instanceStore =
    stringMapStoreFactory.store('instances');

/// Decal-side connection config for a machine, keyed by the machine's
/// sku_catalog [Instance] id. Holds the typed `hidConfig`/`serialConfig`/
/// `demoMode` that sku_catalog's model does not express (they are per-instance
/// decal domain, not trait attributes).
final StoreRef<String, Map<String, Object?>> machineConfigStore =
    stringMapStoreFactory.store('machine_config');

/// The store that marks the storage schema version reached by the latest
/// migration. Written by [libraryMigrations].
final StoreRef<String, Map<String, Object?>> schemaStore = stringMapStoreFactory
    .store('schema_meta');

/// The current storage schema version.
///
/// Bump this (and add a case to [libraryMigrations]) whenever a change needs
/// a data migration rather than a fresh store.
///
/// * v1 — baseline.
/// * v2 — machines moved off the single `devices` blob store onto the shared
///   catalog stores (machine [Sku] + [Instance]) plus the config sidecar.
/// * v3 — discs moved off the `discs` blob store onto the same catalog stores,
///   and slot rows stopped embedding a disc copy: a slot row is now the
///   carousel layout alone, with placement recorded as `locateId` + the
///   `slot_number` attribute on the disc instance.
const int librarySchemaVersion = 3;

/// The `onVersionChanged` handler passed to sembast's `openDatabase`.
///
/// Sembast calls this only when the on-disk version differs from the version
/// requested at open. The closure therefore migrates the store from
/// [oldVersion] to [newVersion] by running the listed up-only steps in order.
/// Version 1 establishes the schema marker so future migrations have a
/// baseline to branch from, and is a no-op data-wise (sembast creates the
/// stores lazily on first write).
OnVersionChangedFunction
libraryMigrations = (Database db, int oldVersion, int newVersion) async {
  for (var version = oldVersion + 1; version <= newVersion; version++) {
    switch (version) {
      case 1:
        // Baseline: record that the schema now lives at v1. All stores are
        // created lazily by sembast on first use, so there is no DDL to run.
        await schemaStore.record('version').put(db, {'version': 1});
      case 2:
        // Machines moved off the single `devices` blob store onto the shared
        // catalog stores (machine Sku in `skuStore`, machine Instance in
        // `instanceStore`) plus the config sidecar (`machineConfigStore`).
        // Split every legacy device row, then drop the blob rows so there is
        // no stale second copy of a machine.
        await _splitLegacyDeviceRows(db);
        await schemaStore.record('version').put(db, {'version': 2});
      case 3:
        // Discs move off the `discs` blob store onto the catalog stores, and
        // slot rows stop embedding a disc copy — the embedded copy becomes the
        // placement (locateId + `slot_number`) on the disc instance.
        await _repointDiscAndSlotRows(db);
        await schemaStore.record('version').put(db, {'version': 3});
      default:
        throw StateError('No migration defined for schema version $version');
    }
  }
};

/// v2 migration: rewrites every row of the legacy `devices` store into the
/// catalog + sidecar stores and then clears the legacy store.
///
/// Runs over the raw [Database] (not a scoped client) because it executes
/// during open, before any repository is bound. Idempotent enough to be safe:
/// it only acts when legacy rows exist, and clears them once split.
Future<void> _splitLegacyDeviceRows(Database db) async {
  final records = await deviceStore.find(db);
  if (records.isEmpty) return;
  for (final record in records) {
    final device = Device.fromJson(record.value);
    final sku = device.machineSku;
    if (sku != null) {
      await skuStore.record(sku.meta.id).put(db, sku.toJson());
    }
    await instanceStore.record(device.meta.id).put(db, device.toInstance().toJson());
    await machineConfigStore
        .record(device.meta.id)
        .put(db, device.config.toJson());
  }
  await deviceStore.delete(db);
}

/// v3 migration: moves every legacy disc row onto the shared catalog stores and
/// rewrites each slot row as carousel layout only (no embedded disc copy).
///
/// A disc that a slot embedded is not lost: the embedded copy becomes the disc
/// instance's placement — `locateId` = the machine, `slot_number` = the slot —
/// which is where placement lives from v3 on. Runs over the raw [Database]
/// because it executes during open, before any repository is bound.
Future<void> _repointDiscAndSlotRows(Database db) async {
  final slots = await slotStore.find(db);
  for (final record in slots) {
    final json = record.value;
    final deviceId = json['device_id'] as String? ?? '';
    final slotNumber = (json['slot_number'] as num?)?.toInt() ?? 0;
    final embedded = json['disc'];
    if (embedded is Map<String, dynamic>) {
      final disc = Disc.fromJson(embedded);
      final sku = disc.discSku;
      if (sku != null) {
        await skuStore.record(sku.meta.id).put(db, sku.toJson());
      }
      final placed = disc.toInstance().copyWith(
        locateId: deviceId.isEmpty ? null : deviceId,
        attributeValues: {
          ...disc.attributeValues,
          kSlotNumberTraitAttributeKey: slotNumber,
        },
      );
      await instanceStore.record(placed.meta.id).put(db, placed.toJson());
    }
    // The slot row keeps only the layout.
    await slotStore.record(record.key).put(db, {
      'id': json['id'],
      'notes': json['notes'] ?? '',
      'created_at': json['created_at'] ?? '',
      'updated_at': json['updated_at'] ?? '',
      'device_id': deviceId,
      'slot_number': slotNumber,
    });
  }

  // Catalogue discs that were never placed, unless the slot pass already wrote
  // them (a placed disc must keep its placement).
  for (final record in await discStore.find(db)) {
    final disc = Disc.fromJson(record.value);
    if (await instanceStore.record(disc.meta.id).get(db) != null) continue;
    final sku = disc.discSku;
    if (sku != null) {
      await skuStore.record(sku.meta.id).put(db, sku.toJson());
    }
    await instanceStore
        .record(disc.meta.id)
        .put(db, disc.toInstance().toJson());
  }

  await discStore.delete(db);
}
