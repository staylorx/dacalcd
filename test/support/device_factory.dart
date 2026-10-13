import 'package:decalcd/decalcd.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

/// Builds a [cat.Meta] with fixed timestamps — the catalog-side meta used by
/// the machine [cat.Instance] and its machine [cat.Sku].
cat.Meta catMeta(String id) => cat.Meta(
  id: id,
  notes: '',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
);

/// Builds a [Device] the catalog-backed way: a machine [cat.Sku] carrying the
/// `hid`/`serializable` traits (with `capacity`/`manufacturer`/`model` as
/// attribute *values*) plus a machine [cat.Instance] (this unit) whose serial
/// number lives on the `serializable` trait. Keeps test call sites readable and
/// independent of the exact SKU/Instance constructor shape.
Device buildDevice(
  String id, {
  String serial = '67808',
  int capacity = 150,
  String manufacturer = 'Dacal',
  String sku = 'DC-300',
  String? model = 'CD Library II',
  String? name,
  SerialConfig? serialConfig,
  HidConfig? hidConfig,
  bool demoMode = false,
}) {
  final machineSku =
      dacalMachineSku(
        meta: catMeta('dc:sku:machine:$id'),
        modelNumber: sku,
        capacity: capacity,
      ).copyWith(
        attributeValues: {
          'capacity': capacity,
          'manufacturer': manufacturer,
          if (model != null) 'model': model,
        },
      );
  return Device(
    meta: catMeta(id),
    skuId: machineSku.meta.id,
    name: name ?? model ?? sku,
    serialNumber: serial,
    machineSku: machineSku,
    serialConfig: serialConfig,
    hidConfig: hidConfig,
    demoMode: demoMode,
  );
}
