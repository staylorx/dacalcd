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

## Capturing at the USB level (USBPcap)

The serial log captures what the app and device exchange *after* the USB
transport, which is enough once the transport is known. To learn the transport
itself — and to see this unit's real, non-COM wiring — capture the raw USB bus:

- USBPcap is installed at `C:\Program Files\USBPcap\USBPcapCMD.exe`; tshark at
  `C:\Program Files\Wireshark\tshark.exe`. Capture needs admin (RunAs).
- **This unit (Cypress 04B4:5A9B) is HID-class, not CDC/virtual-COM.** It has a
  single interrupt-IN endpoint `0x81` (3-byte reports) and NO interrupt-OUT
  endpoint. Commands travel as **GET_DESCRIPTOR STRING** control transfers on
  EP0 where the **string index == the opcode byte**; the response is a string
  descriptor payload = 2-byte length + UTF-16LE status token (`ACK`/`BUSY`/
  `ERROR`). So the response framing is identical to the serial capture — only
  the transport differs.
- Referenced tooling lives in `tool/`:
  - `tool/usbpcap_capture_dacal.ps1` — elevated capture of the Dacal (default
    `\\.\USBPcap2`, `--devices 10`, `--inject-descriptors`); pass
    `-Seconds N -OutFile path.pcap`. Device **address can change on replug** —
    re-map it first (see below).
  - `tool/decode_dacal_capture.sh` — decodes device-10 frames into TX/RX hex.
  - To find the current address after a replug: capture the bus with
    `--inject-descriptors` and tshark it:
    `tshark -r f.pcap -Y "usb.device_address == X" -V | grep -i -A2 idVendor`.
- Packet layout (USBPcap header = 28 bytes, then USB): the GET_DESCRIPTOR
  setup is at offset 0x1c (`80 06 <idx> 03 09 04 …`); the string index (opcode)
  is the byte at 0x1e. Responses carry the status at 0x1e.. as UTF-16LE.
- See `docs/usb-capture-session-2026-10-12.md` for a worked decode.
