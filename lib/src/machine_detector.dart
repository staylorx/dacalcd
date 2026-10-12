import 'package:fpdart/fpdart.dart';

import 'dacal_client.dart';
import 'dacal_failure.dart';
import 'dacal_response.dart';

/// The serial number of the Decal CD machine at this site. The machine is a
/// physical carousel whose identity is its serial number (`'67808'` here), so
/// machine detection keys on reaching a unit on the probed transport.
const String kDecalMachineSerialCode = '67808';

/// The outcome of probing whether a Dacal CD machine is present on a
/// transport. Availability is a *value*, not an exception: a machine that
/// does not answer is reported as [MachineNotDetected], the same way `ping`
/// reports an unreachable host without throwing.
sealed class MachineProbeResult {
  const MachineProbeResult();

  /// True when a machine answered the probe and is reachable.
  bool get detected => this is MachineDetected;
}

/// A machine answered the probe and is reachable. [status] is what it
/// reported — `ok` for a ready unit, or `busy`/`sos` for a live-but-busy or
/// faulted one. Any decodable status counts as *detected*.
final class MachineDetected extends MachineProbeResult {
  /// The status the machine reported in its probe answer.
  final DacalStatus status;

  /// Creates a detected result.
  const MachineDetected(this.status);

  @override
  bool get detected => true;

  @override
  String toString() => 'MachineDetected(status: ${status.token})';
}

/// No machine answered the probe: the port could not be opened, the probe
/// timed out, or the reply was undecodable. [reason] is human-readable.
final class MachineNotDetected extends MachineProbeResult {
  /// Why no machine was found.
  final String reason;

  /// Creates a not-detected result.
  const MachineNotDetected(this.reason);

  @override
  String toString() => 'MachineNotDetected($reason)';
}

/// Probes whether the Decal CD machine is reachable and available on
/// [client]'s transport.
///
/// The probe opens the transport (if not already open) and issues a status
/// query — the protocol's equivalent of a ping, keyed to the site machine
/// whose serial code is [kDecalMachineSerialCode]. If the transport opens and
/// the machine answers with any decodable status frame, it is present and
/// available: returns [MachineDetected]. An open failure, a read timeout, or
/// an undecodable reply is an *absence*, returned as [MachineNotDetected] —
/// never thrown, so callers can treat this as a boolean reachability check.
///
/// The probe leaves the transport in the state it found it in: if it opened
/// it, it closes it again before returning, so the port is not held while the
/// caller decides whether to connect. A transport that was already open is
/// left open.
///
/// A `Left` is reserved for genuinely unexpected errors (an exception inside
/// the probe itself), not for a machine being absent.
TaskEither<DacalFailure, MachineProbeResult> probeMachine(
  DacalClient client,
) {
  return TaskEither<DacalFailure, MachineProbeResult>.tryCatch(() async {
    final wasOpen = client.isOpen;
    if (!wasOpen) {
      final open = await client.open();
      if (open.isLeft()) {
        return const MachineNotDetected('the port could not be opened');
      }
    }

    final status = await client.getStatus();

    if (!wasOpen) {
      await client.close();
    }

    // Any *firmware* answer — a decoded OK, or a device rejection such as
    // BUSY/SOS — proves a machine is on the line, so both count as detected.
    // Only connection/protocol failures (nothing answered or the reply could
    // not be decoded) mean the machine is absent.
    return status.fold(
      (failure) => switch (failure) {
        DacalDeviceError(:final status) =>
          MachineDetected(DacalStatus.fromToken(status)),
        _ => MachineNotDetected(failure.toString()),
      },
      (response) => MachineDetected(response.status),
    );
  }, (Object error, StackTrace stackTrace) =>
      DacalConnectionError('probe failed: $error'));
}

/// Convenience: probes [client] and reports just the reachability boolean, so
/// callers that only need a yes/no do not have to fold the result type.
TaskEither<DacalFailure, bool> probeMachineAvailable(DacalClient client) =>
    probeMachine(client).map((result) => result.detected);
