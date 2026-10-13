import 'package:decalcd/decalcd.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;
import 'package:test/test.dart';

/// Proves the decalcd ↔ sku_catalog bridge: machines and discs are catalog
/// `Sku`s carrying the real shared traits, and the physical carousel is an
/// [Instance] of the machine SKU. This is the foundation slice of the
/// "adopt sku_catalog" migration — classification now lives in the shared
/// package, not decalcd's local mirror.
void main() {
  cat.Meta meta(String id) => cat.Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  group('catalog traits', () {
    test('hid/serializable/cd/dvd are sku_catalog sku-scoped Trait records', () {
      expect(kDcHidTrait.name, 'hid');
      expect(kDcSerializableTrait.name, 'serializable');
      expect(kDcCdTrait.name, 'cd');
      expect(kDcDvdTrait.name, 'dvd');
      for (final t in [kDcHidTrait, kDcSerializableTrait, kDcCdTrait, kDcDvdTrait]) {
        expect(t.scope, [cat.TraitScope.sku]);
      }
    });
  });

  group('Dacal machine SKU', () {
    test('carries hid + serializable traits and capacity attribute', () {
      final machine = dacalMachineSku(
        meta: meta('sku:dc300'),
        modelNumber: 'DC-300',
        capacity: 150,
      );
      expect(machine.traitIds, containsAll([kDcHidTrait.meta.id, kDcSerializableTrait.meta.id]));
      expect(machine.attributeValues['capacity'], 150);
      expect(machine.roundTrips(), isTrue);
    });
  });

  group('disc SKUs', () {
    test('a CD disc carries the cd trait; a DVD disc carries the dvd trait', () {
      final cd = discSku(meta: meta('sku:media-cd'), mediaTrait: kDcCdTrait, modelNumber: 'cd');
      final dvd = discSku(meta: meta('sku:media-dvd'), mediaTrait: kDcDvdTrait, modelNumber: 'dvd');
      expect(cd.traitIds, containsAll([kDcCdTrait.meta.id, kDcSlottableTrait.meta.id]));
      expect(dvd.traitIds, containsAll([kDcDvdTrait.meta.id, kDcSlottableTrait.meta.id]));
      expect(cd.roundTrips(), isTrue);
      expect(dvd.roundTrips(), isTrue);
    });
  });

  group('physical machine instance', () {
    test('an Instance of the machine SKU carries the per-unit serial', () {
      final machine = dacalMachineSku(meta: meta('sku:dc300'), modelNumber: 'DC-300');
      final unit = machineInstance(
        meta: meta('instance:67808'),
        skuId: machine.meta.id,
        name: 'CD Library II',
        serialNumber: '67808',
      );
      expect(unit.skuId, machine.meta.id);
      expect(unit.serialNumber, '67808');
      expect(unit.roundTrips(), isTrue);
    });
  });
}

extension on cat.Sku {
  bool roundTrips() => cat.Sku.fromJson(toJson()) == this;
}

extension on cat.Instance {
  bool roundTrips() => cat.Instance.fromJson(toJson()) == this;
}
