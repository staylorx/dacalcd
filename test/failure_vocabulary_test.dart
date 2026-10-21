import 'package:decalcd/decalcd.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;
import 'package:test/test.dart';

/// Locks decalcd's half of sku_catalog 4.0.0's failure vocabulary: the root is
/// **shared and open** (a product extends it), and our family is a **sibling** of
/// the catalog's closed set rather than a translation into it.
void main() {
  group('Given the shared failure root', () {
    test('Then every DecalFailure IS a catalog DomainFailure', () {
      final failures = <DecalFailure>[
        const NotFoundFailure('device "dev-1" not found'),
        const AlreadyExistsFailure('serial "67808" is taken'),
        const InvalidInputFailure('blank serial'),
        const InUseFailure('disc is placed'),
        const StorageFailure('store broke'),
      ];

      for (final failure in failures) {
        failure.should.beAssignableTo<cat.DomainFailure>();
      }
    });

    test('Then the catalog set and our set are siblings, not members', () {
      // Sharing a root is not the same as belonging to the other's set: a
      // catalog failure is not one of decalcd's.
      const fromCatalog = cat.NotFoundFailure('sku "x" not found');
      fromCatalog.should.not.beAssignableTo<DecalFailure>();
    });

    test('Then message and equality come from the root', () {
      const a = NotFoundFailure('device "dev-1" not found');
      const b = NotFoundFailure('device "dev-1" not found');
      const other = NotFoundFailure('device "dev-2" not found');

      a.message.should.be('device "dev-1" not found');
      a.props.should.be(['device "dev-1" not found']);
      a.should.be(b);
      a.should.not.be(other);
    });

    test('Then our set stays closed: the switch needs no default', () {
      // Exhaustive with no default, which only compiles while DecalFailure is
      // sealed — decalcd's counterpart of the catalog's `CatalogFailure`.
      String describe(DecalFailure failure) => switch (failure) {
        NotFoundFailure() => 'not found',
        AlreadyExistsFailure() => 'duplicate',
        InvalidInputFailure() => 'invalid',
        InUseFailure() => 'in use',
        StorageFailure() => 'storage',
      };

      describe(const StorageFailure('x')).should.be('storage');
      describe(const NotFoundFailure('x')).should.be('not found');
    });
  });
}
