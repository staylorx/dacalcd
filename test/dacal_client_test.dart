import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';

void main() {
  group('Given a DacalClient', () {
    group('When sending getStatus to an ACK device', () {
      test('Then it returns status ok', () async {
        final transport = FakeDacalTransport()..queueReads([ackFrame()]);
        final client = DacalClient(transport);
        await client.open();

        final result = await client.getStatus();
        result.isRight().should.be(true);
        result.getOrElse((_) => fail('Right')).status.should.be(DacalStatus.ok);
      });
    });

    group('When the device returns BUSY', () {
      test('Then it surfaces a device error', () async {
        final transport = FakeDacalTransport()..queueReads([busyFrame()]);
        final client = DacalClient(transport);
        await client.open();

        final result = await client.getStatus();
        result.isLeft().should.be(true);
        final failure = result.fold((f) => f, (_) => fail('Left'));
        failure.should.beOfType<DacalDeviceError>();
        (failure as DacalDeviceError).status.should.be('BUSY');
      });
    });

    group('When moving to a valid slot', () {
      test('Then it retracts then sends move-to and slot', () async {
        final transport = FakeDacalTransport()
          ..queueReads([ackFrame(), ackFrame()]);
        final client = DacalClient(transport);
        await client.open();

        final result = await client.moveToSlot(7);
        result.isRight().should.be(true);

        // Two writes: [retract] then [moveTo, 7].
        transport.written.should.haveCount(2);
        transport.written[0].should.be([0x0e]);
        transport.written[1].should.be([0x0c, 0x07]);
      });
    });

    group('When moving to an out-of-range slot', () {
      test('Then it returns a protocol error without writing', () async {
        final transport = FakeDacalTransport();
        final client = DacalClient(transport);
        await client.open();

        final result = await client.moveToSlot(0);
        result.isLeft().should.be(true);
        result
            .fold((f) => f, (_) => fail('Left'))
            .should
            .beOfType<DacalProtocolError>();
        transport.written.should.haveCount(0);
      });
    });

    group('When the transport cannot open', () {
      test('Then it returns a connection error', () async {
        final transport = FakeDacalTransport()..failOpen = true;
        final client = DacalClient(transport);

        final result = await client.open();
        result.isLeft().should.be(true);
        result
            .fold((f) => f, (_) => fail('Left'))
            .should
            .beOfType<DacalConnectionError>();
      });
    });

    group('When retracting (unslot)', () {
      test('Then it sends the retract opcode and returns ok', () async {
        final transport = FakeDacalTransport()..queueReads([ackFrame()]);
        final client = DacalClient(transport);
        await client.open();

        final result = await client.retract();
        result.isRight().should.be(true);
        result
            .getOrElse((_) => fail('Right'))
            .status
            .should
            .be(DacalStatus.ok);
        // A single retract write, no slot byte.
        transport.written.should.haveCount(1);
        transport.written[0].should.be([0x0e]);
      });
    });

    group('When toggling the LED', () {
      test('Then it sends the on/off opcodes', () async {
        final transport = FakeDacalTransport()
          ..queueReads([ackFrame(), ackFrame()]);
        final client = DacalClient(transport);
        await client.open();

        await client.setLed(true);
        await client.setLed(false);

        transport.written.should.haveCount(2);
        transport.written[0].should.be([0x0f]);
        transport.written[1].should.be([0x10]);
      });
    });
  });
}
