import 'package:decalcd/src/domain/domain.dart';
import 'package:shouldly/shouldly.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;
import 'package:test/test.dart';

cat.Meta meta(String id) =>
    cat.Meta(id: id, notes: '', createdAt: '', updatedAt: '');

void main() {
  group('slottable disc model', () {
    test('a disc Sku is classified cd + slottable', () {
      final sku = discSku(
        meta: meta('dc:sku:disc:album-x'),
        mediaTrait: kDcCdTrait,
        modelNumber: 'Album X (CD)',
      );

      sku.traitIds.should.contain('dc:trait:cd');
      sku.traitIds.should.contain('dc:trait:slottable');
      sku.traitIds.length.should.be(2);
    });

    test('a dvd disc Sku is dvd + slottable', () {
      final sku = discSku(
        meta: meta('dc:sku:disc:film-y'),
        mediaTrait: kDcDvdTrait,
        modelNumber: 'Film Y (DVD)',
      );
      sku.traitIds.should.contain('dc:trait:dvd');
      sku.traitIds.should.contain('dc:trait:slottable');
    });

    test('a disc Instance in a slot carries its slot_number attribute value',
        () {
      final copy = discInstance(
        meta: meta('dc:instance:disc:copy-1'),
        skuId: 'dc:sku:disc:album-x',
        name: 'Album X',
        slotNumber: 12,
      );

      copy.skuId.should.be('dc:sku:disc:album-x');
      (copy.attributeValues[kSlotNumberTraitAttributeKey] as int).should.be(12);
    });

    test('a disc Instance with no slot has no slot_number value', () {
      final loose = discInstance(
        meta: meta('dc:instance:disc:copy-2'),
        skuId: 'dc:sku:disc:album-x',
        name: 'Album X',
      );
      loose.attributeValues.containsKey(kSlotNumberTraitAttributeKey)
          .should
          .beFalse();
    });

    test('slot_number attribute definition hangs off slottable as a number',
        () {
      kDcSlotNumberTraitAttribute.traitId.should.be('dc:trait:slottable');
      kDcSlotNumberTraitAttribute.key.should.be(kSlotNumberTraitAttributeKey);
      kDcSlotNumberTraitAttribute.dataType.should.be(cat.DataType.number);
    });
  });
}
