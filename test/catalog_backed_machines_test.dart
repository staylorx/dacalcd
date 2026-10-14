import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/data/data.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;
import 'package:test/test.dart';

import 'support/device_factory.dart';

/// Each test gets its own in-memory database (the memory factory reuses an open
/// database by name, which would otherwise leak rows).
var _dbSeq = 0;

Future<Database> _openDb() => databaseFactoryMemory.openDatabase(
  'catalog-backed-${_dbSeq++}',
  version: librarySchemaVersion,
  onVersionChanged: libraryMigrations,
);

void main() {
  late Database db;
  late SembastTransactionScope scope;
  late SembastLibraryRepository repo;
  late SembastSkuRepository skus;
  late SembastInstanceRepository instances;
  late SembastMachineConfigRepository configs;

  setUp(() async {
    db = await _openDb();
    scope = SembastTransactionScope();
    repo = SembastLibraryRepository(database: db, scope: scope);
    skus = SembastSkuRepository(database: db, scope: scope);
    instances = SembastInstanceRepository(database: db, scope: scope);
    configs = SembastMachineConfigRepository(database: db, scope: scope);
  });

  tearDown(() => db.close());

  group('Given a machine saved through the library repository', () {
    test('Then it is stored as a catalog Sku + Instance, not a private blob',
        () async {
      final device = buildDevice(
        'dev-1',
        serial: '67808',
        capacity: 150,
        serialConfig: const SerialConfig(portName: 'COM7', baudRate: 9600),
      );
      await repo.saveDevice(device: device).run();

      // The machine SKU is a first-class catalog record.
      final sku = (await skus.fetchById(id: device.machineSku!.meta.id).run())
          .getOrElse((f) => fail('expected Right: $f'));
      sku.modelNumber.should.be('DC-300');
      sku.traitIds.should.contain(kDcSerializableTrait.meta.id);
      (sku.attributeValues['capacity'] as int).should.be(150);

      // The physical unit is a catalog Instance linking to that SKU.
      final inst = (await instances.fetchById(id: 'dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      inst.skuId.should.be(device.machineSku!.meta.id);
      inst.serialNumber.should.be('67808');

      // Connection config lives in the sidecar, keyed by the instance id.
      final cfg = (await configs.fetch('dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      cfg.serialConfig?.portName.should.be('COM7');

      // The retired `devices` blob store is no longer written.
      (await deviceStore.find(db)).length.should.be(0);
    });

    test('Then fetchDevice reassembles identity + config from those stores',
        () async {
      final device = buildDevice(
        'dev-1',
        serial: '67808',
        capacity: 300,
        serialConfig: const SerialConfig(portName: 'COM7'),
        demoMode: true,
      );
      await repo.saveDevice(device: device).run();

      final back = (await repo.fetchDeviceById(id: 'dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      back.manufacturer.should.be('Dacal');
      back.sku.should.be('DC-300');
      back.model.should.be('CD Library II');
      back.capacity.should.be(300);
      back.serialNumber.should.be('67808');
      back.serialConfig?.portName.should.be('COM7');
      back.demoMode.should.be(true);
    });

    test('Then a machine written only via the catalog repositories is visible',
        () async {
      // Write a machine the catalog way — SKU + instance, no library-repo call.
      final machineSku = buildDevice('dev-x').machineSku!;
      await skus.create(sku: machineSku).run();
      await instances
          .create(
            instance: cat.Instance(
              meta: catMeta('dev-x'),
              skuId: machineSku.meta.id,
              locateId: null,
              name: 'Main Rack',
              serialNumber: '4242',
            ),
          )
          .run();

      final all = (await repo.fetchDevices().run())
          .getOrElse((f) => fail('expected Right: $f'));
      all.map((d) => d.meta.id).should.be(['dev-x']);
      all.single.serialNumber.should.be('4242');
      all.single.sku.should.be('DC-300');
    });

    test('Then deleting a machine clears its instance and sidecar config',
        () async {
      await repo
          .saveDevice(
            device: buildDevice('dev-1', serialConfig: const SerialConfig(portName: 'COM7')),
          )
          .run();
      await repo.deleteDevice(id: 'dev-1').run();

      (await instances.fetchById(id: 'dev-1').run()).isLeft().should.be(true);
      (await configs.fetch('dev-1').run()).isLeft().should.be(true);
    });
  });

  group('Given the v2 migration', () {
    test('Then legacy device rows are split onto the catalog + sidecar stores',
        () async {
      // Seed a legacy blob exactly as the v1 schema stored it.
      final legacy = buildDevice(
        'dev-1',
        serial: '67808',
        capacity: 150,
        serialConfig: const SerialConfig(portName: 'COM9'),
      );
      await deviceStore.record('dev-1').put(db, legacy.toJson());

      // Run the upgrade a v1 database would perform on open.
      await libraryMigrations(db, 1, 2);

      (await deviceStore.find(db)).length.should.be(0);

      final inst = (await instances.fetchById(id: 'dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      inst.serialNumber.should.be('67808');

      final sku = (await skus.fetchById(id: legacy.machineSku!.meta.id).run())
          .getOrElse((f) => fail('expected Right: $f'));
      sku.modelNumber.should.be('DC-300');

      final cfg = (await configs.fetch('dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      cfg.serialConfig?.portName.should.be('COM9');

      // The repository now serves the migrated machine end to end.
      final device = (await repo.fetchDeviceById(id: 'dev-1').run())
          .getOrElse((f) => fail('expected Right: $f'));
      device.manufacturer.should.be('Dacal');
      device.capacity.should.be(150);
      device.serialConfig?.portName.should.be('COM9');
    });
  });
}
