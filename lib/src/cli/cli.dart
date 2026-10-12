import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../dacal_client.dart';
import '../domain/domain.dart';
import '../library_service.dart';
import '../machine_detector.dart';
import '../usecases/usecases.dart';

part 'commands.dart';

/// Sink for how the CLI writes a line. Defaults to [print]; tests inject a
/// capturing sink so they can assert on output without touching stdout.
typedef LineWriter = void Function(String line);

/// The dependencies every command needs at the composition root.
///
/// The CLI is a thin consuming shell over the domain (via the repository
/// contract), the repository adapters, and the USB/serial layer (via a
/// [DacalClient] when a carousel is present). It never owns storage or a
/// port: the caller wires those in.
class DecalCliDeps {
  /// The library repository the domain use cases run against.
  final ILibraryRepository library;

  /// Optional unit of work so insert/remove writes are atomic (rolled back on
  /// a `Left`). Pass a [NoOpUnitOfWork] (or null) when the store cannot roll
  /// back.
  final IUnitOfWork? unitOfWork;

  /// The carousel client (USB/serial layer). Null when no carousel is wired;
  /// carousel commands then report it as unavailable instead of crashing.
  final DacalClient? carousel;

  /// Shared read-side service both the CLI and the TUI call to fetch the same
  /// library data. Defaults to a service over [library] so callers that only
  /// supply a repository keep working unchanged.
  final LibraryService service;

  /// Where normal output goes.
  final LineWriter out;

  /// Where diagnostics / usage errors go.
  final LineWriter err;

  /// Creates the dependency bundle.
  DecalCliDeps({
    required this.library,
    this.unitOfWork,
    this.carousel,
    LibraryService? service,
    LineWriter? out,
    LineWriter? err,
  }) : service =
           service ?? LibraryService(repository: library, carousel: carousel),
       out = out ?? print,
       err = err ?? _defaultErr;

  static void _defaultErr(String line) => print('decal: $line');
}

/// The Decal CD library command-line interface.
///
/// Wraps [CommandRunner] (package:args) as a re-usable, testable object:
/// `run([...])` parses args, executes the chosen command and returns an exit
/// code (0 success, 1 failure). `main()` of the `bin/decal.dart` entry just
/// calls this and forwards the code.
class DecalCli {
  /// The underlying command runner.
  final CommandRunner<int> _runner;

  /// Error writer for top-level use/parse errors.
  final LineWriter _err;

  /// Creates the CLI with [deps] injected at the composition root.
  DecalCli(DecalCliDeps deps)
    : _err = deps.err,
      _runner = DecalCli._buildRunner(deps);

  static CommandRunner<int> _buildRunner(DecalCliDeps deps) {
    final runner = CommandRunner<int>(
      'decal',
      'Manage the Dacal CD carousel library: devices, slots, discs and '
          'carousel control.',
    );
    runner.addCommand(ListDevicesCommand(deps));
    runner.addCommand(ShowDeviceCommand(deps));
    runner.addCommand(DeviceAddCommand(deps));
    runner.addCommand(DeviceRemoveCommand(deps));
    runner.addCommand(DeviceUpdateCommand(deps));
    runner.addCommand(ListSlotsCommand(deps));
    runner.addCommand(InsertDiscCommand(deps));
    runner.addCommand(RemoveDiscCommand(deps));
    runner.addCommand(LocateDiscCommand(deps));
    runner.addCommand(CarouselCommand(deps));
    runner.addCommand(DetectMachineCommand(deps));
    return runner;
  }

  /// Parses [args] and runs the selected command, returning an exit code.
  Future<int> run(List<String> args) async {
    try {
      return (await _runner.run(args)) ?? 0;
    } on UsageException catch (e) {
      _err(e.toString());
      return 1;
    }
  }
}

// -- helpers shared by the commands -----------------------------------------

/// Parses [value] as a positive integer, or writes an error and returns null.
int? parsePositiveInt(String value, DecalCliDeps deps, String what) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    deps.err('invalid $what "$value" (expected a positive integer)');
    return null;
  }
  return parsed;
}
