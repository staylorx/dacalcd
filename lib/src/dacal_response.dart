import 'package:equatable/equatable.dart';

/// The device's high-level status as reported over the wire.
enum DacalStatus {
  /// Command accepted and completed.
  ok('ACK'),

  /// The spindle is busy; retry later.
  busy('BUSY'),

  /// Device fault condition; reset is required.
  sos('SOS'),

  /// The device returned a status we do not recognise.
  unknown('UNKNOWN');

  /// The status token as the firmware spells it.
  final String token;

  const DacalStatus(this.token);

  /// Maps a decoded status string to the matching enum value.
  static DacalStatus fromToken(String token) {
    switch (token.toUpperCase()) {
      case 'ACK':
        return DacalStatus.ok;
      case 'BUSY':
        return DacalStatus.busy;
      case 'SOS':
        return DacalStatus.sos;
      default:
        return DacalStatus.unknown;
    }
  }
}

/// A parsed response frame from the Dacal carousel.
class DacalResponse extends Equatable {
  /// Total payload length in bytes (header excluded).
  final int length;

  /// Optional raw data bytes carried after the status token, if any.
  final List<int> data;

  /// Normalised device status decoded from the status token.
  final DacalStatus status;

  /// Creates a parsed response frame.
  const DacalResponse({
    required this.length,
    required this.data,
    required this.status,
  });

  @override
  List<Object?> get props => [length, data, status];

  @override
  String toString() =>
      'DacalResponse(length: $length, status: ${status.token})';
}
