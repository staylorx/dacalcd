#!/usr/bin/env bash
# Decode a USBPcap capture of the Dacal HID device (Cypress 04B4:5A9B) into a
# command stream, shaped like DacalLoggingTransport: TX = host->device command
# bytes, RX = device->host response bytes, both as hex.
#
# Usage: decode_dacal_capture.sh <capture.pcap> [device_address=10]
# Requires tshark (Wireshark) on PATH or at C:/Program Files/Wireshark/tshark.exe.
set -u
CAP="${1:?usage: decode_dacal_capture.sh <capture.pcap> [addr]}"
ADDR="${2:-10}"
TSHARK="$(command -v tshark 2>/dev/null || echo '/c/Program Files/Wireshark/tshark.exe')"

echo "# Decoding $CAP (device address $ADDR)"
echo "# seq dir bytes"
printf '#%04d TX %s\n' 0 '<-- SET_REPORT (control EP0) + interrupt IN EP0x81 reports -->' 2>/dev/null || true

n=0
TSHARK="$TSHARK"
# Interrupt IN endpoint 0x81 payloads = RX (device -> host)
"$TSHARK" -r "$CAP" -Y "usb.device_address == $ADDR and usb.endpoint_address == 0x81" \
  -T fields -e frame.number -e data.data 2>/dev/null | while IFS=$'\t' read -r f d; do
  [ -n "$d" ] || continue
  printf '#%04d RX %s\n' "$f" "$(echo "$d" | tr -d ':')"
done

# Control transfers OUT (SET_REPORT / feature reports) = TX (host -> device)
"$TSHARK" -r "$CAP" -Y "usb.device_address == $ADDR and usb.endpoint_address == 0 and usb.transfer_type == 2" \
  -T fields -e frame.number -e data.data 2>/dev/null | while IFS=$'\t' read -r f d; do
  [ -n "$d" ] || continue
  printf '#%04d TX %s\n' "$f" "$(echo "$d" | tr -d ':')"
done
