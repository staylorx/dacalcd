import 'package:decalcd/decalcd.dart';
import 'package:test/test.dart';

/// Locks the CD/DVD media-kind traits and their wiring onto [Disc]. A disc is
/// a SKU whose media kind (CD vs DVD) is expressed as a trait, mirroring how a
/// machine carries `serializable`/`hid`.
void main() {
  Meta metaFor(String id) => Meta(
    id: id,
    notes: '',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  group('cd/dvd traits', () {
    test('are canonical classifications', () {
      expect(kCdTrait.name, 'cd');
      expect(kCdTraitId, 'trait:cd');
      expect(kDvdTrait.name, 'dvd');
      expect(kDvdTraitId, 'trait:dvd');
      // Registered in the canonical registry for JSON round-trip resolution.
      expect(kCanonicalTraits['cd'], kCdTrait);
      expect(kCanonicalTraits['dvd'], kDvdTrait);
    });
  });

  group('Disc media traits', () {
    Disc cd() => Disc(
      meta: metaFor('disc-cd'),
      skuId: 'sku:cd',
      traits: {kCdTrait},
    );
    Disc dvd() => Disc(
      meta: metaFor('disc-dvd'),
      skuId: 'sku:dvd',
      traits: {kDvdTrait},
    );

    test('a CD disc carries the cd trait and round-trips JSON', () {
      expect(cd().traits, {kCdTrait});
      final back = Disc.fromJson(cd().toJson());
      expect(back.traits, {kCdTrait});
      expect(back, cd());
    });

    test('a DVD disc carries the dvd trait and round-trips JSON', () {
      expect(dvd().traits, {kDvdTrait});
      final back = Disc.fromJson(dvd().toJson());
      expect(back.traits, {kDvdTrait});
      expect(back, dvd());
    });

    test('a disc with no media trait loads and persists as empty', () {
      final disc = Disc(meta: metaFor('disc-bare'), skuId: 'sku:bare');
      expect(disc.traits, isEmpty);
      final back = Disc.fromJson(disc.toJson());
      expect(back.traits, isEmpty);
      expect(back, disc);
    });
  });
}
