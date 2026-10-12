import 'package:fpdart/fpdart.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

import '../dacal_failure.dart';

/// A source of candidate serial port names for autoseek to try.
///
/// [IPortEnumerator] is the seam that lets tests hand the [AutoseekService] a
/// fixed list of fake ports while production enumerates the real Windows COM
/// registry. The enumeration error is surfaced as a [DacalFailure] value,
/// never thrown, matching the library's FP error style.
abstract interface class IPortEnumerator {
  /// Lists the available serial port names (for example `COM3`, `COM7`).
  TaskEither<DacalFailure, List<String>> listAvailablePorts();
}

/// Enumerates the Windows COM ports actually present on this machine via
/// `package:serial_port_win32` — the same registry the transport opens, so an
/// autoseek candidate is always a port that `DacalSerialTransport` can try.
final class WindowsComPortEnumerator implements IPortEnumerator {
  /// The regex for a canonical `COM<n>` port name.
  static final RegExp _comPattern = RegExp(
    r'^COM\d+$',
    caseSensitive: false,
  );

  @override
  TaskEither<DacalFailure, List<String>> listAvailablePorts() =>
      TaskEither.tryCatch(
        () async {
          final ports = SerialPort.getAvailablePorts();
          final result = <String>[];
          for (final raw in ports) {
            final trimmed = raw.trim();
            if (trimmed.isEmpty) continue;
            if (!_comPattern.hasMatch(trimmed)) continue;
            result.add(trimmed);
          }
          return result;
        },
        (Object error, StackTrace stackTrace) =>
            DacalConnectionError('Failed to enumerate COM ports: $error'),
      );
}
