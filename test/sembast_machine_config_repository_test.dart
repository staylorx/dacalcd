import 'package:decalcd/src/data/data.dart';
import 'package:decalcd/src/domain/domain.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

var _dbSeq = 0;

Future<Database> openDb() => databaseFactoryMemory.openDatabase(
  'decalcd-sidecar-test-${_dbSeq++}',
);

Never _unexpectedLeft(DecalFailure f) =>
    throw StateError('expected right, got left: $f');

void main() {
  group('SembastMachineConfigRepository (config sidecar)', () {
    late Database db;
    late SembastTransactionScope scope;
    late SembastMachineConfigRepository repo;

    setUp(() async {
      db = await openDb();
      scope = SembastTransactionScope();
      repo = SembastMachineConfigRepository(database: db, scope: scope);
    });

    tearDown(() => db.close());

    test('fetch on empty -> NotFoundFailure', () async {
      final r = await repo.fetch('dc:instance:67808').run();
      r.isLeft().should.beTrue();
      r.fold((f) => f, (_) => throw StateError('expected left'))
          .should
          .beOfType<NotFoundFailure>();
    });

    test('save then fetch round-trips hid + serial + demoMode', () async {
      final config = MachineConfig(
        instanceId: 'dc:instance:67808',
        demoMode: false,
        hidConfig: HidConfig.dacal,
        serialConfig: const SerialConfig(portName: 'COM3', baudRate: 9600),
      );

      final saved = await repo.save(config).run();
      saved.fold(_unexpectedLeft, (c) => c).instanceId.should.be('dc:instance:67808');

      final fetched = await repo.fetch('dc:instance:67808').run();
      final got = fetched.fold(_unexpectedLeft, (c) => c);
      got.hidConfig!.vid.should.be(0x04b4);
      got.serialConfig!.portName.should.be('COM3');

      (await repo.exists('dc:instance:67808').run())
          .fold(_unexpectedLeft, (b) => b)
          .should
          .beTrue();
      (await repo.exists('dc:instance:nope').run())
          .fold(_unexpectedLeft, (b) => b)
          .should
          .beFalse();
    });

    test('save upserts by key (no duplicate)', () async {
      await repo
          .save(
            MachineConfig(
              instanceId: 'i1',
              serialConfig: const SerialConfig(portName: 'COM1'),
            ),
          )
          .run();
      await repo
          .save(
            MachineConfig(
              instanceId: 'i1',
              hidConfig: HidConfig.dacal,
            ),
          )
          .run();

      final all = await repo.fetchAll().run();
      all.fold(_unexpectedLeft, (list) => list).length.should.be(1);
      all
          .fold(_unexpectedLeft, (list) => list)
          .single
          .hidConfig
          .should
          .not
          .beNull();
    });

    test('delete removes the config', () async {
      await repo
          .save(
            MachineConfig(
              instanceId: 'i1',
              demoMode: true,
            ),
          )
          .run();
      (await repo.delete('i1').run()).isRight().should.beTrue();
      (await repo.exists('i1').run())
          .fold(_unexpectedLeft, (b) => b)
          .should
          .beFalse();
    });
  });
}
