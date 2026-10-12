import 'package:fpdart/fpdart.dart';

import 'dacal_failure.dart';
import 'dacal_transport.dart';

/// Reads complete response frames from a [DacalTransport].
///
/// Responses are framed with a two-byte little-endian length prefix followed
/// by that many payload bytes; a single `read` may return a partial frame or
/// several, so this assembles frames from the byte stream.
class DacalFrameReader {
  /// The transport to read from.
  final DacalTransport transport;

  /// Bytes buffered across reads waiting for the payload to complete.
  final List<int> _buffer = [];

  /// Creates a frame reader over [transport].
  DacalFrameReader(this.transport);

  /// Reads one complete frame, waiting up to [timeout] for payload bytes.
  ///
  /// Returns [DacalConnectionError] when the transport is closed mid-frame.
  Future<Either<DacalFailure, List<int>>> readFrame({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    // Ensure the two length bytes are present.
    while (_buffer.length < 2) {
      final more = await _readSome(timeout);
      if (more == null) return Left(DacalConnectionError('Read timed out'));
      _buffer.addAll(more);
    }

    final length = _buffer[0] | (_buffer[1] << 8);

    while (_buffer.length < length) {
      final more = await _readSome(timeout);
      if (more == null) return Left(DacalConnectionError('Read timed out'));
      _buffer.addAll(more);
    }

    final frame = _buffer.sublist(0, length);
    _buffer.removeRange(0, length);
    return Right(frame);
  }

  Future<List<int>?> _readSome(Duration timeout) async {
    final data = await transport.read(255, timeout: timeout);
    return data.isEmpty ? null : data;
  }
}
