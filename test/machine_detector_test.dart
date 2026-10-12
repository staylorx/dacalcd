import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';

void main() {
  group('Given probeMachine', () {
    group('When the machine answers an ACK', () {
      test('Then it reports the machine as detected', () async {
        final transport = FakeDacalTransport()..queueReads([ackFrame()]);
        final client = DacalClient(transport);

        final result = await probeMachine(client).run();

        result.isRight().should.be(true);
        final probe = result.getOrElse((_) => fail('Right'));
        probe.detected.should.be(true);
        probe.should.beOfType<MachineDetected>();
        (probe as MachineDetected).status.should.be(DacalStatus.ok);
      });
    });

    group('When the machine answers BUSY', () {
      test('Then it still counts the machine as detected', () async {
        final transport = FakeDacalTransport()..queueReads([busyFrame()]);
        final client = DacalClient(transport);

        final result = await probeMachine(client).run();

        result.isRight().should.be(true);
        final probe = result.getOrElse((_) => fail('Right'));
        probe.detected.should.be(true);
        (probe as MachineDetected).status.should.be(DacalStatus.busy);
      });
    });

    group('When the transport cannot open', () {
      test('Then it reports the machine as not detected', () async {
        final transport = FakeDacalTransport()..failOpen = true;
        final client = DacalClient(transport);

        final result = await probeMachine(client).run();

        result.isRight().should.be(true);
        final probe = result.getOrElse((_) => fail('Right'));
        probe.detected.should.be(false);
        probe.should.beOfType<MachineNotDetected>();
      });
    });

    group('probeMachineAvailable', () {
      test('Then it maps a detected probe to true', () async {
        final transport = FakeDacalTransport()..queueReads([ackFrame()]);
        final client = DacalClient(transport);

        final result = await probeMachineAvailable(client).run();
        result.getOrElse((_) => fail('Right')).should.be(true);
      });

      test('Then it maps an absent probe to false', () async {
        final client = DacalClient(FakeDacalTransport());
        final result = await probeMachineAvailable(client).run();
        result.getOrElse((_) => fail('Right')).should.be(false);
      });
    });
  });
}
