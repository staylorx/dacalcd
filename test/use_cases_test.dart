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
        serialCode: serial,
        skuId: 'decal-150',
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
      d.serialCode.should.be('67808');
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
}
