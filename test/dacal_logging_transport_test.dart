import 'dart:io';
import 'dart:math';

import 'package:decalcd/decalcd.dart';
import 'package:path/path.dart' as p;
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';

void main() {
  group('Given a DacalLoggingTransport', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dacal_capture_${Random().nextInt(1 << 32)}');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    group('When bytes are written and read', () {
      test('Then it logs TX and RX lines', () async {
        final inner = FakeDacalTransport()..queueReads([ackFrame()]);
        final logger = DacalLoggingTransport(inner, directory: dir.path);
        await logger.open();
        await logger.write([0x11]);
        await logger.read(8);
        await logger.close();

        final lines = File(p.join(dir.path, 'dacal_traffic.log'))
            .readAsLinesSync()
            .where((l) => l.isNotEmpty)
            .toList();
        lines.should.haveCount(4);
        lines[0].should.contain('OPEN');
        lines[1].should.contain('TX 11');
        lines[2].should.contain('RX 08 00 41 00 43 00 4b 00');
        lines[3].should.contain('CLOSE');
      });
    });
  });
}
