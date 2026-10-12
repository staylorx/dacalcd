# Capturing Dacal serial traffic for reverse engineering

The Dacal family's documented command set (see the README opcode table) covers
the common DC-101 / DC-300 operations, but not every variant is fully mapped.
When you have a machine whose command set you want to confirm or discover, use
`DacalLoggingTransport` to record every byte exchanged while you drive the
vendor software, then study the capture.

## How it works

`DacalLoggingTransport` wraps any other `DacalTransport` and writes each event to
a log file:

- `OPEN` when the port is opened
- `TX <hex>` for every command written to the device
- `RX <hex>` for every response read back
- `CLOSE` when the port is closed

Lines are flushed incrementally, so a capture survives a crash mid-run.

## Wiring it into your tool

```dart
import 'package:decalcd/decalcd.dart';

final inner = DacalSerialTransport('COM3');
final capturing = DacalLoggingTransport(
  inner,
  directory: r'C:\captures',
  fileName: 'session1.log',
);

final client = DacalClient(capturing);
await client.open();
// ... now run the vendor software or issue commands ...
await client.close(); // flushes and closes the log
```

Run the vendor's own control software against the same COM port instead of your
code, and it will appear in the capture — that is the fastest way to learn the
exact bytes the manufacturer's app sends.

## Reading a capture

Each line is a sequence number plus a direction tag and hex bytes. Stop your
own code from sending anything while capturing so the log only contains the
actions you are reverse-engineering.

Worked example of interpreting a capture:

```
#0: OPEN
#1: TX 11
#2: RX 08 00 41 00 43 00 4b 00
#3: TX 0e
#4: RX 08 00 41 00 43 00 4b 00
#5: TX 0c 05
#6: RX 08 00 41 00 43 00 4b 00
```

- `#1` sends `GET_STATUS` (0x11); `#2` answers `08 00` (length 8) then
  `41 00 43 00 4b 00` = UTF-16LE `ACK`.
- `#3` sends `RETRACT` (0x0e); the device ACKs.
- `#5` sends `MOVE_TO` (0x0c) followed by slot byte `05`; the device ACKs.

Cross-reference each `TX` opcode against the README table; an operation that
does not match known opcodes is a candidate for a newly discovered command.

## What to do with a discovery

Record the new opcode (and its argument layout) in the README protocol table
and add a `DacalResponse`/codec mapping for it, so the next tool using this
layer can drive it without another capture session.

## Pitfalls

- Do not `echo` or send your own traffic during a capture you intend to
  interpret — it pollutes the log.
- The log uses raw hex; decode status tokens with the codec or the table above.
- `DacalLoggingTransport` must be `close()`d to flush the final buffered lines.
