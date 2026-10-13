import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'support/device_factory.dart';
import 'support/memory_backends.dart';

void main() {
  late MemoryLibraryRepository repo;

  setUp(() {
    repo = MemoryLibraryRepository();
  });

  Meta meta(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  Device machine(String id, {String? serial, SerialConfig? config}) =>
      buildDevice(
        id,
        serial: serial ?? 'm-$id',
        serialConfig: config,
      );

  group('migrateLegacySerialConfig', () {
    test(
      'applies a legacy port to the first machine without a config',
      () async {
        await repo.saveDevice(device: machine('dev-1')).run();
        await repo.saveDevice(device: machine('dev-2')).run();

        final migrated = await migrateLegacySerialConfig(
          repository: repo,
          legacyPort: 'COM4',
        );
        migrated.should.not.beNull();
        migrated!.meta.id.should.be('dev-1');
        migrated.serialConfig?.portName.should.be('COM4');
        migrated.serialConfig?.baudRate.should.be(DacalSerialSettings.baudRate);

        final saved = await repo.fetchDevices().run();
        final devices = saved.getOrElse((_) => fail('expected Right'));
        devices
            .firstWhere((d) => d.meta.id == 'dev-1')
            .serialConfig
            ?.portName
            .should
            .be('COM4');
        devices
            .firstWhere((d) => d.meta.id == 'dev-2')
            .serialConfig
            .should
            .beNull();
      },
    );

    test('is a no-op when every machine already has its own config', () async {
      await repo
          .saveDevice(
            device: machine(
              'dev-1',
              config: const SerialConfig(portName: 'COM9'),
            ),
          )
          .run();

      final migrated = await migrateLegacySerialConfig(
        repository: repo,
        legacyPort: 'COM4',
      );
      migrated.should.beNull();

      final saved = await repo.fetchDevices().run();
      final devices = saved.getOrElse((_) => fail('expected Right'));
      devices.single.serialConfig?.portName.should.be('COM9');
    });

    test('is a no-op with no machines', () async {
      final migrated = await migrateLegacySerialConfig(
        repository: repo,
        legacyPort: 'COM4',
      );
      migrated.should.beNull();
    });

    test('is a no-op for a blank legacy port', () async {
      await repo.saveDevice(device: machine('dev-1')).run();

      final migrated = await migrateLegacySerialConfig(
        repository: repo,
        legacyPort: '  ',
      );
      migrated.should.beNull();
    });
  });
}
