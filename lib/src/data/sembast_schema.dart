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

/// The store that holds every catalogued [Disc] row, keyed by the disc's
/// opaque [Meta.id]. The library catalog lives here, independent of the
/// inline disc copies embedded on [slotStore] rows.
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
const int librarySchemaVersion = 2;

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
