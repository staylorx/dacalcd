import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/cli/cli.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';
import 'support/device_factory.dart';
import 'support/memory_library_repository.dart';

/// A capturing line writer for asserting CLI output without touching stdout.
class _Capture {
  final List<String> lines = [];
  void add(String line) => lines.add(line);
  String get joined => lines.join('\n');
}

/// Builds a CLI over an in-memory repository, optionally seeding it, with an
/// optional fake carousel.
DecalCli _cli({
  MemoryLibraryRepository? repo,
  DacalClient? carousel,
  _Capture? out,
  _Capture? err,
}) {
  final repository = repo ?? MemoryLibraryRepository();
  return DecalCli(
    DecalCliDeps(
      library: repository,
      carousel: carousel,
      out: (out ?? _Capture()).add,
      err: (err ?? _Capture()).add,
    ),
  );
}

Meta _meta(String id) => Meta(
  id: id,
  notes: '',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
);

Device _device(String id) => buildDevice(id, capacity: 3);

/// Seeds a device plus empty slots 1..n.
Future<MemoryLibraryRepository> _seed() async {
  final repo = MemoryLibraryRepository();
  await repo.saveDevice(device: _device('dev-a')).run();
  for (var n = 1; n <= 3; n++) {
    await repo
        .updateSlot(
          slot: Slot(
            meta: _meta('dev-a-slot-$n'),
            deviceId: 'dev-a',
            slotNumber: n,
          ),
        )
        .run();
  }
  return repo;
}

DacalClient _ackCarousel() {
  final transport = FakeDacalTransport()..queueReads([ackFrame(), ackFrame()]);
  return DacalClient(transport);
}

void main() {
  group('DecalCli command parsing', () {
    test('`devices` lists seeded devices', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), out: out);
      final code = await cli.run(['devices']);
      code.should.be(0);
      out.joined.should.contain('67808');
      out.joined.should.contain('manufacturer Dacal');
      out.joined.should.contain('sku DC-300');
      out.joined.should.contain('model CD Library II');
      out.joined.should.contain('capacity 3');
    });

    test('`device-info <serial>` shows machine details', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), out: out);
      final code = await cli.run(['device-info', '67808']);
      code.should.be(0);
      out.joined.should.contain('Device 67808');
      out.joined.should.contain('manufacturer: Dacal');
      out.joined.should.contain('sku:          DC-300');
      out.joined.should.contain('model:        CD Library II');
      out.joined.should.contain('serial:       67808');
      out.joined.should.contain('capacity:     3');
    });

    test('`device-info` with unknown serial reports an error', () async {
      final err = _Capture();
      final cli = _cli(repo: await _seed(), err: err);
      final code = await cli.run(['device-info', 'nope']);
      code.should.be(1);
      err.joined.should.contain('error');
    });

    test('`device-info <id>` shows machine details by opaque id', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), out: out);
      final code = await cli.run(['device-info', 'dev-a']);
      code.should.be(0);
      out.joined.should.contain('Device 67808');
      out.joined.should.contain('id:           dev-a');
    });

    test('`device-add` registers a new machine and `devices` lists it', () async {
      final repo = await _seed();
      final out = _Capture();
      final cli = _cli(repo: repo, out: out);
      final code = await cli.run(
        ['device-add', 'Dacal', 'DC-600', 'CD Library III', '9999', '600', 'Rack 2'],
      );
      code.should.be(0);
      out.joined.should.contain('Registered machine 9999');

      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['devices']);
      out2.joined.should.contain('9999');
      out2.joined.should.contain('model CD Library III');
    });

    test('`device-add` refuses a duplicate serial', () async {
      final err = _Capture();
      final cli = _cli(repo: await _seed(), err: err);
      final code = await cli.run(
        ['device-add', 'Dacal', 'DC-300', 'CD Library II', '67808', '150'],
      );
      code.should.be(1);
      err.joined.should.contain('already registered');
    });

    test('`device-update` changes a machine by serial', () async {
      final repo = await _seed();
      final out = _Capture();
      final cli = _cli(repo: repo, out: out);
      final code = await cli.run(
        ['device-update', '67808', '--capacity=300', '--name=Big Rack'],
      );
      code.should.be(0);
      out.joined.should.contain('Updated machine 67808');

      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['device-info', 'dev-a']);
      out2.joined.should.contain('capacity:     300');
      out2.joined.should.contain('name:         Big Rack');
    });

    test('`device-remove` deletes a machine by serial', () async {
      final repo = await _seed();
      final out = _Capture();
      final cli = _cli(repo: repo, out: out);
      final code = await cli.run(['device-remove', '67808']);
      code.should.be(0);
      out.joined.should.contain('Removed machine 67808');

      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['devices']);
      out2.joined.should.contain('No devices.');
    });

    test('`slots <device-id>` lists slots', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), out: out);
      final code = await cli.run(['slots', 'dev-a']);
      code.should.be(0);
      out.joined.should.contain('1: empty');
      out.joined.should.contain('3: empty');
    });

    test('`insert` places a disc and `slots` shows it', () async {
      final out = _Capture();
      final repo = await _seed();
      final cli = _cli(repo: repo, out: out);

      final insertCode = await cli.run(['insert', 'dev-a', '2', 'cd-sku-9']);
      insertCode.should.be(0);
      out.joined.should.contain('Inserted disc cd-sku-9 into dev-a slot 2');

      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['slots', 'dev-a']);
      out2.joined.should.contain('2: cd-sku-9');
    });

    test('`insert` refuses a slot that already holds a disc', () async {
      final err = _Capture();
      final repo = await _seed();
      final cli = _cli(repo: repo, err: err);
      await cli.run(['insert', 'dev-a', '1', 'cd-1']);
      await cli.run(['insert', 'dev-a', '1', 'cd-2']);
      final code = await cli.run(['insert', 'dev-a', '1', 'cd-3']);
      code.should.be(1);
      err.joined.should.contain('already holds');
    });

    test('`insert` with a non-integer slot reports a parse error', () async {
      final err = _Capture();
      final cli = _cli(repo: await _seed(), err: err);
      final code = await cli.run(['insert', 'dev-a', 'two', 'cd-sku']);
      code.should.be(1);
      err.joined.should.contain('invalid slot');
    });

    test('`remove` empties a slot', () async {
      final out = _Capture();
      final repo = await _seed();
      final cli = _cli(repo: repo, out: out);
      await cli.run(['insert', 'dev-a', '1', 'cd-x']);
      final code = await cli.run(['remove', 'dev-a', '1']);
      code.should.be(0);
      out.joined.should.contain('Emptied dev-a slot 1');

      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['slots', 'dev-a']);
      out2.joined.should.contain('1: empty');
    });

    test('`locate <disc-id>` finds the slot holding the disc', () async {
      final repo = await _seed();
      final cli = _cli(repo: repo);
      await cli.run(['insert', 'dev-a', '3', 'cd-zz']);

      // Discover the disc id that insert minted.
      final out2 = _Capture();
      final cli2 = _cli(repo: repo, out: out2);
      await cli2.run(['slots', 'dev-a']);
      final line = out2.lines.firstWhere((l) => l.contains('cd-zz'));
      final discId = RegExp(r'disc id ([^)\s]+)').firstMatch(line)!.group(1)!;

      final out3 = _Capture();
      final cli3 = _cli(repo: repo, out: out3);
      final code = await cli3.run(['locate', discId]);
      code.should.be(0);
      out3.joined.should.contain('slot 3');
    });

    test('`locate` for a disc in no slot reports not found', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), out: out);
      final code = await cli.run(['locate', 'ghost-disc']);
      code.should.be(0);
      out.joined.should.contain('not in any slot');
    });

    test('`carousel <slot>` moves to slot via the serial layer', () async {
      final out = _Capture();
      final cli = _cli(repo: await _seed(), carousel: _ackCarousel(), out: out);
      final code = await cli.run(['carousel', '5']);
      code.should.be(0);
      out.joined.should.contain('carousel moved to slot 5');
    });

    test('`carousel` without a wired device reports it', () async {
      final err = _Capture();
      final cli = _cli(repo: await _seed(), err: err);
      final code = await cli.run(['carousel', '5']);
      code.should.be(1);
      err.joined.should.contain('No carousel is wired');
    });

    test('an unknown command surfaces a usage error', () async {
      final err = _Capture();
      final cli = _cli(repo: await _seed(), err: err);
      final code = await cli.run(['bogus']);
      code.should.be(1);
      err.joined.should.contain('Could not find a command');
    });

    test('`--help` exits 0 and prints usage', () async {
      final cli = _cli(repo: await _seed());
      var code = 0;
      await expectLater(() async {
        code = await cli.run(['--help']);
      }, prints(contains('Manage the Dacal CD carousel library')));
      code.should.be(0);
    });
  });
}
