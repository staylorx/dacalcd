import 'package:decalcd/decalcd.dart';
import 'package:test/test.dart';

/// Locks the reverse-engineered USB/HID connection facts into the core model
/// (captured live via USBPcap, see docs/usb-capture-session-*.md) so the
/// knowledge survives and any future HID transport can open this exact unit.
void main() {
  group('HidConnectionInfo', () {
    test('round-trips JSON with every captured connection fact', () {
      final info = HidConnectionInfo.dacal;
      final back = HidConnectionInfo.fromJson(info.toJson());
      expect(back, info);

      // Cypress CY7C64225 HID-UART bridge.
      expect(back.transportKind, kHidTransportStringDescriptor);
      expect(back.vid, 0x04b4);
      expect(back.pid, 0x5a9b);

      // Bus-level identity from the captures.
      expect(back.busFilter, r'\\.\USBPcap2');
      expect(back.deviceAddress, 10);

      // Endpoint + framing.
      expect(back.interruptInEndpoint, 0x81);
      expect(back.reportSize, 3);
      expect(back.pollInterval, 10);

      // Command = string-descriptor index on a GET_DESCRIPTOR control transfer.
      expect(back.opcodeViaStringIndex, isTrue);
      expect(back.stringLanguageId, 0x0409);

      expect(back.statusTokens, kDacalStatusTokens);
    });

    test('keeps the TX direction as an open seam (unproven)', () {
      expect(const HidTxInfo().mechanism, 'unproven');
      final back = HidTxInfo.fromJson(const HidTxInfo().toJson());
      expect(back.mechanism, 'unproven');
      expect(back.note, isNotEmpty);
    });
  });

  group('hid trait', () {
    test('a CD library SKU carries the hid trait (connection on the instance)',
        () {
      expect(kHidTrait.name, 'hid');
      expect(kHidTraitId, 'trait:hid');
      // The SKU is classified `hid`; the concrete connection detail is a
      // HidConnectionInfo field on the Device instance (like serialConfig).
      const info = HidConnectionInfo.dacal;
      expect(info.transportKind, kHidTransportStringDescriptor);
    });
  });
}
