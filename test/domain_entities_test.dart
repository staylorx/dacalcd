import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

import 'support/device_factory.dart';
import 'support/disc_factory.dart';

void main() {
  Meta meta(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  group('Given a Device', () {
    test('Then it round-trips machine fields and JSON', () {
      final device = buildDevice(
        'dev-1',
        serial: '67808',
        capacity: 150,
        name: 'Carousel',
        serialConfig: const SerialConfig(portName: 'COM3', baudRate: 9600),
        demoMode: true,
      );

      final back = Device.fromJson(device.toJson());
      back.manufacturer.should.be('Dacal');
      back.sku.should.be('DC-300');
      back.model.should.be('CD Library II');
      back.serialNumber.should.be('67808');
      back.capacity.should.be(150);
      back.name.should.be('Carousel');
      back.serialConfig?.portName.should.be('COM3');
      back.serialConfig?.baudRate.should.be(9600);
      back.demoMode.should.be(true);
    });

    test('Then it carries the serializable trait with the serial_number attribute',
        () {
      final device = buildDevice(
        'dev-1',
        serial: '67808',
        capacity: 150,
      );

      device.traits.map((t) => t.name).should.contain(
        kDcSerializableTrait.name,
      );
      (device.traitAttributeValues['serial_number'] as String).should
          .be('67808');
      (device.traitAttributeValues[kSerialNumberTraitAttributeKey] as String)
          .should
          .be('67808');
      Device
          .traitAttributeDefinitions
          .map((a) => a.key)
          .should
          .contain('serial_number');
      // The pair is sku_catalog's own (SerializableTrait.define): a
      // *unique* string attribute of a sku-scoped classification.
      kDcSerializableTrait.scope.should.be([TraitScope.sku]);
      kDcSerialNumberTraitAttribute.isUnique.should.beTrue();
      kDcSerialNumberTraitAttribute.dataType.should.be(DataType.string);
    });

    test('Then multiple machines coexist with distinct serials and models',
        () {
      final a = buildDevice(
        'm1',
        manufacturer: 'Dacal',
        sku: 'DC-300',
        model: 'CD Library II',
        serial: '67808',
        capacity: 150,
      );
      final b = buildDevice(
        'm2',
        manufacturer: 'Primera',
        sku: 'PF-600',
        model: 'CD Library III',
        serial: '9999',
        capacity: 300,
      );

      final machines = [a, b];
      machines.map((m) => m.serialNumber).should.be(['67808', '9999']);
      machines.map((m) => m.model).should.be(['CD Library II', 'CD Library III']);
      machines.expand((m) => m.traits).map((t) => t.name).should.be([
        kDcSerializableTrait.name,
        kDcSerializableTrait.name,
      ]);
    });
  });

  group('Given a Disc', () {
    test('Then it round-trips its skuId through JSON', () {
      final disc = buildDisc(
        'disc-1',
        skuId: 'cd-sku-1',
        name: 'Label',
        serialNumber: 'SN-1',
      );
      final back = Disc.fromJson(disc.toJson());
      back.skuId.should.be('cd-sku-1');
      back.label.should.be('Label');
      back.serialNumber.should.be('SN-1');
    });

    test('Then slotting it records the slot as an attribute value', () {
      final disc = buildDisc('disc-1', slotNumber: 4);
      disc.slotNumber.should.be(4);
      disc.isSlotted.should.be(true);
      Disc.fromJson(disc.toJson()).slotNumber.should.be(4);

      disc.withSlot(null).isSlotted.should.be(false);
    });
  });

  group('Given a Slot', () {
    test('Then it reports empty and occupied correctly', () {
      final empty = Slot(meta: meta('s1'), deviceId: 'dev-1', slotNumber: 1);
      empty.isEmpty.should.be(true);
      empty.isOccupied.should.be(false);

      final full = Slot(
        meta: meta('s2'),
        deviceId: 'dev-1',
        slotNumber: 2,
        disc: buildDisc('d1'),
      );
      full.isOccupied.should.be(true);
      full.isEmpty.should.be(false);
    });

    test('Then empty() clears the disc and copyWith sets it', () {
      final empty = Slot(meta: meta('s1'), deviceId: 'dev-1', slotNumber: 1);
      final disc = buildDisc('d1');
      final full = empty.copyWith(disc: disc);
      full.isOccupied.should.be(true);
      full.disc?.meta.id.should.be('d1');

      final cleared = full.empty();
      cleared.isOccupied.should.be(false);
      cleared.disc.should.beNull();
    });
  });
}
