import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:test/test.dart';

void main() {
  Meta meta(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  group('Given a Device', () {
    test('Then it round-trips its serial code and capacity through JSON', () {
      final device = Device(
        meta: meta('dev-1'),
        serialCode: '67808',
        skuId: 'decal-150',
        capacity: 150,
        name: 'Carousel',
      );

      final back = Device.fromJson(device.toJson());
      back.serialCode.should.be('67808');
      back.skuId.should.be('decal-150');
      back.capacity.should.be(150);
      back.name.should.be('Carousel');
    });
  });

  group('Given a Disc', () {
    test('Then it round-trips its skuId through JSON', () {
      final disc = Disc(
        meta: meta('disc-1'),
        skuId: 'cd-sku-1',
        label: 'Label',
        serialNumber: 'SN-1',
      );
      final back = Disc.fromJson(disc.toJson());
      back.skuId.should.be('cd-sku-1');
      back.label.should.be('Label');
      back.serialNumber.should.be('SN-1');
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
        disc: Disc(meta: meta('d1'), skuId: 'cd-sku-1'),
      );
      full.isOccupied.should.be(true);
      full.isEmpty.should.be(false);
    });

    test('Then empty() clears the disc and copyWith sets it', () {
      final empty = Slot(meta: meta('s1'), deviceId: 'dev-1', slotNumber: 1);
      final disc = Disc(meta: meta('d1'), skuId: 'cd-sku-1');
      final full = empty.copyWith(disc: disc);
      full.isOccupied.should.be(true);
      full.disc?.meta.id.should.be('d1');

      final cleared = full.empty();
      cleared.isOccupied.should.be(false);
      cleared.disc.should.beNull();
    });
  });
}
