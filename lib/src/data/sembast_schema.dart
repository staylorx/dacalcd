import 'package:sembast/sembast.dart';

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

/// The store that marks the storage schema version reached by the latest
/// migration. Written by [libraryMigrations].
final StoreRef<String, Map<String, Object?>> schemaStore = stringMapStoreFactory
    .store('schema_meta');

/// The current storage schema version.
///
/// Bump this (and add a case to [libraryMigrations]) whenever a change needs
/// a data migration rather than a fresh store.
const int librarySchemaVersion = 1;

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
      default:
        throw StateError('No migration defined for schema version $version');
    }
  }
};
