import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

/// The contract suite every `ILibraryRepository` adapter must pass.
///
/// This is the shared suite the bible's at-least-two-repository-adapters rule
/// demands: run it against the in-memory test double and against the
/// sembast-backed adapter so we know both honor the same contract. A new
/// adapter is conformant the moment it passes here.
///
/// [build] must return a fresh, empty repository for each test.
void sharedRepositoryContractSuite({
  required String name,
  required Future<ILibraryRepository> Function() build,
}) {
  Meta meta(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  Device device(String id, {String serial = '67808', int capacity = 150}) =>
      Device(
        meta: meta(id),
        serialCode: serial,
        skuId: 'decal-150',
        capacity: capacity,
      );

  Disc disc(String id) => Disc(meta: meta(id), skuId: 'cd-sku-1');

  /// Seeds a device plus empty slots 1..count into [r].
  Future<void> seedDevice(ILibraryRepository r, String id, int count) async {
    await r.saveDevice(device: device(id)).run();
    for (var n = 1; n <= count; n++) {
      await r
          .updateSlot(
            slot: Slot(meta: meta('$id-slot-$n'), deviceId: id, slotNumber: n),
          )
          .run();
    }
  }

  group('$name (shared repository contract)', () {
    late ILibraryRepository repo;

    setUp(() async {
      repo = await build();
    });

    test(
      'Then saveDevice persists a device and fetchDevices returns it',
      () async {
        final saved = await repo.saveDevice(device: device('dev-a')).run();
        saved.isRight().should.be(true);

        final all = await repo.fetchDevices().run();
        all.isRight().should.be(true);
        all
            .getOrElse((_) => fail('expected Right'))
            .map((d) => d.meta.id)
            .should
            .be(['dev-a']);
      },
    );

    test(
      'Then devices persist their full record across a save+fetch',
      () async {
        await repo
            .saveDevice(
              device: Device(
                meta: meta('dev-full'),
                serialCode: '9999',
                skuId: 'decal-300',
                capacity: 300,
                name: 'Rack 1',
              ),
            )
            .run();

        final fetched = await repo.fetchDeviceById(id: 'dev-full').run();
        final d = fetched.getOrElse((_) => fail('expected Right'));
        d.serialCode.should.be('9999');
        d.skuId.should.be('decal-300');
        d.capacity.should.be(300);
        d.name.should.be('Rack 1');
      },
    );

    test(
      'Then fetchDeviceBySerialCode finds the device by serial code',
      () async {
        await repo.saveDevice(device: device('dev-a', serial: '111')).run();
        await repo.saveDevice(device: device('dev-b', serial: '222')).run();

        final result = await repo
            .fetchDeviceBySerialCode(serialCode: '222')
            .run();
        result
            .getOrElse((_) => fail('expected Right'))
            .meta
            .id
            .should
            .be('dev-b');
      },
    );

    test(
      'Then fetchDeviceBySerialCode fails NotFound for an unknown code',
      () async {
        final result = await repo
            .fetchDeviceBySerialCode(serialCode: 'ghost')
            .run();
        result.isLeft().should.be(true);
        result
            .fold((f) => f, (_) => fail('expected Left'))
            .should
            .beAssignableTo<NotFoundFailure>();
      },
    );

    test('Then fetchDeviceById fails NotFound for an unknown id', () async {
      final result = await repo.fetchDeviceById(id: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });

    test('Then saveDevice over an existing id overwrites (upsert)', () async {
      await repo
          .saveDevice(
            device: Device(
              meta: meta('dev-a'),
              serialCode: '111',
              skuId: 'decal-150',
              capacity: 150,
            ),
          )
          .run();
      final updated = await repo
          .saveDevice(
            device: Device(
              meta: meta('dev-a'),
              serialCode: '111',
              skuId: 'decal-150',
              capacity: 300,
              name: 'expanded',
            ),
          )
          .run();
      updated.isRight().should.be(true);

      final fetched = await repo.fetchDeviceById(id: 'dev-a').run();
      final d = fetched.getOrElse((_) => fail('expected Right'));
      d.capacity.should.be(300);
      d.name.should.be('expanded');
    });

    test(
      'Then listSlots returns the device slots in slot-number order',
      () async {
        await seedDevice(repo, 'dev-a', 3);
        final result = await repo.listSlots(deviceId: 'dev-a').run();
        result.isRight().should.be(true);
        result
            .getOrElse((_) => fail('expected Right'))
            .map((s) => s.slotNumber)
            .should
            .be([1, 2, 3]);
      },
    );

    test('Then listSlots fails NotFound when the device is absent', () async {
      final result = await repo.listSlots(deviceId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });

    test('Then fetchSlot retrieves a slot by device and slot number', () async {
      await seedDevice(repo, 'dev-a', 2);
      final result = await repo
          .fetchSlot(deviceId: 'dev-a', slotNumber: 2)
          .run();
      result.isRight().should.be(true);
      final slot = result.getOrElse((_) => fail('expected Right'));
      slot.deviceId.should.be('dev-a');
      slot.slotNumber.should.be(2);
      slot.isEmpty.should.be(true);
    });

    test('Then fetchSlot fails NotFound for an unknown slot', () async {
      await seedDevice(repo, 'dev-a', 1);
      final result = await repo
          .fetchSlot(deviceId: 'dev-a', slotNumber: 99)
          .run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });

    test('Then updateSlot persists a disc so a later fetch sees it', () async {
      await seedDevice(repo, 'dev-a', 2);

      final result = await repo
          .updateSlot(
            slot: Slot(
              meta: meta('dev-a-slot-2'),
              deviceId: 'dev-a',
              slotNumber: 2,
              disc: disc('d1'),
            ),
          )
          .run();
      result.isRight().should.be(true);

      final fetched = await repo
          .fetchSlot(deviceId: 'dev-a', slotNumber: 2)
          .run();
      final slot = fetched.getOrElse((_) => fail('expected Right'));
      slot.isOccupied.should.be(true);
      slot.disc?.meta.id.should.be('d1');
    });

    test(
      'Then updateSlot can empty a slot and updateSlot can replace',
      () async {
        await seedDevice(repo, 'dev-a', 2);
        final slotMeta = meta('dev-a-slot-1');

        await repo
            .updateSlot(
              slot: Slot(
                meta: slotMeta,
                deviceId: 'dev-a',
                slotNumber: 1,
                disc: disc('d1'),
              ),
            )
            .run();
        var fetched = await repo
            .fetchSlot(deviceId: 'dev-a', slotNumber: 1)
            .run();
        fetched
            .getOrElse((_) => fail('expected Right'))
            .isOccupied
            .should
            .be(true);

        // Replace disc d1 with d2 in the same slot.
        await repo
            .updateSlot(
              slot: Slot(
                meta: slotMeta,
                deviceId: 'dev-a',
                slotNumber: 1,
                disc: disc('d2'),
              ),
            )
            .run();
        fetched = await repo.fetchSlot(deviceId: 'dev-a', slotNumber: 1).run();
        final s = fetched.getOrElse((_) => fail('expected Right'));
        s.disc?.meta.id.should.be('d2');

        // Empty it.
        await repo.updateSlot(slot: s.empty()).run();
        fetched = await repo.fetchSlot(deviceId: 'dev-a', slotNumber: 1).run();
        fetched
            .getOrElse((_) => fail('expected Right'))
            .isEmpty
            .should
            .be(true);
      },
    );

    test('Then locateDisc finds the slot holding the disc', () async {
      await seedDevice(repo, 'dev-a', 3);
      await repo
          .updateSlot(
            slot: Slot(
              meta: meta('dev-a-slot-3'),
              deviceId: 'dev-a',
              slotNumber: 3,
              disc: disc('d1'),
            ),
          )
          .run();

      final result = await repo.locateDisc(discId: 'd1').run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right'))?.slotNumber.should.be(3);
    });

    test('Then locateDisc returns null when the disc is not placed', () async {
      await seedDevice(repo, 'dev-a', 1);
      final result = await repo.locateDisc(discId: 'ghost').run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right')).should.beNull();
    });

    test('Then saveDisc catalogues a disc and fetchDisc returns it', () async {
      final saved = await repo
          .saveDisc(disc: Disc(meta: meta('disc-a'), skuId: 'cd-sku-1'))
          .run();
      saved.isRight().should.be(true);

      final fetched = await repo.fetchDisc(discId: 'disc-a').run();
      fetched
          .getOrElse((_) => fail('expected Right'))
          .skuId
          .should
          .be('cd-sku-1');
    });

    test('Then saveDisc over an existing id updates the disc (upsert)', () async {
      await repo
          .saveDisc(disc: Disc(meta: meta('disc-a'), skuId: 'cd-sku-1'))
          .run();
      await repo
          .saveDisc(
            disc: Disc(
              meta: meta('disc-a'),
              skuId: 'cd-sku-2',
              label: 'A',
              serialNumber: 'SN-1',
            ),
          )
          .run();

      final d = (await repo.fetchDisc(discId: 'disc-a').run())
          .getOrElse((_) => fail('expected Right'));
      d.skuId.should.be('cd-sku-2');
      d.label.should.be('A');
      d.serialNumber.should.be('SN-1');
    });

    test('Then fetchDisc fails NotFound for an unknown disc', () async {
      final result = await repo.fetchDisc(discId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });

    test('Then listDiscs returns the catalogue in sku-id order', () async {
      await repo
          .saveDisc(disc: Disc(meta: meta('disc-b'), skuId: 'cd-sku-9'))
          .run();
      await repo
          .saveDisc(disc: Disc(meta: meta('disc-a'), skuId: 'cd-sku-1'))
          .run();

      final result = await repo.listDiscs().run();
      result
          .getOrElse((_) => fail('expected Right'))
          .map((d) => d.meta.id)
          .should
          .be(['disc-a', 'disc-b']);
    });

    test('Then deleteDisc removes a catalogue disc', () async {
      await repo
          .saveDisc(disc: Disc(meta: meta('disc-a'), skuId: 'cd-sku-1'))
          .run();
      final result = await repo.deleteDisc(discId: 'disc-a').run();
      result.isRight().should.be(true);

      (await repo.fetchDisc(discId: 'disc-a').run()).isLeft().should.be(true);
    });

    test('Then deleteDisc fails NotFound for an unknown disc', () async {
      final result = await repo.deleteDisc(discId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });
}
