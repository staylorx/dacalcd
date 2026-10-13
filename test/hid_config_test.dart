import 'package:decalcd/decalcd.dart';
import 'package:test/test.dart';

/// Locks the reverse-engineered USB/HID connection facts into the core model
/// (captured live via USBPcap, see docs/usb-capture-session-*.md) so the
/// knowledge survives and any future HID transport can open this exact unit.
void main() {
  group('HidConfig', () {
    test('round-trips JSON with every captured connection fact', () {
      final info = HidConfig.dacal;
      final back = HidConfig.fromJson(info.toJson());
      expect(back, info);

      // Cypress CY7C64225 HID-UART bridge.
      expect(back.transportKind, kHidTransportStringDescriptor);
      expect(back.vid, 0x04b4);
      expect(back.pid, 0x5a9b);

      // Bus-level identity from the captures.
      expect(back.busFilter, r'\\\\.\\USBPcap2');
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

  group('Device.hidConfig', () {
    // A CD library machine is a SKU classified `hid`; the concrete connection
    // detail is a first-class HidConfig entity held as a property of the
    // Device instance, mirroring serialConfig — not a trait-attribute value.
    Device deviceWithHid() => Device(
      meta: Meta(
        id: 'device-67808',
        notes: '',
        createdAt: '2026-01-01T00:00:00.000Z',
        updatedAt: '2026-01-01T00:00:00.000Z',
      ),
      manufacturer: 'Dacal',
      sku: 'DC-300',
      model: 'CD Library II',
      serialNumber: '67808',
      capacity: 150,
    ).copyWithHidConfig(HidConfig.dacal);

    test('survives Device JSON round-trip', () {
      final device = deviceWithHid();
      final back = Device.fromJson(device.toJson());
      expect(back.hidConfig, HidConfig.dacal);
      final without = Device.fromJson(device.toJson()
        ..remove('hid_config'));
      expect(without.hidConfig, isNull);
    });

    test('copyWithHidConfig sets the connection per instance', () {
      final base = deviceWithHid();
      expect(base.hidConfig, HidConfig.dacal);
      expect(base.copyWithHidConfig(null).hidConfig, isNull);
      // Traits untouched: the instance's classification does not gain traits
      // from carrying a connection config.
      expect(base.traits, {kDcSerializableTrait});
    });
  });

  group('hid trait', () {
    test('a CD library SKU carries the hid trait (connection on the instance)',
        () {
      expect(kDcHidTrait.name, 'hid');
      expect(kDcHidTrait.meta.id, 'dc:trait:hid');
      // The SKU is classified `hid`; the concrete connection detail is a
      // HidConfig field on the Device instance (like serialConfig).
      const info = HidConfig.dacal;
      expect(info.transportKind, kHidTransportStringDescriptor);
    });
  });
}
