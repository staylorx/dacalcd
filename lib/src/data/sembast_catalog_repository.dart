import 'package:fpdart/fpdart.dart';
import 'package:sembast/sembast.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import 'sembast_schema.dart';
import 'sembast_transaction_scope.dart';

/// A [cat.ISkuRepository] backed by sembast.
///
/// sku_catalog ships no storage — persistence is decalcd's job. This is the
/// foundation of the catalog-backed model: SKUs (machines and discs) live in
/// the shared model, keyed by their sku_catalog [Meta.id]. Every method returns
/// an fpdart [TaskEither] and never throws: a storage fault maps to
/// [cat.DatasourceFailure], an absent record to [cat.NotFoundFailure]. Reads
/// and writes go through the active [SembastTransactionScope] when one is set,
/// otherwise the bare database.
class SembastSkuRepository implements cat.ISkuRepository {
  /// Creates a SKU repository over [database].
  SembastSkuRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  /// The sembast [Database] backing this repository.
  final Database _database;
  final SembastTransactionScope _scope;

  DatabaseClient get _client => _scope.active ?? _database;

  @override
  TaskEither<cat.DomainFailure, List<cat.Sku>> fetchAll() =>
      TaskEither.tryCatch(() async {
        final records = await skuStore.find(_client);
        return records.map((r) => cat.Sku.fromJson(r.value)).toList();
      }, _storageError);

  @override
  TaskEither<cat.DomainFailure, cat.Sku> fetchById({required String id}) =>
      TaskEither.tryCatch(() async {
        final record = await skuStore.record(id).get(_client);
        if (record == null) throw _NotFound('Sku "$id" not found');
        return cat.Sku.fromJson(record);
      }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Sku> create({
    required cat.Sku sku,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await skuStore.record(sku.meta.id).get(_client);
    if (existing != null) {
      throw _AlreadyExists('Sku "${sku.meta.id}" already exists');
    }
    await skuStore.record(sku.meta.id).put(_client, sku.toJson());
    return sku;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Sku> update({
    required cat.Sku sku,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await skuStore.record(sku.meta.id).get(_client);
    if (existing == null) {
      throw _NotFound('Cannot update missing Sku "${sku.meta.id}"');
    }
    await skuStore.record(sku.meta.id).put(_client, sku.toJson());
    return sku;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> delete({
    required String id,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final deleted = await skuStore.record(id).delete(_client);
    if (deleted == null) throw _NotFound('Sku "$id" not found');
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> clearAll({cat.IUnitOfWork? uow}) =>
      TaskEither.tryCatch(() => skuStore.delete(_client), _storageError);
}

/// A [cat.ITraitRepository] backed by sembast.
class SembastTraitRepository implements cat.ITraitRepository {
  /// Creates a trait repository over [database].
  SembastTraitRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  final Database _database;
  final SembastTransactionScope _scope;

  DatabaseClient get _client => _scope.active ?? _database;

  @override
  TaskEither<cat.DomainFailure, List<cat.Trait>> fetchAll() =>
      TaskEither.tryCatch(() async {
        final records = await traitStore.find(_client);
        return records.map((r) => cat.Trait.fromJson(r.value)).toList();
      }, _storageError);

  @override
  TaskEither<cat.DomainFailure, cat.Trait> fetchById({required String id}) =>
      TaskEither.tryCatch(() async {
        final record = await traitStore.record(id).get(_client);
        if (record == null) throw _NotFound('Trait "$id" not found');
        return cat.Trait.fromJson(record);
      }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Trait> create({
    required cat.Trait trait,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await traitStore.record(trait.meta.id).get(_client);
    if (existing != null) {
      throw _AlreadyExists('Trait "${trait.meta.id}" already exists');
    }
    await traitStore.record(trait.meta.id).put(_client, trait.toJson());
    return trait;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Trait> update({
    required cat.Trait trait,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await traitStore.record(trait.meta.id).get(_client);
    if (existing == null) {
      throw _NotFound('Cannot update missing Trait "${trait.meta.id}"');
    }
    await traitStore.record(trait.meta.id).put(_client, trait.toJson());
    return trait;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> delete({
    required String id,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final deleted = await traitStore.record(id).delete(_client);
    if (deleted == null) throw _NotFound('Trait "$id" not found');
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> clearAll({cat.IUnitOfWork? uow}) =>
      TaskEither.tryCatch(() => traitStore.delete(_client), _storageError);
}

/// A [cat.ITraitAttributeDefinitionRepository] backed by sembast.
class SembastTraitAttributeDefinitionRepository
    implements cat.ITraitAttributeDefinitionRepository {
  /// Creates a trait-attribute-definition repository over [database].
  SembastTraitAttributeDefinitionRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  final Database _database;
  final SembastTransactionScope _scope;

  DatabaseClient get _client => _scope.active ?? _database;

  @override
  TaskEither<cat.DomainFailure, List<cat.TraitAttributeDefinition>> fetchAll() =>
      TaskEither.tryCatch(() async {
        final records = await traitAttributeDefinitionStore.find(_client);
        return records
            .map((r) => cat.TraitAttributeDefinition.fromJson(r.value))
            .toList();
      }, _storageError);

  @override
  TaskEither<cat.DomainFailure, List<cat.TraitAttributeDefinition>> fetchByTrait({
    required String traitId,
  }) => TaskEither.tryCatch(() async {
    final records = await traitAttributeDefinitionStore.find(
      _client,
      finder: Finder(filter: Filter.equals('trait_id', traitId)),
    );
    return records
        .map((r) => cat.TraitAttributeDefinition.fromJson(r.value))
        .toList();
  }, _storageError);

  @override
  TaskEither<cat.DomainFailure, cat.TraitAttributeDefinition> fetchById({
    required String id,
  }) => TaskEither.tryCatch(() async {
    final record = await traitAttributeDefinitionStore.record(id).get(_client);
    if (record == null) {
      throw _NotFound('TraitAttributeDefinition "$id" not found');
    }
    return cat.TraitAttributeDefinition.fromJson(record);
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.TraitAttributeDefinition> create({
    required cat.TraitAttributeDefinition attribute,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await traitAttributeDefinitionStore
        .record(attribute.meta.id)
        .get(_client);
    if (existing != null) {
      throw _AlreadyExists(
          'TraitAttributeDefinition "${attribute.meta.id}" already exists');
    }
    await traitAttributeDefinitionStore
        .record(attribute.meta.id)
        .put(_client, attribute.toJson());
    return attribute;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.TraitAttributeDefinition> update({
    required cat.TraitAttributeDefinition attribute,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await traitAttributeDefinitionStore
        .record(attribute.meta.id)
        .get(_client);
    if (existing == null) {
      throw _NotFound('Cannot update missing TraitAttributeDefinition '
          '"${attribute.meta.id}"');
    }
    await traitAttributeDefinitionStore
        .record(attribute.meta.id)
        .put(_client, attribute.toJson());
    return attribute;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> delete({
    required String id,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final deleted =
        await traitAttributeDefinitionStore.record(id).delete(_client);
    if (deleted == null) {
      throw _NotFound('TraitAttributeDefinition "$id" not found');
    }
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> clearAll({cat.IUnitOfWork? uow}) =>
      TaskEither.tryCatch(
          () => traitAttributeDefinitionStore.delete(_client), _storageError);
}

/// A [cat.IInstanceRepository] backed by sembast.
class SembastInstanceRepository implements cat.IInstanceRepository {
  /// Creates an instance repository over [database].
  SembastInstanceRepository({
    required Database database,
    SembastTransactionScope? scope,
  }) : _database = database,
       _scope = scope ?? SembastTransactionScope();

  final Database _database;
  final SembastTransactionScope _scope;

  DatabaseClient get _client => _scope.active ?? _database;

  @override
  TaskEither<cat.DomainFailure, List<cat.Instance>> fetchAll() =>
      TaskEither.tryCatch(() async {
        final records = await instanceStore.find(_client);
        return records.map((r) => cat.Instance.fromJson(r.value)).toList();
      }, _storageError);

  @override
  TaskEither<cat.DomainFailure, List<cat.Instance>> fetchByLocate({
    required String locateId,
  }) => TaskEither.tryCatch(() async {
    final records = await instanceStore.find(
      _client,
      finder: Finder(filter: Filter.equals('locate_id', locateId)),
    );
    return records.map((r) => cat.Instance.fromJson(r.value)).toList();
  }, _storageError);

  @override
  TaskEither<cat.DomainFailure, cat.Instance> fetchById({required String id}) =>
      TaskEither.tryCatch(() async {
        final record = await instanceStore.record(id).get(_client);
        if (record == null) throw _NotFound('Instance "$id" not found');
        return cat.Instance.fromJson(record);
      }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Instance> create({
    required cat.Instance instance,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await instanceStore.record(instance.meta.id).get(_client);
    if (existing != null) {
      throw _AlreadyExists('Instance "${instance.meta.id}" already exists');
    }
    await instanceStore.record(instance.meta.id).put(_client, instance.toJson());
    return instance;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, cat.Instance> update({
    required cat.Instance instance,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final existing = await instanceStore.record(instance.meta.id).get(_client);
    if (existing == null) {
      throw _NotFound('Cannot update missing Instance "${instance.meta.id}"');
    }
    await instanceStore.record(instance.meta.id).put(_client, instance.toJson());
    return instance;
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> delete({
    required String id,
    cat.IUnitOfWork? uow,
  }) => TaskEither.tryCatch(() async {
    final deleted = await instanceStore.record(id).delete(_client);
    if (deleted == null) throw _NotFound('Instance "$id" not found');
  }, _failureOrStorageError);

  @override
  TaskEither<cat.DomainFailure, void> clearAll({cat.IUnitOfWork? uow}) =>
      TaskEither.tryCatch(() => instanceStore.delete(_client), _storageError);
}

/// A repository-internal "not found" signal mapped to [cat.NotFoundFailure].
class _NotFound implements Exception {
  const _NotFound(this.message);
  final String message;
}

/// A repository-internal "already exists" signal mapped to
/// [cat.AlreadyExistsFailure].
class _AlreadyExists implements Exception {
  const _AlreadyExists(this.message);
  final String message;
}

/// Maps a caught [_NotFound]/[_AlreadyExists] to its domain failure, and any
/// other exception to a [cat.DatasourceFailure].
cat.DomainFailure _failureOrStorageError(Object error, StackTrace stackTrace) {
  if (error is _NotFound) return cat.NotFoundFailure(error.message);
  if (error is _AlreadyExists) return cat.AlreadyExistsFailure(error.message);
  return _storageError(error, stackTrace);
}

/// Maps any storage exception to a [cat.DatasourceFailure].
cat.DomainFailure _storageError(Object error, StackTrace stackTrace) =>
    cat.DatasourceFailure('Catalog storage operation failed: $error');
