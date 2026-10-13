# Dacal USB capture — session 2026-10-12 (observed command stream)

Captured via USBPcap on \\.\USBPcap2, device address 10 (Cypress 04B4:5A9B,
"Dacal CD/DVD Library D-101/DC-300/DC-016RW"), while driving the original
vendor software through: device off / device on / go to slot / load disk /
unload disk.

Transport discovered: this unit is a HID-class Cypress CY7C64225 bridge, NOT a
CDC virtual-COM. Commands travel as GET_DESCRIPTOR STRING control transfers on
EP0 where the STRING INDEX == the opcode byte; the device answers with a string
descriptor whose payload is the two-byte length + UTF-16LE status token
(0c 03 … = "ERROR", 0a 03 … = "BUSY", 08 03 41 00 43 00 4b 00 = "ACK").

source pcap:  $LOCALAPPDATA\Temp\dacal_session.pcap  (46 frames, incl 6 enum)

  # : string idx = opcode  ->  status        time (s)  burst
  1 : 0x11 (GET_STATUS)    ->  ERROR        23.43     (A)
  2 : 0x0b (RESET)         ->  ACK          23.43     (A)
  3 : 0x11 (GET_STATUS)    ->  ERROR        42.50     (B)
  4 : 0x0b (RESET)         ->  ACK          42.50     (B)
  5 : 0x11 (GET_STATUS)    ->  ERROR        52.46     (C)
  6 : 0x0b (RESET)         ->  ACK          52.46     (C)
  7 : 0x0c (MOVE_TO)       ->  ACK          52.46     (C)
  8 : 0x04 (??)            ->  BUSY         52.46     (C)
  9 : 0x11 (GET_STATUS)    ->  ERROR        67.43     (D)
 10 : 0x0b (RESET)         ->  ACK          67.43     (D)
 11 : 0x0e (RETRACT)       ->  BUSY         68.44     (E)
 12 : 0x0e (RETRACT)       ->  BUSY         68.44     (E)
 13 : 0x0c (MOVE_TO)       ->  ACK          68.44     (E)
 14 : 0x04 (??)            ->  BUSY         68.44     (E)
 15 : 0x11 (GET_STATUS)    ->  ERROR        95.21     (F)
 16 : 0x0b (RESET)         ->  ACK          95.21     (F)
 17 : 0x11 (GET_STATUS)    ->  ACK          117.38    (G)
 18 : 0x0e (RETRACT)       ->  ACK          117.38    (G)
 19 : 0x0c (MOVE_TO)       ->  ACK          117.38    (G)
 20 : 0x05 (slot arg)      ->  ACK          117.38    (G)

Observed opcode vocabulary: {0x04, 0x05, 0x0b, 0x0c, 0x0e, 0x11}.

Matches README: 0x0b RESET, 0x0c MOVE_TO, 0x0e RETRACT, 0x11 GET_STATUS.
NEW / undocumented: 0x04 (returns BUSY), 0x05 (returns ACK; strong candidate
for the MOVE_TO slot-number byte — see the 0x0c,0x05 pairing in burst G).

Open question to label precisely: which raw index maps to each pushbutton
(device off / on / go-to-slot / load / unload). Recommend a per-action capture
(one single action per window) to assign each index to a button name.
