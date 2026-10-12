import 'dart:typed_data';

import 'package:serial_port_win32/serial_port_win32.dart';
import 'package:win32/win32.dart';

import 'dacal_transport.dart';

/// The default Dacal transport settings for a DC-101 / DC-300 carousel.
///
/// These match the common configuration used by the reference DACAL
/// libraries (8 data bits, no parity, one stop bit). Baud rate is not
/// meaningful to a USB control-transfer device but is required by the
/// serial API and left at the library default.
abstract final class DacalSerialSettings {
  /// Bytes of the byte-size field.
  static const int byteSize = 8;

  /// No parity.
  static const DCB_PARITY parity = NOPARITY;

  /// One stop bit.
  static const DCB_STOP_BITS stopBits = ONESTOPBIT;

  /// 9600 baud (nominal; USB devices ignore framing speed).
  static const int baudRate = 9600;
}

/// A [DacalTransport] backed by a Windows COM port via
/// `package:serial_port_win32`.
///
/// The host drivers expose the Dacal carousel's USB link as a virtual COM
/// port on Windows; this adapter reads and writes that port. Open
/// notifications and plug detection are deliberately out of scope — the
/// carousel is enumerated and opened by port name.
class DacalSerialTransport implements DacalTransport {
  /// The Windows COM port name, for example `COM3`.
  final String portName;

  /// The byte channel, lazily created by [open].
  SerialPort? _port;

  /// Creates a transport for [portName] (for example `COM3`).
  DacalSerialTransport(this.portName);

  @override
  bool get isOpen => _port?.isOpened ?? false;

  @override
  Future<String?> open() async {
    if (isOpen) return null;
    try {
      final port = SerialPort(
        portName,
        openNow: true,
        ByteSize: DacalSerialSettings.byteSize,
        BaudRate: DacalSerialSettings.baudRate,
        Parity: DacalSerialSettings.parity,
        StopBits: DacalSerialSettings.stopBits,
      );
      if (!port.isOpened) {
        return 'Failed to open $portName';
      }
      _port = port;
      return null;
    } catch (e) {
      return 'Could not open $portName: $e';
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final port = _requireOpen();
    await port.writeBytesFromUint8List(Uint8List.fromList(bytes));
  }

  @override
  Future<List<int>> read(
    int count, {
    Duration timeout = const Duration(milliseconds: 1000),
  }) async {
    final port = _requireOpen();
    final data = await port.readBytes(
      count,
      timeout: timeout,
    );
    return data;
  }

  @override
  Future<void> close() async {
    _port?.close();
    _port = null;
  }

  SerialPort _requireOpen() {
    final port = _port;
    if (port == null) {
      throw StateError('Serial port $portName is not open');
    }
    return port;
  }
}
