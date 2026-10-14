import 'package:decalcd/decalcd.dart';
import 'package:test/test.dart';

import 'support/disc_factory.dart';
import 'support/device_factory.dart';

/// Locks the CD/DVD media-kind traits and their wiring onto [Disc]. A disc is
/// an instance of a SKU whose media kind (CD vs DVD) is expressed as a trait,
/// mirroring how a machine carries `serializable`/`hid`.
void main() {
  group('cd/dvd traits', () {
    test('are canonical classifications', () {
      expect(kDcCdTrait.name, 'cd');
      expect(kDcCdTrait.meta.id, 'dc:trait:cd');
      expect(kDcDvdTrait.name, 'dvd');
      expect(kDcDvdTrait.meta.id, 'dc:trait:dvd');
      // Registered in the canonical registry for JSON round-trip resolution.
      expect(kCanonicalTraits['cd'], kDcCdTrait);
      expect(kCanonicalTraits['dvd'], kDcDvdTrait);
    });
  });

  group('Disc media traits', () {
    Disc cd() => buildDisc('disc-cd', skuId: 'sku:cd');
    Disc dvd() => buildDisc('disc-dvd', skuId: 'sku:dvd', mediaTrait: kDcDvdTrait);

    test('a CD disc carries the cd + slottable traits and round-trips JSON', () {
      expect(cd().traits, {kDcCdTrait, kDcSlottableTrait});
      final back = Disc.fromJson(cd().toJson());
      expect(back.traits, {kDcCdTrait, kDcSlottableTrait});
      expect(back, cd());
    });

    test('a DVD disc carries the dvd + slottable traits and round-trips JSON', () {
      expect(dvd().traits, {kDcDvdTrait, kDcSlottableTrait});
      final back = Disc.fromJson(dvd().toJson());
      expect(back.traits, {kDcDvdTrait, kDcSlottableTrait});
      expect(back, dvd());
    });

    test('a disc with no media SKU loads and persists as empty', () {
      final disc = Disc(meta: catMeta('disc-bare'), skuId: 'sku:bare', name: '');
      expect(disc.traits, isEmpty);
      final back = Disc.fromJson(disc.toJson());
      expect(back.traits, isEmpty);
      expect(back, disc);
    });
  });
}
