import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import 'command.dart';
import 'dacal_failure.dart';
import 'dacal_response.dart';

/// Encodes and decodes the Dacal carousel wire protocol.
///
/// Command bytes are single opcodes (see [DacalCommand]); the two-byte
/// move-to-slot operation is two consecutive control writes — the opcode
/// `moveTo`, then the slot number byte. Responses are framed as a two-byte
/// little-endian length followed by a UTF-16LE status token (`ACK`, `BUSY`,
/// `SOS` or `ERROR`) and optional payload.
abstract final class DacalCodec {
  /// Encodes a [DacalCommand] (without a slot argument) to its wire bytes.
  static List<int> encode(DacalCommand command) => [command.code];

  /// Encodes the raw slot argument that follows `moveTo` on the wire.
  ///
  /// Slots are 1-based; the firmware accepts 1..150.
  static List<int> encodeSlot(int slot) => [slot & 0xff];

  /// Decodes a response frame into a [DacalResponse].
  ///
  /// Returns [DacalProtocolError] when the frame is too short to carry a
  /// status token, or when the length prefix disagrees with the frame.
  static Either<DacalFailure, DacalResponse> decode(List<int> frame) {
    if (frame.length < 4) {
      return Left(DacalProtocolError(
          'Frame too short (${frame.length} bytes) to hold a status token'));
    }

    final length = frame[0] | (frame[1] << 8);
    if (length > frame.length) {
      return Left(DacalProtocolError(
          'Length prefix $length exceeds frame of ${frame.length} bytes'));
    }

    final tokenBytes = _utf16leSlice(frame, 2, frame.length);
    final token = utf8.decode(tokenBytes).toUpperCase();
    final data = <int>[];

    return Right(DacalResponse(
      length: length,
      data: data,
      status: DacalStatus.fromToken(token),
    ));
  }

  /// Interprets a single status truth, mapping device errors (non-ACK) to a
  /// [DacalDeviceError] failure.
  static Either<DacalFailure, DacalResponse> requireOk(
      DacalResponse response, String command) {
    if (response.status == DacalStatus.ok) {
      return Right(response);
    }
    return Left(DacalDeviceError(
      status: response.status.token,
      command: command,
    ));
  }

  static List<int> _utf16leSlice(List<int> bytes, int start, int end) {
    final raw = Uint8List.fromList(bytes.sublist(start, end));
    // Decode UTF-16LE into code units, then re-encode as UTF-8 for string use.
    return utf8.encode(String.fromCharCodes(raw.buffer.asUint16List()));
  }
}
