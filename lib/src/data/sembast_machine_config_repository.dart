import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';

import '../domain/domain.dart';
import 'sembast_schema.dart';
import 'sembast_transaction_scope.dart';

/// The sembast-backed **config sidecar** for machine instances.
///
/// Keys per-machine connection config ([MachineConfig]) by the machine's
/// sku_catalog [Instance] id. This keeps the typed `hidConfig`/`serialConfig`/
/// `demoMode` decal domain data beside — but out of — the shared catalog
/// stores, so sku_catalog's trait/attribute classification model is never bent
/// to carry connection wiring.
///
/// Uses decalcd's own [DecalFailure] (not sku_catalog's [cat.DomainFailure]):
/// the shared catalog owns identity/classification; this decal-side store owns
/// the machine's connection config, so failures surface in decalcd's language.
/// A missing config is [NotFoundFailure]; a storage fault maps to
/// [StorageFailure]. Unlike the catalog repositories, the sidecar is
/// upsert-by-key (its key is the instance id, so a machine never has two
/// configs).
class SembastMachineConfigRepository {
  /// Creates a sidecar over [database] (transaction-scoped when [scope] set).
  SembastMachineConfigRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  final Database _database;
  final SembastTransactionScope _scope;

  DatabaseClient get _client => _scope.active ?? _database;

  /// Reads the [MachineConfig] for [instanceId], or [NotFoundFailure].
  TaskEither<DecalFailure, MachineConfig> fetch(String instanceId) =>
      TaskEither.tryCatch(() async {
        final record = await machineConfigStore.record(instanceId).get(_client);
        if (record == null) {
          throw _NotFound('No config for machine instance "$instanceId"');
        }
        return MachineConfig.fromJson(record);
      }, _failureOrStorageError);

  /// Writes (upserts) [config], keyed by its [MachineConfig.instanceId].
  TaskEither<DecalFailure, MachineConfig> save(MachineConfig config) =>
      TaskEither.tryCatch(() async {
        await machineConfigStore
            .record(config.instanceId)
            .put(_client, config.toJson());
        return config;
      }, _storageError);

  /// Returns whether a config exists for [instanceId].
  TaskEither<DecalFailure, bool> exists(String instanceId) =>
      TaskEither.tryCatch(() async {
        final record = await machineConfigStore.record(instanceId).get(_client);
        return record != null;
      }, _storageError);

  /// Removes the config for [instanceId], if present.
  TaskEither<DecalFailure, void> delete(String instanceId) =>
      TaskEither.tryCatch(() async {
        await machineConfigStore.record(instanceId).delete(_client);
      }, _storageError);

  /// Returns every stored [MachineConfig] (links to catalog instances).
  TaskEither<DecalFailure, List<MachineConfig>> fetchAll() =>
      TaskEither.tryCatch(() async {
        final records = await machineConfigStore.find(_client);
        return records
            .map((r) => MachineConfig.fromJson(r.value))
            .toList();
      }, _storageError);
}

/// Signals an absent sidecar record, mapped to [NotFoundFailure].
class _NotFound implements Exception {
  const _NotFound(this.message);
  final String message;
}

/// Maps a [_NotFound] to [NotFoundFailure]; anything else to [StorageFailure].
DecalFailure _failureOrStorageError(Object error, StackTrace stackTrace) {
  if (error is _NotFound) return NotFoundFailure(error.message);
  return _storageError(error, stackTrace);
}

/// Maps any storage exception to a [StorageFailure].
DecalFailure _storageError(Object error, StackTrace stackTrace) =>
    StorageFailure('Sidecar storage operation failed: $error');
