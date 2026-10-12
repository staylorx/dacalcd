import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';

void main() {
  group('Given a DacalFrameReader', () {
    group('When a complete frame arrives in one read', () {
      test('Then it returns the whole frame once', () async {
        final transport = FakeDacalTransport();
        final reader = DacalFrameReader(transport);
        transport.queueReads([ackFrame()]);

        final first = await reader.readFrame();
        first.isRight().should.be(true);
        first.getOrElse((_) => fail('Right')).should.be(ackFrame());
      });
    });

    group('When a frame arrives split across reads', () {
      test('Then it reassembles from the buffer', () async {
        final transport = FakeDacalTransport();
        final reader = DacalFrameReader(transport);
        final frame = ackFrame();
        // Split the 8-byte frame into two reads.
        transport.queueReads([frame.sublist(0, 5), frame.sublist(5)]);

        final result = await reader.readFrame();
        result.isRight().should.be(true);
        result.getOrElse((_) => fail('Right')).should.be(frame);
      });
    });

    group('When the transport returns nothing', () {
      test('Then it reports a connection error', () async {
        final transport = FakeDacalTransport();
        final reader = DacalFrameReader(transport);
        transport.queueReads([const []]);

        final result = await reader.readFrame(
            timeout: const Duration(milliseconds: 50));
        result.isLeft().should.be(true);
        result
            .fold((f) => f, (_) => fail('Left'))
            .should
            .beOfType<DacalConnectionError>();
      });
    });
  });
}
