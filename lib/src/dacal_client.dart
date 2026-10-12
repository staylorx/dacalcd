import 'package:fpdart/fpdart.dart';

import 'command.dart';
import 'dacal_codec.dart';
import 'dacal_failure.dart';
import 'dacal_frame_reader.dart';
import 'dacal_response.dart';
import 'dacal_transport.dart';

/// A high-level client for commanding a Dacal CD carousel over a
/// [DacalTransport].
///
/// The client owns the open/close lifecycle, encodes commands, reads and
/// assembles response frames, decodes them, and surfaces device errors as
/// [DacalFailure] values. Transport selection (real serial port, capture
/// wrapper, or in-memory fake) is injected via the constructor, keeping this
/// class pure and testable without hardware.
class DacalClient {
  /// The byte transport carrying commands to, and responses from, the device.
  final DacalTransport transport;

  late final DacalFrameReader _reader;

  /// Whether [open] has succeeded and [close] has not yet been called.
  bool _open = false;

  /// Creates a client over [transport].
  DacalClient(this.transport) {
    _reader = DacalFrameReader(transport);
  }

  /// True once [open] has succeeded and before [close].
  bool get isOpen => _open && transport.isOpen;

  /// Opens the transport.
  ///
  /// Returns [DacalConnectionError] when the underlying port cannot be opened.
  Future<Either<DacalFailure, void>> open() async {
    final err = await transport.open();
    if (err != null) return Left(DacalConnectionError(err));
    _open = true;
    return const Right(null);
  }

  /// Closes the transport and releases the port.
  Future<void> close() async {
    await transport.close();
    _open = false;
  }

  /// Sends a single [DacalCommand] and returns its parsed response.
  Future<Either<DacalFailure, DacalResponse>> send(DacalCommand command) =>
      _roundTrip([...DacalCodec.encode(command)], command.name);

  /// Moves the carousel to get the disc in [slot] (1..150).
  ///
  /// A move is the two-step retract-then-target sequence the firmware
  /// expects, matching the reference USB library behaviour.
  Future<Either<DacalFailure, DacalResponse>> moveToSlot(int slot) async {
    if (slot < 1 || slot > 150) {
      return Left(DacalProtocolError('Slot $slot out of range (1..150)'));
    }
    await _roundTrip([...DacalCodec.encode(DacalCommand.retract)], 'retract');
    return _roundTrip(
      [
        DacalCodec.encode(DacalCommand.moveTo).first,
        DacalCodec.encodeSlot(slot).first,
      ],
      'moveTo($slot)',
    );
  }

  /// Retracts the pickup arm / closes the drive, releasing the currently
  /// slotted disc so it can be removed from the reader.
  ///
  /// This is the complement to [moveToSlot]: it is the "unslot" half of the
  /// slot/unslot cycle (the firmware expects a retract before a move, and a
  /// retract on its own withdraws an already-present disc).
  Future<Either<DacalFailure, DacalResponse>> retract() =>
      send(DacalCommand.retract);

  /// Queries the current device status.
  Future<Either<DacalFailure, DacalResponse>> getStatus() =>
      send(DacalCommand.getStatus);

  /// Resets the carousel.
  Future<Either<DacalFailure, DacalResponse>> reset() =>
      send(DacalCommand.reset);

  /// Turns the on-body LED position display on or off.
  Future<Either<DacalFailure, DacalResponse>> setLed(bool on) =>
      send(on ? DacalCommand.ledOn : DacalCommand.ledOff);

  Future<Either<DacalFailure, DacalResponse>> _roundTrip(
      List<int> bytes, String command) async {
    final result = await _run(command, () async {
      await transport.write(bytes);
      final frame = await _reader.readFrame();
      return frame.flatMap(DacalCodec.decode).flatMap(
          (response) => DacalCodec.requireOk(response, command));
    });
    return result;
  }

  Future<Either<DacalFailure, DacalResponse>> _run(
      String command, Future<Either<DacalFailure, DacalResponse>> Function() op) {
    // This adapter-boundary exception→value conversion must use the sanctioned
    // TaskEither.tryCatch (bible compact rule), not a hand-rolled try/catch.
    // op() returns Either on the success path but can still throw (the
    // transport precondition probe); tryCatch turns that throw into a
    // DacalConnectionError, and the inner Either is flattened back out.
    final roundTrip =
        TaskEither<DacalFailure, Either<DacalFailure, DacalResponse>>.tryCatch(
      op,
      (Object error, StackTrace stackTrace) =>
          DacalConnectionError('$command failed: $error'),
    );
    return roundTrip
        .flatMap((either) =>
            TaskEither<DacalFailure, DacalResponse>.fromEither(either))
        .run();
  }
}
