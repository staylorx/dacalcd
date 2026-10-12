# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project is the core package (`decalcd`) in the decalcd Topology-C
workspace. This file records the **keen decisions and the why** (bible §1.3),
not a work log. Group by release, newest on top; a release tag is a plain
`vX.Y.Z`.

## [Unreleased]

### Added

- **Multiple CD library machines data model.** `Device` is now a full machine
  type carrying `manufacturer` (e.g. `'Dacal'`), `sku` (e.g. `'DC-300'`),
  `model` (e.g. `'CD Library II'`) and `serialNumber` (e.g. `'67808'`), plus
  per-machine serial-port details (`serialConfig`) — connection settings are
  per machine, not one app-wide port. The repository returns a `List<Device>`
  so the library manages any number of machines. A new **`serializable`
  trait** (with the `serial_number` trait attribute) captures serial numbers
  generically: every machine is serializable and exposes its serial as the
  `serial_number` trait-attribute value.

- **CRUD API + storage for multiple machines.** The repository contract gained
  `deleteDevice` (removes a machine and its slots in one step, so a removed
  machine leaves no orphaned records), implemented by both the sembast and
  in-memory adapters. New use cases — `AddDevice`, `GetDeviceById`,
  `UpdateDevice`, `DeleteDevice` — join the existing `ListDevices` /
  `GetDeviceBySerialCode` to make machine management full CRUD: list all
  machines, fetch one by id *or* serial number, register a new machine
  (minting its id, refusing a duplicate serial), update its identity fields,
  and delete it. `LibraryService` (the shared CLI/TUI/Flutter front door)
  exposes all five, and new CLI commands `decal device-add` / `device-remove`
  / `device-update` drive them; `decal device-info` now accepts an id or a
  serial. Every response carries the machine's manufacturer, sku, model and
  serial number, and the serial stays retrievable as the `serial_number`
  value of the `serializable` trait. Serial numbers are unique per machine.

- **Retract (unslot) primitive on the serial client.** `DacalClient.retract()`
  sends the `RETRACT` (`0x0e`) opcode on its own — the firmware's "release the
  disc out of the reader" command, the complement to `moveToSlot`. This is
  what the Flutter disk library's Unslot button issues; previously only a raw
  `send` of the opcode existed with no dedicated, tested high-level method.

- **Persistent serial connection settings.** A `SerialConfig` domain entity
  (port name + baud rate) exposed through the public barrel, a
  `ISerialConfigStore` contract, a file-backed `SerialConfigFileStore`
  (a `src/config` composition-root seam, like `src/data`, kept off the
  platform-agnostic barrel), and a `SerialConfigService` facade the Flutter
  app calls to persist the selected COM port across restarts.

- **Automatic machine detection via a protocol ping.** `probeMachine(client)`
  (in `src/machine_detector.dart`, exported from the public barrel) opens the
  client's transport and issues the status query — the protocol's equivalent
  of a ping — to the machine (`'67808'`). It returns a sealed
  `MachineProbeResult`: `MachineDetected` when a **firmware** answer comes
  back (any decodable status, since even a BUSY/SOS rejection proves a
  machine is on the line), `MachineNotDetected` for an open failure, timeout
  or undecodable reply. Availability is a value, never thrown, and the probe
  leaves the port in the state it found it. `probeMachineAvailable(client)`
  is a convenience returning just the boolean. New CLI `decal --port COM detect`.

### Keen decisions

- **Repo hygiene audit (bible §9.11 bootstrap item 11).** The core repo agreed
  to the operating-docs contract: `AGENTS.md` at the workspace root (deviations
  + local wiring, never doctrine restated), a `BACKLOG.md` queue per package,
  this Keep-a-Changelog, and a CI workflow that calls the one canonical melos
  script contract (`dart run melos run <task>`, §2.1). Prior state: core had a
  one-line CHANGELOG stub, no BACKLOG, no AGENTS, no CI.
- **Three sibling Topology-C roots is a deliberate deviation, not an accident.**
  `decalcd` (core), `decalcd_tui` and `decalcd_flutter` (delivery mechanisms)
  are independent packages, each its own melos workspace root. Keep them that
  way; do not "fix" into a monorepo without a proposal.
- **`decalcd_flutter` is intentionally CI-gated natively.** It has no melos
  script contract yet (bible §2.1 gap, tracked as a deviation); its CI gate is
  native `flutter analyze`/`flutter test` until aligned.
- **Config §13 is tracked, not implemented.** The CLI is flag-only (`--db`,
  `--port`); the three-layer precedence chain is a recorded BACKLOG item (owner
  may declare it a deliberate deviation instead).
- **Repository identity.** package/repository metadata is `taybiz/decalcd`;
  the on-disk folder is `dacalcd`. The local carousel unit is `'67808'`.

### Fixed

- CHANGELOG was a placeholder (`## 1.0.0 / Initial version`) that silenced the
  "keen decisions" record for this package; replaced with the real format.

## [0.1.0]

- Initial serial-transport + library-domain core (Dacal DC-101/DC-300 protocol
  codec, `ILibraryRepository` contract, sembast + in-memory adapters, CLI
  `bin/decal.dart`, shared `LibraryService`).
