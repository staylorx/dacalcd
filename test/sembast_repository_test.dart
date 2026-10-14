import 'package:decalcd/src/data/data.dart';
import 'package:decalcd/decalcd.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import 'support/device_factory.dart';
import 'support/disc_factory.dart';
import 'support/shared_contract_suite.dart';

var _dbSeq = 0;

Future<Database> openDb() => databaseFactoryMemory.openDatabase(
  // A unique name per open gives each test a fresh, isolated store — the
  // memory factory reuses an open database by name, which would otherwise
  // leak rows between contract tests.
  'decalcd-test-${_dbSeq++}',
  version: librarySchemaVersion,
  onVersionChanged: libraryMigrations,
);

void main() {
  // The sembast adapter must honor the exact same contract as the in-memory
  // adapter. Each contract test gets a fresh in-memory database, closed on
  // teardown.
  sharedRepositoryContractSuite(
    name: 'SembastLibraryRepository',
    build: () async {
      final db = await openDb();
      addTearDown(db.close);
      final scope = SembastTransactionScope();
      return SembastLibraryRepository(database: db, scope: scope);
    },
  );

  group('SembastLibraryRepository', () {
    late Database db;
    late SembastTransactionScope scope;
    late SembastLibraryRepository repo;

    Meta meta(String id) => Meta(
      id: id,
      notes: '',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    );

    Future<void> seedDevice(
      String deviceId, {
      int capacity = 3,
      Map<int, Disc>? occupied,
    }) async {
      await repo
          .saveDevice(
            device: buildDevice(
              deviceId,
              serial: deviceId == 'dev-a' ? '67808' : '4444',
              capacity: capacity,
            ),
          )
          .run();
      for (var n = 1; n <= capacity; n++) {
        await repo
            .updateSlot(
              slot: Slot(
                meta: meta('$deviceId-slot-$n'),
                deviceId: deviceId,
                slotNumber: n,
                disc: occupied?[n],
              ),
            )
            .run();
      }
    }

    setUp(() async {
      db = await openDb();
      scope = SembastTransactionScope();
      repo = SembastLibraryRepository(database: db, scope: scope);
    });

    tearDown(() async {
      await db.close();
    });

    group('Given the schema migration', () {
      test(
        'Then openDatabase runs the onVersionChanged migration to v$librarySchemaVersion',
        () async {
          db.version.should.be(librarySchemaVersion);

          final marker = await schemaStore.record('version').get(db);
          marker.should.not.beNull();
          (marker?['version']).should.be(librarySchemaVersion);
        },
      );

      test('Then the v3 step re-points discs and thins the slot rows', () async {
        // A v2 database: a catalogue disc in the blob store, and a slot row
        // that embeds a copy of another disc.
        await discStore
            .record('disc-1')
            .put(db, buildDisc('disc-1', skuId: 'cd-sku-1').toJson());
        final seated = buildDisc('disc-2', skuId: 'cd-sku-9', slotNumber: 2);
        await slotStore.record('dev-a-slot-2').put(db, {
          'id': 'dev-a-slot-2',
          'notes': '',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'device_id': 'dev-a',
          'slot_number': 2,
          'disc': seated.toJson(),
        });

        await libraryMigrations(db, 2, 3);

        // The blob store is retired…
        (await discStore.find(db)).length.should.be(0);
        // …the slot row is layout only…
        final layout = (await slotStore.record('dev-a-slot-2').get(db))!;
        layout.containsKey('disc').should.be(false);
        layout['device_id'].should.be('dev-a');
        layout['slot_number'].should.be(2);
        // …and both discs are catalog instances, the slotted one still placed.
        final placed = (await instanceStore.record('disc-2').get(db))!;
        placed['locate_id'].should.be('dev-a');
        ((placed['attribute_values'] as Map)[kSlotNumberTraitAttributeKey] as int)
            .should
            .be(2);
        (await instanceStore.record('disc-1').get(db))!['locate_id'].should
            .beNull();
      });
    });

    group('Given a disc placed in a slot', () {
      test('Then placement lands on the instance, not on the slot row', () async {
        await seedDevice('dev-a');
        await repo
            .updateSlot(
              slot: Slot(
                meta: meta('dev-a-slot-2'),
                deviceId: 'dev-a',
                slotNumber: 2,
                disc: buildDisc('disc-1', skuId: 'cd-sku-1'),
              ),
            )
            .run();

        // The slot row carries the carousel layout and no disc copy.
        final layout = (await slotStore.record('dev-a-slot-2').get(db))!;
        layout.containsKey('disc').should.be(false);

        // The disc instance carries the placement.
        final placed = (await instanceStore.record('disc-1').get(db))!;
        placed['locate_id'].should.be('dev-a');
        ((placed['attribute_values'] as Map)[kSlotNumberTraitAttributeKey] as int)
            .should
            .be(2);

        // Emptying the slot unplaces it — the disc stays catalogued.
        final empty = await repo.fetchSlot(deviceId: 'dev-a', slotNumber: 2).run();
        await repo.updateSlot(slot: empty.getOrElse((_) => fail('Right')).empty()).run();
        final unplaced = (await instanceStore.record('disc-1').get(db))!;
        unplaced['locate_id'].should.beNull();
        (await repo.fetchDisc(discId: 'disc-1').run()).isRight().should.be(true);
      });
    });

    group('Given a SembastUnitOfWork sharing the repository scope', () {
      test(
        'Then an InsertDisc with a unit of work commits atomically',
        () async {
          await seedDevice('dev-a');
          final uow = SembastUnitOfWork(database: db, scope: scope);
          final insert = InsertDisc(repository: repo, unitOfWork: uow);
          final disc = buildDisc('d1');

          final result = await insert(
            disc: disc,
            deviceId: 'dev-a',
            slotNumber: 2,
          ).run();

          result.isRight().should.be(true);

          final slot2 = await repo
              .fetchSlot(deviceId: 'dev-a', slotNumber: 2)
              .run();
          slot2
              .getOrElse((_) => fail('expected Right'))
              .disc
              ?.meta
              .id
              .should
              .be('d1');
        },
      );

      test('Then a disc move clears the old slot atomically', () async {
        await seedDevice(
          'dev-a',
          occupied: {1: buildDisc('d1')},
        );
        final uow = SembastUnitOfWork(database: db, scope: scope);
        final insert = InsertDisc(repository: repo, unitOfWork: uow);

        final result = await insert(
          disc: buildDisc('d1'),
          deviceId: 'dev-a',
          slotNumber: 3,
        ).run();
        result.isRight().should.be(true);

        // Old slot cleared, new slot filled — both in the same transaction.
        final slot1 = await repo
            .fetchSlot(deviceId: 'dev-a', slotNumber: 1)
            .run();
        slot1.getOrElse((_) => fail('expected Right')).isEmpty.should.be(true);

        final slot3 = await repo
            .fetchSlot(deviceId: 'dev-a', slotNumber: 3)
            .run();
        slot3
            .getOrElse((_) => fail('expected Right'))
            .disc
            ?.meta
            .id
            .should
            .be('d1');
      });

      test(
        'Then a Left rolls the whole transaction back — writes are undone',
        () async {
          await seedDevice('dev-a');

          final uow = SembastUnitOfWork(database: db, scope: scope);
          final failed = await uow.runEither<DecalFailure, void>(
            body: () async {
              // Write a disc into slot 1 within the transaction, then abort.
              await repo
                  .updateSlot(
                    slot: Slot(
                      meta: meta('dev-a-slot-1'),
                      deviceId: 'dev-a',
                      slotNumber: 1,
                      disc: buildDisc('d1'),
                    ),
                  )
                  .run();
              return Either.left(
                const NotFoundFailure('abort this transaction'),
              );
            },
          );

          failed.isLeft().should.be(true);
          failed
              .fold((f) => f, (_) => fail('expected Left'))
              .should
              .beAssignableTo<NotFoundFailure>();

          // The in-transaction write must have been undone: slot 1 is empty.
          final slot1 = await repo
              .fetchSlot(deviceId: 'dev-a', slotNumber: 1)
              .run();
          slot1
              .getOrElse((_) => fail('expected Right'))
              .isEmpty
              .should
              .be(true);
        },
      );

      test('Then a Right commits the transaction', () async {
        await seedDevice('dev-a');

        final uow = SembastUnitOfWork(database: db, scope: scope);
        final result = await uow.runEither<DecalFailure, void>(
          body: () async {
            await repo
                .updateSlot(
                  slot: Slot(
                    meta: meta('dev-a-slot-1'),
                    deviceId: 'dev-a',
                    slotNumber: 1,
                    disc: buildDisc('d1'),
                  ),
                )
                .run();
            return Either.right(null);
          },
        );

        result.isRight().should.be(true);

        final slot1 = await repo
            .fetchSlot(deviceId: 'dev-a', slotNumber: 1)
            .run();
        slot1
            .getOrElse((_) => fail('expected Right'))
            .disc
            ?.meta
            .id
            .should
            .be('d1');
      });
    });
  });
}
