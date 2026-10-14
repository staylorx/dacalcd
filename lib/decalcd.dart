/// # Communication layer for the Dacal CD carousel.
///
/// Opens a serial (USB-backed virtual COM) connection to a Dacal DC-101 /
/// DC-300 carousel, sends commands (move to slot, get status, reset, LED),
/// and parses the status-token responses.
///
/// ## Error style
///
/// **Failures are returned as values** (`Either<DacalFailure, T>`), never
/// thrown: every operation completes with `fpdart` tuples. The underlying
/// byte transport is injected so the client works against a real Windows
/// port, a capture logger (for reverse engineering), or an in-memory fake
/// (for tests).
///
/// See the README for how to capture serial traffic when the protocol for a
/// given machine is not fully documented.
///
/// ## The library model
///
/// Alongside the communication layer, this package carries the Decal CD
/// library domain: a [Device] (the carousel, itself a catalog SKU with
/// serial codes unique per machine), its [Slot]s, and the [Disc]s (catalog
/// CD/DVD SKUs) that occupy them. Every action the outer rings perform — the
/// GUI, the TUI and the CLI alike — goes through the use cases in
/// `src/usecases` (list devices, get a device by serial code, list slots, get
/// slot status, insert/remove a disc, locate a disc, load the list-view
/// snapshot); no ring talks to a repository or a parallel service directly.
///
/// The domain presents FP-style tuples: every repository method and use case
/// call returns a fpdart `TaskEither<DecalFailure, T>`; call `.run()` for a
/// `Future<Either<DecalFailure, T>>`.
library;

export 'src/autoseek/autoseek.dart';
export 'src/command.dart';
export 'src/config/legacy_serial_config_migration.dart';
export 'src/config/serial_config_service.dart';
export 'src/dacal_client.dart';
export 'src/dacal_codec.dart';
export 'src/dacal_failure.dart';
export 'src/dacal_frame_reader.dart';
export 'src/dacal_logging_transport.dart';
export 'src/dacal_response.dart';
export 'src/machine_detector.dart';
export 'src/dacal_serial_transport.dart';
export 'src/dacal_transport.dart';
export 'src/domain/domain.dart';
export 'src/usecases/usecases.dart';
