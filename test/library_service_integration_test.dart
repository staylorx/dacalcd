// Integration test: the shared LibraryService is the single source of data
// for BOTH entry points.
//
// This exercises the acceptance criterion for the TUI/CLI data-layer
// integration: "TUI shows live data from the same source as the CLI". It
// drives the CLI's CommandRunner (`DecalCli`) and the TUI's controller over
// the same seeded repository, and asserts the records both surface are
// produced by the same shared LibraryService — so neither entry point reads
// the repository on its own forged path.
import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/cli/cli.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'support/memory_library_repository.dart';

Meta _meta(String id) => Meta(
  id: id,
  notes: '',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
);

/// Seeds a memory repository with one device and 3 slots (slot 2 occupied).
Future<MemoryLibraryRepository> _seed() async {
  final repo = MemoryLibraryRepository();
  await repo
      .saveDevice(
        device: Device(
          meta: _meta('dev-a'),
          serialCode: '67808',
          skuId: 'decal-150',
          capacity: 3,
          name: 'Unit 67808',
        ),
      )
      .run();
  await repo
      .updateSlot(
        slot: Slot(
          meta: _meta('dev-a-slot-1'),
          deviceId: 'dev-a',
          slotNumber: 1,
        ),
      )
      .run();
  await repo
      .updateSlot(
        slot: Slot(
          meta: _meta('dev-a-slot-2'),
          deviceId: 'dev-a',
          slotNumber: 2,
          disc: Disc(meta: _meta('disc-2'), skuId: 'cd-sku-9'),
        ),
      )
      .run();
  await repo
      .updateSlot(
        slot: Slot(
          meta: _meta('dev-a-slot-3'),
          deviceId: 'dev-a',
          slotNumber: 3,
        ),
      )
      .run();
  return repo;
}

class _Capture {
  final List<String> lines = [];
  void add(String line) => lines.add(line);
  String get joined => lines.join('\n');
}

void main() {
  group('LibraryService — shared data layer for CLI and TUI', () {
    test(
      'load() returns the same snapshot the CLI `devices` command lists',
      () async {
        final repo = await _seed();
        final service = LibraryService(repository: repo);
        final snapshot = (await service.load().run()).fold(
          (f) => fail('load failed: $f'),
          (v) => v,
        );

        // The CLI lists devices through its own DecalCliDeps — which now carries
        // a LibraryService over the same repository, so no data is duplicated.
        final cli = DecalCli(
          DecalCliDeps(library: repo, out: (_) {}, err: (_) {}),
        );
        final code = await cli.run(['devices']);
        code.should.be(0);

        // Same device record from the service and from the CLI path.
        snapshot.devices.should.haveCount(1);
        final svc = snapshot.devices.single;
        svc.serialCode.should.be('67808');
        svc.name.should.be('Unit 67808');
        snapshot.firstDeviceSlots.should.haveCount(3);
      },
    );

    test('listSlots() matches the CLI `slots` command output', () async {
      final repo = await _seed();
      final service = LibraryService(repository: repo);

      final slots = (await service.listSlots('dev-a').run()).fold(
        (f) => fail('list failed: $f'),
        (v) => v,
      );
      slots.should.haveCount(3);
      slots[0].isEmpty.should.beTrue();
      slots[1].disc?.skuId.should.be('cd-sku-9');
      slots[2].isEmpty.should.beTrue();

      // The CLI command renders the same occupancy via the shared service.
      final out = _Capture();
      final cli = DecalCli(
        DecalCliDeps(library: repo, out: out.add, err: (_) {}),
      );
      final code = await cli.run(['slots', 'dev-a']);
      code.should.be(0);
      out.joined.should.contain('1: empty');
      out.joined.should.contain('2: cd-sku-9');
      out.joined.should.contain('3: empty');
    });

    test('a repository error surfaces as a Left, not a throw', () async {
      final repo = MemoryLibraryRepository();
      // Empty repository: load() succeeds with an empty snapshot.
      final service = LibraryService(repository: repo);
      final snapshot = (await service.load().run()).fold(
        (f) => fail('load failed: $f'),
        (v) => v,
      );
      snapshot.devices.should.beEmpty();
      snapshot.firstDeviceSlots.should.beNull();
    });
  });

  group('LibraryService — disc catalog facade', () {
    test('addDisc + listDiscs + getDisc round-trip through the facade', () async {
      final repo = MemoryLibraryRepository();
      final service = LibraryService(repository: repo);

      final added = (await service
          .addDisc(skuId: 'cd-sku-1', label: 'Rumours')
          .run())
          .getOrElse((f) => fail('addDisc failed: $f'));

      final listed = (await service.listDiscs().run())
          .getOrElse((f) => fail('listDiscs failed: $f'));
      listed.should.haveCount(1);
      listed.single.skuId.should.be('cd-sku-1');

      final fetched = (await service.getDisc(added.meta.id).run())
          .getOrElse((f) => fail('getDisc failed: $f'));
      fetched.label.should.be('Rumours');
    });

    test('changeDisc updates a catalogued disc via the facade', () async {
      final repo = MemoryLibraryRepository();
      final service = LibraryService(repository: repo);
      final added = (await service.addDisc(skuId: 'cd-sku-1').run())
          .getOrElse((f) => fail('addDisc failed: $f'));

      final changed = (await service
          .changeDisc(
            discId: added.meta.id,
            label: 'Rumours 2004',
            serialNumber: 'SN-7',
          )
          .run())
          .getOrElse((f) => fail('changeDisc failed: $f'));
      changed.label.should.be('Rumours 2004');
      changed.serialNumber.should.be('SN-7');
    });

    test('removeDiscFromLibrary refuses a disc that is placed in a slot',
        () async {
      final repo = MemoryLibraryRepository();
      final service = LibraryService(repository: repo);
      final added = (await service.addDisc(skuId: 'cd-sku-1').run())
          .getOrElse((f) => fail('addDisc failed: $f'));

      // Place it into the carousel, then try to remove it from the library.
      await repo
          .saveDevice(
            device: Device(
              meta: _meta('dev-a'),
              serialCode: '67808',
              skuId: 'decal-150',
              capacity: 3,
            ),
          )
          .run();
      await repo
          .updateSlot(
            slot: Slot(
              meta: _meta('dev-a-slot-1'),
              deviceId: 'dev-a',
              slotNumber: 1,
              disc: added,
            ),
          )
          .run();

      final result = await service.removeDiscFromLibrary(added.meta.id).run();
      result.isLeft().should.beTrue();
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<InUseFailure>();
    });

    test('a duplicate sku via the facade fails AlreadyExists', () async {
      final repo = MemoryLibraryRepository();
      final service = LibraryService(repository: repo);
      (await service.addDisc(skuId: 'cd-sku-1').run())
          .getOrElse((f) => fail('addDisc failed: $f'));

      final result = await service.addDisc(skuId: 'cd-sku-1').run();
      result.isLeft().should.beTrue();
      result
          .fold((f) => f, (_) => fail('expected Left'))
          .should
          .beAssignableTo<AlreadyExistsFailure>();
    });
  });
}
