import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'support/memory_backends.dart';

void main() {
  Meta meta(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  Device device(String id, {String serial = '67808', int capacity = 150}) =>
      Device(
        meta: meta(id),
        manufacturer: 'Dacal',
        sku: 'DC-300',
        model: 'CD Library II',
        serialNumber: serial,
        capacity: capacity,
      );

  Disc disc(String id, {String skuId = 'cd-sku-1'}) =>
      Disc(meta: meta(id), skuId: skuId);

  /// Seeds a device plus empty slots 1..count into [r].
  void seedDevice(MemoryLibraryRepository r, String id, int count) {
    final dev = device(id);
    r.saveDevice(device: dev).run();
    for (var n = 1; n <= count; n++) {
      r
          .updateSlot(
            slot: Slot(meta: meta('$id-slot-$n'), deviceId: id, slotNumber: n),
          )
          .run();
    }
  }

  late MemoryLibraryRepository repo;

  InsertDisc insertDisc(MemoryLibraryRepository r) => InsertDisc(repository: r);

  setUp(() {
    repo = MemoryLibraryRepository();
  });

  group('Given the list devices use case', () {
    test('Then it returns every saved device', () async {
      seedDevice(repo, 'dev-a', 1);
      seedDevice(repo, 'dev-b', 1);

      final result = await ListDevices(repo)().run();
      result.isRight().should.be(true);
      final devices = result.getOrElse((_) => fail('expected Right'));
      devices.map((d) => d.meta.id).should.be(['dev-a', 'dev-b']);
    });
  });

  group('Given the get device by serial code use case', () {
    test('Then it finds the device with that serial code', () async {
      seedDevice(repo, 'dev-1', 1);
      final result = await GetDeviceBySerialCode(repo)(
        serialCode: '67808',
      ).run();
      result.isRight().should.be(true);
      final d = result.getOrElse((_) => fail('expected Right'));
      d.meta.id.should.be('dev-1');
      d.serialNumber.should.be('67808');
    });

    test('Then it returns a failure for an unknown serial code', () async {
      final result = await GetDeviceBySerialCode(repo)(
        serialCode: 'nope',
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given the list slots for a device use case', () {
    test('Then it returns slots in slot-number order', () async {
      seedDevice(repo, 'dev-1', 3);
      final result = await ListSlotsForDevice(repo)(deviceId: 'dev-1').run();
      result.isRight().should.be(true);
      final slots = result.getOrElse((_) => fail('expected Right'));
      slots.map((s) => s.slotNumber).should.be([1, 2, 3]);
    });

    test('Then it fails when the device does not exist', () async {
      final result = await ListSlotsForDevice(repo)(deviceId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given the get slot status use case', () {
    test('Then it reports an occupied slot with its disc', () async {
      seedDevice(repo, 'dev-1', 2);
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 2,
      ).run();

      final result = await GetSlotStatus(repo)(
        deviceId: 'dev-1',
        slotNumber: 2,
      ).run();
      result.isRight().should.be(true);
      final slot = result.getOrElse((_) => fail('expected Right'));
      slot.isOccupied.should.be(true);
      slot.disc?.meta.id.should.be('d1');
    });

    test('Then it reports an empty slot', () async {
      seedDevice(repo, 'dev-1', 1);
      final result = await GetSlotStatus(repo)(
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      final slot = result.getOrElse((_) => fail('expected Right'));
      slot.isEmpty.should.be(true);
    });

    test('Then it fails for a slot that does not exist', () async {
      seedDevice(repo, 'dev-1', 1);
      final result = await GetSlotStatus(repo)(
        deviceId: 'dev-1',
        slotNumber: 99,
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given the insert disc use case', () {
    test('Then it places the disc into an empty slot', () async {
      seedDevice(repo, 'dev-1', 2);
      final result = await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 2,
      ).run();
      result.isRight().should.be(true);
      final slot = result.getOrElse((_) => fail('expected Right'));
      slot.slotNumber.should.be(2);
      slot.disc?.meta.id.should.be('d1');

      final locate = await LocateDisc(repo)(discId: 'd1').run();
      locate.getOrElse((_) => fail('expected Right'))?.slotNumber.should.be(2);
    });

    test('Then it refuses an occupied slot', () async {
      seedDevice(repo, 'dev-1', 2);
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      final result = await insertDisc(repo)(
        disc: disc('d2'),
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<InUseFailure>();
    });

    test('Then moving a disc clears its previous slot', () async {
      seedDevice(repo, 'dev-1', 3);
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 3,
      ).run();

      final slot1 = await GetSlotStatus(repo)(
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      slot1.getOrElse((_) => fail('expected Right')).isEmpty.should.be(true);

      final slot3 = await GetSlotStatus(repo)(
        deviceId: 'dev-1',
        slotNumber: 3,
      ).run();
      slot3
          .getOrElse((_) => fail('expected Right'))
          .disc
          ?.meta
          .id
          .should
          .be('d1');
    });
  });

  group('Given the remove disc use case', () {
    test('Then it empties an occupied slot', () async {
      seedDevice(repo, 'dev-1', 1);
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();

      final result = await RemoveDisc(repo)(
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right')).isEmpty.should.be(true);
    });

    test('Then it fails when the slot is already empty', () async {
      seedDevice(repo, 'dev-1', 1);
      final result = await RemoveDisc(repo)(
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<InvalidInputFailure>();
    });
  });

  group('Given the locate disc use case', () {
    test('Then it returns the slot holding the disc', () async {
      seedDevice(repo, 'dev-1', 2);
      await insertDisc(repo)(
        disc: disc('d1'),
        deviceId: 'dev-1',
        slotNumber: 2,
      ).run();

      final result = await LocateDisc(repo)(discId: 'd1').run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right'))?.slotNumber.should.be(2);
    });

    test('Then it returns null when the disc is not placed', () async {
      seedDevice(repo, 'dev-1', 1);
      final result = await LocateDisc(repo)(discId: 'ghost').run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right')).should.beNull();
    });
  });

  group('Given the add disc to library use case', () {
    AddDiscToLibrary addDisc(String id) =>
        AddDiscToLibrary(repository: repo, idGenerator: () => id);

    test('Then it catalogues a new disc with a minted id', () async {
      final result = await addDisc('disc-1')
          .call(
            skuId: 'cd-sku-1',
            label: 'Fleetwood Mac',
            serialNumber: 'SN-7',
          )
          .run();
      result.isRight().should.be(true);
      final d = result.getOrElse((_) => fail('expected Right'));
      d.meta.id.should.be('disc-1');
      d.skuId.should.be('cd-sku-1');
      d.label.should.be('Fleetwood Mac');
      d.serialNumber.should.be('SN-7');

      final listed = await ListDiscs(repo)().run();
      listed
          .getOrElse((_) => fail('expected Right'))
          .map((x) => x.meta.id)
          .should
          .be(['disc-1']);
    });

    test('Then it refuses a duplicate sku', () async {
      await addDisc('disc-1').call(skuId: 'cd-sku-1').run();
      final result = await addDisc('disc-2').call(skuId: 'cd-sku-1').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<AlreadyExistsFailure>();
    });

    test('Then it refuses a blank sku id', () async {
      final result = await addDisc('disc-1').call(skuId: '   ').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<InvalidInputFailure>();
    });
  });

  group('Given the get disc use case', () {
    test('Then it fetches a catalogued disc', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1')
          .run();
      final result = await GetDisc(repo)(discId: 'disc-1').run();
      result
          .getOrElse((_) => fail('expected Right'))
          .skuId
          .should
          .be('cd-sku-1');
    });

    test('Then it fails NotFound for an unknown disc', () async {
      final result = await GetDisc(repo)(discId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given the list discs use case', () {
    test('Then it is empty for a fresh library', () async {
      final result = await ListDiscs(repo)().run();
      result.getOrElse((_) => fail('expected Right')).should.beEmpty();
    });

    test('Then it lists every catalogued disc in sku order', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'd-b')
          .call(skuId: 'cd-sku-9')
          .run();
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'd-a')
          .call(skuId: 'cd-sku-1')
          .run();
      final result = await ListDiscs(repo)().run();
      result
          .getOrElse((_) => fail('expected Right'))
          .map((d) => d.meta.id)
          .should
          .be(['d-a', 'd-b']);
    });
  });

  group('Given the remove disc from library use case', () {
    test('Then it removes a disc that is not placed', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1')
          .run();
      final result = await RemoveDiscFromLibrary(repo)(discId: 'disc-1').run();
      result.isRight().should.be(true);
      result.getOrElse((_) => fail('expected Right')).meta.id.should.be('disc-1');
      (await GetDisc(repo)(discId: 'disc-1').run()).isLeft().should.be(true);
    });

    test('Then it refuses when the disc is in a carousel slot', () async {
      seedDevice(repo, 'dev-1', 2);
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1')
          .run();
      await insertDisc(repo)(
        disc: disc('disc-1'),
        deviceId: 'dev-1',
        slotNumber: 1,
      ).run();

      final result = await RemoveDiscFromLibrary(repo)(discId: 'disc-1').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<InUseFailure>();
    });

    test('Then it fails NotFound for an unknown disc', () async {
      final result = await RemoveDiscFromLibrary(repo)(discId: 'ghost').run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given the change disc in library use case', () {
    test('Then it changes the label and serial number', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1', label: 'Old')
          .run();
      final result = await ChangeDiscInLibrary(repository: repo).call(
        discId: 'disc-1',
        label: 'New',
        serialNumber: 'SN-9',
      ).run();
      result.isRight().should.be(true);
      final changed = result.getOrElse((_) => fail('expected Right'));
      changed.label.should.be('New');
      changed.serialNumber.should.be('SN-9');

      final fetched = await GetDisc(repo)(discId: 'disc-1').run();
      fetched.getOrElse((_) => fail('expected Right')).label.should.be('New');
    });

    test('Then leaves untouched fields unchanged', () async {
      await AddDiscToLibrary(
        repository: repo,
        idGenerator: () => 'disc-1',
      ).call(skuId: 'cd-sku-1', label: 'Keep').run();
      final result = await ChangeDiscInLibrary(repository: repo).call(
        discId: 'disc-1',
        serialNumber: 'SN-X',
      ).run();
      final changed = result.getOrElse((_) => fail('expected Right'));
      changed.skuId.should.be('cd-sku-1');
      changed.label.should.be('Keep');
      changed.serialNumber.should.be('SN-X');
    });

    test('Then it refuses a sku already used by another disc', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1')
          .run();
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-2')
          .call(skuId: 'cd-sku-2')
          .run();

      final result = await ChangeDiscInLibrary(repository: repo).call(
        discId: 'disc-1',
        skuId: 'cd-sku-2',
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<AlreadyExistsFailure>();
    });

    test('Then it refreshes updatedAt', () async {
      await AddDiscToLibrary(repository: repo, idGenerator: () => 'disc-1')
          .call(skuId: 'cd-sku-1')
          .run();
      final before = (await GetDisc(repo)(discId: 'disc-1').run())
          .getOrElse((_) => fail('expected Right'));

      // A fixed clock makes the refreshed timestamp deterministic.
      final changedAt = DateTime.utc(2026, 2, 1, 8, 30, 0);
      await ChangeDiscInLibrary(
        repository: repo,
        clock: () => changedAt,
      ).call(discId: 'disc-1', label: 'X').run();
      final after = (await GetDisc(repo)(discId: 'disc-1').run())
          .getOrElse((_) => fail('expected Right'));
      after.meta.updatedAt.should.not.be(before.meta.updatedAt);
      after.meta.updatedAt.should.be('2026-02-01T08:30:00.000Z');
    });

    test('Then it fails NotFound for an unknown disc', () async {
      final result = await ChangeDiscInLibrary(repository: repo).call(
        discId: 'ghost',
        label: 'X',
      ).run();
      result.isLeft().should.be(true);
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<NotFoundFailure>();
    });
  });

  group('Given library + machine integration', () {
    test(
      'Then add to library, insert to machine, change, remove from machine, '
      'then remove from library all compose',
      () async {
        seedDevice(repo, 'dev-1', 3);

        // Catalog a disc, then place it in slot 2.
        final added = (await AddDiscToLibrary(
          repository: repo,
          idGenerator: () => 'disc-1',
        ).call(skuId: 'cd-sku-1', label: 'Rumours').run())
            .getOrElse((_) => fail('expected Right'));
        final placed = await insertDisc(repo)(
          disc: added,
          deviceId: 'dev-1',
          slotNumber: 2,
        ).run();
        placed.isRight().should.be(true);

        // Change the catalogue label — the slot's inline copy follows.
        await ChangeDiscInLibrary(repository: repo).call(
          discId: 'disc-1',
          label: 'Rumours 2004',
        ).run();
        final slot2 = (await GetSlotStatus(repo)(
          deviceId: 'dev-1',
          slotNumber: 2,
        ).run())
            .getOrElse((_) => fail('expected Right'));
        slot2.disc?.label.should.be('Rumours 2004');

        // Locate it, remove it from the machine, then from the library.
        (await LocateDisc(repo)(discId: 'disc-1').run())
            .getOrElse((_) => fail('expected Right'))
            ?.slotNumber
            .should
            .be(2);
        await RemoveDisc(repo)(deviceId: 'dev-1', slotNumber: 2).run();
        final removed = await RemoveDiscFromLibrary(repo)(discId: 'disc-1').run();
        removed.isRight().should.be(true);
        (await ListDiscs(repo)().run())
            .getOrElse((_) => fail('expected Right'))
            .should
            .beEmpty();
      },
    );
  });
}
