import 'package:decalcd/src/data/data.dart';
import 'package:decalcd/src/domain/domain.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;
import 'package:test/test.dart';

var _dbSeq = 0;

/// Opens a fresh, isolated in-memory database per call (the memory factory
/// reuses an open database by name, so a unique name avoids row leakage).
Future<Database> openDb() => databaseFactoryMemory.openDatabase(
  'decalcd-catalog-test-${_dbSeq++}',
);

/// Fails the test if the left side is ever produced where a right is expected.
Never _unexpectedLeft(cat.DomainFailure f) =>
    throw StateError('expected right, got left: $f');

void main() {
  group('SembastCatalogRepository (catalog backing stores)', () {
    late Database db;
    late SembastTransactionScope scope;
    late SembastSkuRepository skus;
    late SembastTraitRepository traits;
    late SembastTraitAttributeDefinitionRepository attributes;
    late SembastInstanceRepository instances;

    setUp(() async {
      db = await openDb();
      scope = SembastTransactionScope();
      skus = SembastSkuRepository(database: db, scope: scope);
      traits = SembastTraitRepository(database: db, scope: scope);
      attributes =
          SembastTraitAttributeDefinitionRepository(database: db, scope: scope);
      instances = SembastInstanceRepository(database: db, scope: scope);
    });

    tearDown(() => db.close());

    test('SKU repo: create, fetch all, fetch by id', () async {
      final sku = dacalMachineSku(
        meta: const cat.Meta(id: 'dc:sku:machine:dc300', notes: '', createdAt: '', updatedAt: ''),
        modelNumber: 'DC-300',
      );

      (await skus.create(sku: sku).run()).isRight().should.beTrue();

      final all = await skus.fetchAll().run();
      all.fold(_unexpectedLeft, (list) => list)
          .single
          .meta
          .id
          .should
          .be('dc:sku:machine:dc300');

      final byId = await skus.fetchById(id: 'dc:sku:machine:dc300').run();
      byId.fold(_unexpectedLeft, (s) => s).modelNumber.should.be('DC-300');
    });

    test('SKU repo: duplicate create -> AlreadyExistsFailure', () async {
      await skus
          .create(
            sku: dacalMachineSku(
              meta: const cat.Meta(id: 's1', notes: '', createdAt: '', updatedAt: ''),
              modelNumber: 'DC-300',
            ),
          )
          .run();
      final dup = await skus
          .create(
            sku: dacalMachineSku(
              meta: const cat.Meta(id: 's1', notes: '', createdAt: '', updatedAt: ''),
              modelNumber: 'DC-300',
            ),
          )
          .run();
      dup.isLeft().should.beTrue();
      dup.fold((f) => f, (_) => throw StateError('expected left'))
          .should
          .beOfType<cat.AlreadyExistsFailure>();
    });

    test('SKU repo: update, delete, then delete missing -> NotFound', () async {
      await skus
          .create(
            sku: dacalMachineSku(
              meta: const cat.Meta(id: 's2', notes: '', createdAt: '', updatedAt: ''),
              modelNumber: 'DC-300',
            ),
          )
          .run();

      (await skus
              .update(
                sku: dacalMachineSku(
                  meta: const cat.Meta(id: 's2', notes: '', createdAt: '', updatedAt: ''),
                  modelNumber: 'DC-300',
                  capacity: 160,
                ),
              )
              .run())
          .isRight()
          .should
          .beTrue();

      final missingUpdate = await skus
          .update(
            sku: dacalMachineSku(
              meta: const cat.Meta(id: 'nope', notes: '', createdAt: '', updatedAt: ''),
              modelNumber: 'X',
            ),
          )
          .run();
      missingUpdate
          .fold((f) => f, (_) => throw StateError('expected left'))
          .should
          .beOfType<cat.NotFoundFailure>();

      (await skus.delete(id: 's2').run()).isRight().should.beTrue();
      final delMissing = await skus.delete(id: 's2').run();
      delMissing
          .fold((f) => f, (_) => throw StateError('expected left'))
          .should
          .beOfType<cat.NotFoundFailure>();
    });

    test('SKU repo: clearAll empties the store', () async {
      await skus
          .create(
            sku: dacalMachineSku(
              meta: const cat.Meta(id: 'a', notes: '', createdAt: '', updatedAt: ''),
              modelNumber: 'A',
            ),
          )
          .run();
      await skus.clearAll().run();
      final all = await skus.fetchAll().run();
      all.fold(_unexpectedLeft, (list) => list).isEmpty.should.beTrue();
    });

    test('Trait repo: round-trips the canonical hid trait', () async {
      (await traits.create(trait: kDcHidTrait).run()).isRight().should.beTrue();

      final all = await traits.fetchAll().run();
      all.fold(_unexpectedLeft, (list) => list)
          .single
          .meta
          .id
          .should
          .be('dc:trait:hid');

      final byId = await traits.fetchById(id: 'dc:trait:hid').run();
      byId.fold(_unexpectedLeft, (t) => t).name.should.be('hid');
    });

    test('TraitAttributeDefinition repo: filters by trait', () async {
      (await attributes.create(attribute: kDcSerialNumberTraitAttribute).run())
          .isRight()
          .should
          .beTrue();

      final byTrait =
          await attributes.fetchByTrait(traitId: 'dc:trait:serializable').run();
      byTrait
          .fold(_unexpectedLeft, (list) => list)
          .single
          .key
          .should
          .be('serial_number');

      final otherTrait =
          await attributes.fetchByTrait(traitId: 'dc:trait:hid').run();
      otherTrait
          .fold(_unexpectedLeft, (list) => list)
          .isEmpty
          .should
          .beTrue();
    });

    test('Instance repo: full lifecycle', () async {
      final instance = machineInstance(
        meta: const cat.Meta(id: 'dc:instance:67808', notes: '', createdAt: '', updatedAt: ''),
        skuId: 'dc:sku:machine:dc300',
        name: 'UPSTAIRS LIBRARY',
        serialNumber: '67808',
        locateId: 'locate:main',
      );

      (await instances.create(instance: instance).run()).isRight().should.beTrue();
      (await instances.fetchById(id: 'dc:instance:67808').run())
          .fold(_unexpectedLeft, (i) => i)
          .serialNumber
          .should
          .be('67808');

      final byLocate =
          await instances.fetchByLocate(locateId: 'locate:main').run();
      byLocate
          .fold(_unexpectedLeft, (list) => list)
          .single
          .name
          .should
          .be('UPSTAIRS LIBRARY');

      final missingLocate =
          await instances.fetchByLocate(locateId: 'locate:none').run();
      missingLocate
          .fold(_unexpectedLeft, (list) => list)
          .isEmpty
          .should
          .beTrue();

      (await instances.delete(id: 'dc:instance:67808').run()).isRight().should.beTrue();
      (await instances.fetchAll().run())
          .fold(_unexpectedLeft, (list) => list)
          .isEmpty
          .should
          .beTrue();
    });
  });
}
