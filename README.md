# decalcd

Communication layer for controlling a Dacal CD carousel (DC-101 / DC-300) on
Windows. It opens a serial (USB-backed virtual COM) connection, sends commands
(move to slot, get status, reset, LED), parses the status-token responses, and
can capture raw traffic for reverse engineering.

This package is the low-level transport + protocol layer that the CLI, TUI and
Flutter app build on.

## Protocol summary

The Dacal carousel is a Cypress 0x04b4 / 0x5a9b USB device that exposes the
same command set over either of two transports, confirmed by live USB capture
(USBPcap):

- **Serial (CDC virtual COM)** — a byte stream of single opcode bytes; responses
  are framed as a two-byte little-endian length followed by a UTF-16LE status
  token (`ACK`, `BUSY`, `SOS`, `ERROR`).
- **HID string-descriptor (this unit)** — Cypress CY7C64225 HID-UART bridge
  with a single interrupt-IN endpoint `0x81` and no OUT endpoint. Commands ride
  as **GET_DESCRIPTOR STRING** control transfers on EP0 where the **string index
  is the opcode byte**; the response is a string descriptor `LL 03 <token
  UTF-16LE>` (`03` = STRING descriptor type, LL = byte count) — the same status
  tokens, differing from the serial frame only in byte [1] (0x03 vs 0x00).

The opcode table below is validated against live captures of both. Command
bytes are single opcodes; the two-byte move-to-slot operation is the opcode
`MOVE_TO` followed by the slot number byte (e.g. slot 5 -> `0x05`), exactly as
`DacalCodec.encode` / `encodeSlot` emit.

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
| The library catalog | The library's own collection of `Disc`s, independent of carousel placement. A catalogue disc may be in the machine (one slot) or not. |

Relationship: **a `Device` has many `Slot`s, each `Slot` holds at most one `Disc`, and
the library catalog tracks its `Disc`s independently of those placements.**
Operations are single-action use cases typed against the `ILibraryRepository`
contract:

- Read: `ListDevices`, `GetDeviceBySerialCode`, `ListSlotsForDevice`,
  `GetSlotStatus`, `ListDiscs`, `GetDisc`, `LocateDisc`.
- Add / remove / change a disc **in the library**: `AddDiscToLibrary` (refuses a
  duplicate sku with `AlreadyExistsFailure`), `RemoveDiscFromLibrary` (refuses
  with `InUseFailure` while the disc is in a carousel slot), `ChangeDiscInLibrary`
  (updates sku / label / serial number and refreshes `Meta.updatedAt`; syncs the
  slot's inline copy when the disc is placed).
- Add / remove a disc **in the machine** (a specific slot): `InsertDisc` (refuses
  an occupied slot and clears the disc's previous slot, atomically when a unit of
  work is passed), `RemoveDisc`.

Every call returns an fpdart
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