/// Sealed failures for the Dacal communication layer.
///
/// The communication layer reports failure as a *value* (following the
/// dart-flutter-bible doctrine): every public operation returns an
/// `Either<DacalFailure, T>` (or `TaskEither`) rather than throwing.
sealed class DacalFailure {
  const DacalFailure();
}

/// A command was rejected by the device, which answered with a non-ACK status.
final class DacalDeviceError extends DacalFailure {
  /// The status text the device returned (for example `BUSY` or `SOS`).
  final String status;

  /// The command opcode (and optional slot) that produced the error.
  final String command;

  /// Creates a device-error failure.
  const DacalDeviceError({required this.status, required this.command});

  @override
  String toString() =>
      'DacalDeviceError(command: $command, status: $status)';
}

/// The transport could not be opened or was closed while in use.
final class DacalConnectionError extends DacalFailure {
  /// Human-readable detail on why the open failed.
  final String message;

  /// Creates a connection-error failure.
  const DacalConnectionError(this.message);

  @override
  String toString() => 'DacalConnectionError($message)';
}

/// Bytes read from the device could not be decoded into a status response.
final class DacalProtocolError extends DacalFailure {
  /// Description of the malformed frame.
  final String message;

  /// Creates a protocol-error failure.
  const DacalProtocolError(this.message);

  @override
  String toString() => 'DacalProtocolError($message)';
}
