# Dacal USB capture — labeling session 2026-10-12 (2nd capture)

Purpose: assign opcodes to the vendor-software pushbuttons by doing each single
action in a separate timed burst. Captured 5 min on \\.\USBPcap2 / dev addr 10.

source pcap:  $LOCALAPPDATA\Temp\dacal_label.pcap  (64 frames, 6 enum + 58 cmd)

Every response this session was ACK (device stayed up & ready). Confirmed:

  - Transport = GET_DESCRIPTOR STRING on EP0; STRING INDEX == opcode byte.
  - 0x0b RESET, 0x0c MOVE_TO, 0x0e RETRACT, 0x0f LED_ON, 0x10 LED_OFF,
    0x11 GET_STATUS — all match the README / DacalCommand enum exactly.
  - 0x05 = the MOVE_TO **slot-byte** argument (slot 5 -> 0x05), always sent
    immediately after 0x0c, matching DacalCodec.encodeSlot.
  - A move-to-slot is: RETRACT(0x0e) x2, then MOVE_TO(0x0c) + slot — the
    exact two-step the README describes.

Timeline (time -> command sequence):
  5.9s   GET_STATUS, RETRACT, LED_OFF(0x10)
  10.2s  GET_STATUS, RETRACT, LED_ON(0x0f)
  13.5s  GET_STATUS, RETRACT, LED_ON(0x0f)
  18.5s  GET_STATUS, RETRACT, RETRACT, MOVE_TO(0x0c)+slot(0x05)
  32.0s  GET_STATUS, RETRACT, RETRACT, MOVE_TO(0x0c)+slot(0x05)
  35.9s  GET_STATUS, RETRACT, RETRACT, MOVE_TO(0x0c)+slot(0x05)
  43.4s  GET_STATUS, RETRACT, RETRACT, MOVE_TO(0x0c)+slot(0x05)

Response framing on the HID transport: `LL 03 <token UTF-16LE>` where LL is the
descriptor bLength (= token byte count) and the 03 is the STRING descriptor
type. Identical status tokens to the serial form; the ONLY byte difference vs
the serial frame is position [1] (0x03 here vs 0x00 there). DacalCodec.decode
reads a 2-byte LE length from [0..1], so it must tolerate/strip the 0x03 type
byte for the HID transport.

Still undocumented: 0x04 (appeared in the 1st session returning BUSY; not seen
here). Not added to the enum pending its meaning.
