import 'package:decalcd/decalcd.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import 'device_factory.dart';

/// Builds a disc the catalog-backed way: a media SKU (a CD by default) with
/// [skuId], instantiated as a [Disc] carrying [id].
///
/// Mirrors `buildDevice`: tests construct the catalog parts (SKU + instance)
/// rather than a parallel disc model.
Disc buildDisc(
  String id, {
  String skuId = 'cd-sku-1',
  String name = '',
  String? serialNumber,
  int? slotNumber,
  cat.Trait mediaTrait = kDcCdTrait,
}) {
  final sku = dacalDiscSku(
    skuId: skuId,
    mediaTrait: mediaTrait,
    modelNumber: name.isEmpty ? skuId : name,
  );
  return Disc(
    meta: catMeta(id),
    skuId: sku.meta.id,
    name: name,
    serialNumber: serialNumber,
    attributeValues: {kSlotNumberTraitAttributeKey: ?slotNumber},
    discSku: sku,
  );
}
