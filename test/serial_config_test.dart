import 'dart:io';

import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/config/config.dart';
import 'package:test/test.dart';

void main() {
  group('SerialConfig', () {
    test('round-trips through JSON', () {
      const config = SerialConfig(portName: 'COM7', baudRate: 115200);
      final json = config.toJson();
      final restored = SerialConfig.fromJson(json);
      expect(restored, equals(config));
    });

    test('defaults baud rate to 9600 when absent', () {
      final restored = SerialConfig.fromJson({'port_name': 'COM3'});
      expect(restored.portName, 'COM3');
      expect(restored.baudRate, 9600);
    });
  });

  group('SerialConfigFileStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('serial_config_test');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    String path(String name) =>
        '${dir.path}${Platform.pathSeparator}$name.json';

    test('load returns null when the file does not exist', () async {
      final store = SerialConfigFileStore(path('missing'));
      final result = await store.load().run();
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), isNull);
    });

    test('save then load round-trips the config', () async {
      final store = SerialConfigFileStore(path('config'));
      const config = SerialConfig(portName: 'COM5', baudRate: 19200);

      final saved = await store.save(config).run();
      expect(saved.isRight(), isTrue);

      final loaded = await store.load().run();
      expect(loaded.isRight(), isTrue);
      expect(loaded.getRight().toNullable(), equals(config));
    });

    test('re-opening the same file restores the persisted value', () async {
      final first = SerialConfigFileStore(path('config'));
      await first.save(const SerialConfig(portName: 'COM9')).run();

      // A fresh store over the same file sees the saved config — this is the
      // "persists across app restarts" behaviour the app depends on.
      final second = SerialConfigFileStore(path('config'));
      final loaded = await second.load().run();
      expect(loaded.isRight(), isTrue);
      expect(loaded.getRight().toNullable()?.portName, 'COM9');
    });
  });
}
