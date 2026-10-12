/// Automatic serial-port detection (autoseek) for the Decal CD carousel.
///
/// The carousel's USB link enumerates as one of several virtual COM ports on
/// Windows; autoseek finds which one it is by enumerating the candidate ports
/// and probing each for the machine (an [IPortEnumerator] + a machine probe),
/// then returns the matching port as [AutoseekFound].
///
/// Both the enumerator and the prober are injectable, so tests hand the
/// service a fake port list and a fake prober and never touch hardware. The
/// transport-level probe ([probePort]) is the production default.
library;

import 'package:fpdart/fpdart.dart';

import '../dacal_client.dart';
import '../dacal_failure.dart';
import '../dacal_serial_transport.dart';
import '../machine_detector.dart';
import 'port_enumerator.dart';

export 'port_enumerator.dart';

/// The outcome of an autoseek over the available COM ports.
sealed class AutoseekResult {
  const AutoseekResult();

  /// True when a matching port was found ([AutoseekFound]).
  bool get found => this is AutoseekFound;
}

/// A COM port answered the machine probe; [portName] is the one to connect to.
final class AutoseekFound extends AutoseekResult {
  /// The port that reported a reachable Dacal CD machine.
  final String portName;

  /// Creates a found result for [portName].
  const AutoseekFound(this.portName);

  @override
  String toString() => 'AutoseekFound(portName: $portName)';
}

/// No enumerated port answered the machine probe.
final class AutoseekNotFound extends AutoseekResult {
  /// Human-readable summary of why nothing matched.
  final String reason;

  /// Creates a not-found result with [reason].
  const AutoseekNotFound(this.reason);

  @override
  String toString() => 'AutoseekNotFound($reason)';
}

/// Probes a single [portName] and reports whether a reachable Dacal CD
/// machine answered.
///
/// Builds a serial transport over the port and answers the protocol probe
/// ([probeMachineAvailable]). A port that cannot be opened, times out, or
/// answers with garbage folds to `false` rather than throwing, so probing an
/// empty port is a normal outcome, not an error.
TaskEither<DacalFailure, bool> probePort(String portName) {
  final client = DacalClient(DacalSerialTransport(portName));
  return probeMachineAvailable(client);
}

/// Finds the COM port where the Dacal CD machine is reachable (autoseek).
///
/// Enumerates the candidate ports through [enumerator] and probes each in
/// order through [probe] until one answers the machine probe. The matching
/// port is returned as [AutoseekFound]; if none answers, [AutoseekNotFound].
/// Ports that a probe cannot open count as absent (`false`) and are skipped,
/// so autoseek never stops on an empty or contested port.
final class AutoseekService {
  /// Source of candidate COM port names.
  final IPortEnumerator enumerator;

  /// How each candidate port is probed for the machine.
  final TaskEither<DacalFailure, bool> Function(String portName) probe;

  /// Creates an autoseek service. Defaults [probe] to [probePort] when the
  /// caller does not inject one.
  AutoseekService({
    required this.enumerator,
    TaskEither<DacalFailure, bool> Function(String portName)? probe,
  }) : probe = probe ?? probePort;

  /// Searches the enumerated ports for the Dacal CD machine.
  TaskEither<DacalFailure, AutoseekResult> seek() =>
      enumerator.listAvailablePorts().flatMap(_seekOnPorts);

  TaskEither<DacalFailure, AutoseekResult> _seekOnPorts(List<String> ports) =>
      TaskEither.tryCatch(
        () async {
          for (final port in ports) {
            final either = await probe(port).run();
            if (either.isRight() && either.getRight().toNullable() == true) {
              return AutoseekFound(port);
            }
          }
          return AutoseekNotFound(
            'No enumerated COM port answered the machine probe.',
          );
        },
        (Object error, StackTrace stackTrace) =>
            DacalConnectionError('Autoseek failed: $error'),
      );
}
