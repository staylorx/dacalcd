import 'dart:io';

import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/cli/cli.dart';
import 'package:decalcd/src/data/data.dart';
import 'package:sembast/sembast_io.dart';

/// The `decal` command-line entry point.
///
/// Wires a file-backed sembast library and — when `--port` is given — a real
/// USB/serial transport to the CLI. With no carousel port the CLI runs the
/// library commands only.
///
/// Global options (`--db`, `--port`) must precede the subcommand; everything
/// after them is handed to the CLI verbatim (the CLI's own package:args parser
/// owns `--help`, unknown flags, etc.):
///
///   `decal --db lib.db --port COM3 insert <device> <slot> <sku>`
///
Future<void> main(List<String> args) async {
  // Peel the leading global options off the arg list; the remainder (the
  // subcommand + its args) is the CLI's to parse.
  var dbPath = 'decalcd.db';
  String? port;
  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg.startsWith('--db=')) {
      dbPath = arg.substring('--db='.length);
      i++;
    } else if (arg == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
      i += 2;
    } else if (arg.startsWith('--port=')) {
      port = arg.substring('--port='.length);
      i++;
    } else if (arg == '--port' && i + 1 < args.length) {
      port = args[i + 1];
      i += 2;
    } else {
      break;
    }
  }
  final cliArgs = args.skip(i).toList();

  // Open the library database (composition root).
  final db = await databaseFactoryIo.openDatabase(
    dbPath,
    version: librarySchemaVersion,
    onVersionChanged: libraryMigrations,
  );
  final scope = SembastTransactionScope();
  final repository = SembastLibraryRepository(database: db, scope: scope);
  final unitOfWork = SembastUnitOfWork(database: db, scope: scope);

  // Real carousel transport when a port is given, else none.
  DacalClient? carousel;
  if (port != null && port.isNotEmpty) {
    carousel = DacalClient(DacalSerialTransport(port));
    await carousel.open();
  }

  // The CLI command args are everything after the global options (which the
  // args parser strips off the front).
  final cli = DecalCli(
    DecalCliDeps(
      library: repository,
      unitOfWork: unitOfWork,
      carousel: carousel,
    ),
  );
  final code = await cli.run(cliArgs);
  await db.close();
  if (carousel != null) await carousel.close();
  exit(code);
}
