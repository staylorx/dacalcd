# decalcd

Communication layer for controlling a Dacal CD carousel (DC-101 / DC-300) on
Windows. It opens a serial (USB-backed virtual COM) connection, sends commands
(move to slot, get status, reset, LED), parses the status-token responses, and
can capture raw traffic for reverse engineering.

This package is the low-level transport + protocol layer that the CLI, TUI and
Flutter app build on.

## Protocol summary

The Dacal carousel enumerates on Windows as a virtual COM port (its USB link is
a Cypress 0x04b4 / 0x5a9b device). Commands are single opcode bytes; responses
are framed as a two-byte little-endian length followed by a UTF-16LE status
token (`ACK`, `BUSY`, `SOS`, `ERROR`).

| Command        | Opcode | Notes                                   |
|----------------|--------|-----------------------------------------|
| ID             | 0x0a   | Identify the device                     |
| RESET          | 0x0b   | Reset the spindle                       |
| MOVE_TO        | 0x0c   | Followed by the slot number byte        |
| RETRACT        | 0x0e   | Retract the pickup arm                  |
| LED_ON         | 0x0f   | Turn the LED display on                 |
| LED_OFF        | 0x10   | Turn the LED display off                |
| GET_STATUS     | 0x11   | Returns ACK / BUSY / SOS / ERROR        |

A "move to slot" is the two-step `RETRACT` then `MOVE_TO` + slot, matching the
reference USB libraries.

## Error style

Failures are returned as values — every operation completes with
`Either<DacalFailure, T>` (fpdart). See `lib/decalcd.dart` for the failure
hierarchy. Nothing throws.

## Usage

```dart
import 'package:decalcd/decalcd.dart';

// Real Windows COM port transport:
final transport = DacalSerialTransport('COM3');
final client = DacalClient(transport);

final result = await client.moveToSlot(5);
result.fold(
  (failure) => print('failed: $failure'),
  (response) => print('moved: ${response.status.token}'),
);
```

## Capturing serial traffic for reverse engineering

If a given machine's command set is not fully documented, wrap the live
transport in `DacalLoggingTransport` and run the vendor software; every byte
sent and received is appended to a log file. See
[`docs/capturing-traffic.md`](docs/capturing-traffic.md) for the full walkthrough
and a worked example reading the capture back into a frame viewer.

## Tests

`dart test` — the codec, frame reader and client are tested against an
in-memory fake transport (no hardware required).

## The library model (domain)

Alongside the transport layer, this package carries the Decal CD **library
domain** built on the `sku_catalog` package: the physical carousel is a SKU,
and so are the discs it holds.

| Concept | What it is |
|---|---|
| `Device` | A physical Decal CD carousel, unique by `serialCode` per machine (the unit here is `'67808'`). It is itself a catalog SKU (`skuId`) whose trait attribute is the total CD count (`capacity`, e.g. 150). |
| `Slot` | One position in a device's carousel, identified by a `slotNumber` unique within that device (1..capacity). Empty or holding exactly one `Disc`. |
| `Disc` | A CD/DVD held by the library — a catalog SKU (`skuId`), so it can be classified by the catalog's traits. The library leans on `SkuAssociation` links to relate disc SKUs to the carousel SKU and to each other. |

Relationship: **a `Device` has many `Slot`s, and each `Slot` holds at most one
`Disc`.** Operations are single-action use cases typed against the
`ILibraryRepository` contract: `ListDevices`, `GetDeviceBySerialCode`,
`ListSlotsForDevice`, `GetSlotStatus`, `InsertDisc`, `RemoveDisc`,
`LocateDisc`. Every call returns an fpdart
`TaskEither<DecalFailure, T>`; call `.run()` for a
`Future<Either<DecalFailure, T>>`.

### Persistence

Two `ILibraryRepository` adapters ship in this package, both honoring one
shared contract suite:

- a **sembast** adapter (`SembastLibraryRepository`, in
  `lib/src/data/`) that persists `Devices` and `Slots` in a local sembast
  database — the production path;
- an in-memory test double (`MemoryLibraryRepository` in
  `test/support/`) for tests and tooling.

The sembast adapter stores a slot's `Disc` inline on the slot row and supports
atomic multi-write operations through `SembastUnitOfWork`: a `Left` returned
inside a unit of work rolls the whole transaction back. Schema changes are
driven by sembast's `onVersionChanged` migration hook
(`lib/src/data/sembast_schema.dart`). The data layer is not part of the public
barrel; wire it in at your composition root by importing
`package:decalcd/src/data/data.dart` (CLI, TUI and Flutter app).

## The CLI

`bin/decal.dart` is a command-line interface over the domain (via the
repository contract) and the USB/serial carousel layer. It wires a file-backed
sembast library at the composition root and — when `--port` is given — a real
serial transport to the carousel:

```
decal --db lib.db [--port COM3] <command> [args]
```

Global options (`--db`, `--port`) must precede the subcommand. Run
`decal --help` for usage.

| Command | Purpose | Example |
|---|---|---|
| `devices` | List carousel devices | `decal devices` |
| `device-info <serial>` | Show one device | `decal device-info 67808` |
| `slots <device-id>` | List a device's slots | `decal slots dev-67808` |
| `insert <device-id> <slot> <sku-id>` | Place a disc in a slot | `decal insert dev-67808 5 cd-sku-99` |
| `remove <device-id> <slot>` | Empty a slot | `decal remove dev-67808 5` |
| `locate <disc-id>` | Find a disc's slot | `decal locate <disc-id>` |
| `carousel <slot>` | Move the spindle to a slot (USB/serial) | `decal --port COM3 carousel 12` |
| `detect` | Probe whether the machine (`'67808'`) is reachable | `decal --port COM3 detect` |

Device/slot/carousel records are persisted across runs in the sembast file.
The CLI layer lives under `lib/src/cli/` (a composition-root seam, imported
as `package:decalcd/src/cli/cli.dart`, not part of the public barrel) and is
unit-tested for command parsing in `test/decal_cli_test.dart` against an
in-memory repository and a fake serial transport — no hardware required.

### Shared data service

Both the CLI and the TUI (and the Flutter app) fetch their read-side data
through the shared [`LibraryService`](lib/src/library_service.dart) — a thin
facade over the domain read use cases. The CLI's `devices` / `slots` commands
and the TUI's controller load path call this same service, so neither entry
point reconstructs its own data-fetching path. Integration coverage lives in
`test/library_service_integration_test.dart`, which drives the shared service
against both a CLI `DecalCli` run and asserted live data.