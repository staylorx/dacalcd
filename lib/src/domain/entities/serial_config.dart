import 'package:equatable/equatable.dart';

/// The saved serial connection settings for a Decal CD carousel.
///
/// Holds the COM port name and baud rate — the two values a user selects in
/// the app — alongside the fixed framing the Dacal protocol expects (8 data
/// bits / no parity / one stop bit, matching [DacalSerialSettings]).
///
/// It is a plain value object: no behaviour and no storage. Reading and
/// writing it to persistent storage is done through an [ISerialConfigStore].
class SerialConfig extends Equatable {
  /// The Windows COM port name, for example `COM3` or `COM7`.
  final String portName;

  /// The baud rate, for example 9600. Not meaningful to a USB control-transfer
  /// device, but required by the serial API and persisted so the connection is
  /// reproducible across restarts.
  final int baudRate;

  /// Creates a [SerialConfig].
  const SerialConfig({required this.portName, this.baudRate = 9600});

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    'port_name': portName,
    'baud_rate': baudRate,
  };

  /// Parses a [SerialConfig] from snake_case JSON, falling back to defaults
  /// when a field is missing.
  factory SerialConfig.fromJson(Map<String, dynamic> json) => SerialConfig(
    portName: json['port_name'] as String? ?? '',
    baudRate: json['baud_rate'] is int
        ? json['baud_rate'] as int
        : int.tryParse(json['baud_rate']?.toString() ?? '') ?? 9600,
  );

  @override
  List<Object?> get props => [portName, baudRate];
}
