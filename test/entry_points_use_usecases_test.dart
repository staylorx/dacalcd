// Integration test: the outer rings act only through the use cases.
//
// The rule this locks: every action an outer ring performs — the GUI, the TUI,
// the CLI — is a use case over the shared repository. There is no parallel
// service surface above the use-case layer for a ring to act through, so two
// rings wired over the same repository cannot drift: they are running the same
// use cases. This drives the CLI's CommandRunner (`DecalCli`) and a
// use-case-driven ring (what a GUI/TUI list view would call) over one seeded
// repository and asserts the records agree.
import 'package:decalcd/src/cli/cli.dart';
import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'support/device_factory.dart';
import 'support/disc_factory.dart';
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
        device: buildDevice(
          'dev-a',
          capacity: 3,
          serial: '67808',
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
          disc: buildDisc('disc-2', skuId: 'cd-sku-9'),
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
  group('Given the outer rings wired over one repository', () {
    test('Then a list-view ring and the CLI see the same devices', () async {
      final repo = await _seed();

      // The list view's ring: the use case a GUI/TUI would call.
      final snapshot = (await LoadLibrarySnapshot(repo).call().run())
          .getOrElse((f) => fail('snapshot failed: $f'));
      snapshot.devices.should.haveCount(1);
      snapshot.devices.single.serialNumber.should.be('67808');
      snapshot.firstDeviceSlots.should.haveCount(3);

      // The CLI's ring: its `devices` command over the same repository.
      final out = _Capture();
      final cli = DecalCli(
        DecalCliDeps(library: repo, out: out.add, err: (_) {}),
      );
      (await cli.run(['devices'])).should.be(0);
      out.joined.should.contain('67808');
      out.joined.should.contain('Dacal');

      // Both ran the same use case, so the records are identical.
      final viaUseCase = (await ListDevices(repo).call().run())
          .getOrElse((f) => fail('listDevices failed: $f'));
      viaUseCase.single.meta.id.should.be(snapshot.devices.single.meta.id);
    });

    test('Then the CLI slots output matches ListSlotsForDevice', () async {
      final repo = await _seed();

      final slots = (await ListSlotsForDevice(repo).call(deviceId: 'dev-a').run())
          .getOrElse((f) => fail('list failed: $f'));
      slots.should.haveCount(3);
      slots[0].isEmpty.should.beTrue();
      slots[1].disc?.skuId.should.be('cd-sku-9');
      slots[2].isEmpty.should.beTrue();

      final out = _Capture();
      final cli = DecalCli(
        DecalCliDeps(library: repo, out: out.add, err: (_) {}),
      );
      (await cli.run(['slots', 'dev-a'])).should.be(0);
      out.joined.should.contain('1: empty');
      out.joined.should.contain('2: cd-sku-9');
      out.joined.should.contain('3: empty');
    });

    test('Then an empty library yields an empty snapshot, not an error',
        () async {
      final snapshot = (await LoadLibrarySnapshot(MemoryLibraryRepository()).call().run())
          .getOrElse((f) => fail('snapshot failed: $f'));
      snapshot.devices.should.beEmpty();
      snapshot.firstDeviceSlots.should.beNull();
    });
  });
}
