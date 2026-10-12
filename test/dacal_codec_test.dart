import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'fake_dacal_transport.dart';

void main() {
  group('Given a DacalCodec', () {
    group('When encoding a command', () {
      test('Then it emits the single opcode byte', () {
        DacalCodec.encode(DacalCommand.getStatus).should.be([0x11]);
        DacalCodec.encode(DacalCommand.moveTo).should.be([0x0c]);
        DacalCodec.encode(DacalCommand.reset).should.be([0x0b]);
      });
    });

    group('When encoding a slot', () {
      test('Then it emits the raw byte', () {
        DacalCodec.encodeSlot(42).should.be([42]);
      });
    });

    group('When decoding an ACK frame', () {
      test('Then it parses status ok and response fields', () {
        final result = DacalCodec.decode(ackFrame());
        result.isRight().should.be(true);
        final response = result.getOrElse((_) => fail('expected Right'));
        response.status.should.be(DacalStatus.ok);
        response.length.should.be(8);
        response.status.token.should.be('ACK');
      });
    });

    group('When decoding BUSY / SOS frames', () {
      test('Then it maps them to busy / sos status', () {
        DacalCodec.decode(busyFrame())
            .getOrElse((_) => fail('Right'))
            .status
            .should
            .be(DacalStatus.busy);
        DacalCodec.decode(sosFrame())
            .getOrElse((_) => fail('Right'))
            .status
            .should
            .be(DacalStatus.sos);
      });
    });

    group('When decoding a truncated frame', () {
      test('Then it returns a protocol failure', () {
        final result = DacalCodec.decode([1, 0]);
        result.isLeft().should.be(true);
        result.fold((f) => f.should.beOfType<DacalProtocolError>(),
            (_) => fail('expected Left'));
      });
    });

    group('When requiring ok on a non-ACK response', () {
      test('Then it returns a device error', () {
        final response =
            DacalCodec.decode(busyFrame()).getOrElse((_) => fail('Right'));
        final result = DacalCodec.requireOk(response, 'getStatus');
        result.isLeft().should.be(true);
        result
            .fold((f) => f,
                (_) => fail('expected Left'))
            .should
            .beOfType<DacalDeviceError>();
      });
    });
  });
}
