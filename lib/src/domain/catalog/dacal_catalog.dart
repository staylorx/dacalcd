/// Canonical catalog mapping for the Decal CD library — the bridge from
/// decalcd's domain onto the shared `sku_catalog` model.
///
/// decalcd does **not** ship its own catalog storage or Trait/Sku mirror:
/// classification (the `hid`/`serializable` traits on a machine, the
/// `cd`/`dvd` traits on a disc) lives in the shared `sku_catalog` package.
/// This module holds the canonical catalog objects for the machines and discs
/// this app manages.
///
/// `sku_catalog` ships models + repository contracts but **no storage** —
/// persistence is decalcd's job, so these records are ultimately read/written
/// through decalcd's own repository layer (see the catalog slice of the plan).
library;

import 'package:sku_catalog/sku_catalog.dart' as cat;

/// Id used for the owner [Manufacturer] of every CD library machine in the
/// catalog (`'Dacal'`).
const String kDcManufacturerId = 'dc:manufacturer:dacal';

/// The `hid` trait: a SKU that talks USB/HID. Applies to CD library machines
/// (see [dacalMachineSku]).
const cat.Trait kDcHidTrait = cat.Trait(
  meta: cat.Meta(id: 'dc:trait:hid', notes: '', createdAt: '', updatedAt: ''),
  name: 'hid',
  scope: [cat.TraitScope.sku],
);

/// The `serializable` trait: a SKU whose serial number is captured generically
/// via trait-attribute values.
const cat.Trait kDcSerializableTrait = cat.Trait(
  meta: cat.Meta(
    id: 'dc:trait:serializable',
    notes: '',
    createdAt: '',
    updatedAt: '',
  ),
  name: 'serializable',
  scope: [cat.TraitScope.sku],
);

/// The `cd` trait: a disc SKU whose media kind is a compact disc.
const cat.Trait kDcCdTrait = cat.Trait(
  meta: cat.Meta(id: 'dc:trait:cd', notes: '', createdAt: '', updatedAt: ''),
  name: 'cd',
  scope: [cat.TraitScope.sku],
);

/// The `dvd` trait: a disc SKU whose media kind is a DVD.
const cat.Trait kDcDvdTrait = cat.Trait(
  meta: cat.Meta(id: 'dc:trait:dvd', notes: '', createdAt: '', updatedAt: ''),
  name: 'dvd',
  scope: [cat.TraitScope.sku],
);

/// A CD library machine (e.g. a Dacal `DC-300`) as a catalog SKU — the *model*
/// class. It carries the `hid` + `serializable` traits as its classification
/// and a `capacity` trait attribute, exactly as the vendor catalog defines it.
///
/// The concrete physical unit at this site is an [Instance] of this Sku (see
/// [machineInstance]); the per-unit connection detail (serial/HID) stays as
/// typed decalcd-domain config on the machine instance, not as trait
/// attribute values.
cat.Sku dacalMachineSku({
  required cat.Meta meta,
  required String modelNumber,
  String? manufacturerModelNumber,
  int capacity = 150,
  List<String> extraTraitIds = const [],
}) =>
    cat.Sku(
      meta: meta,
      manufacturerId: kDcManufacturerId,
      modelNumber: modelNumber,
      manufacturerModelNumber: manufacturerModelNumber,
      traitIds: [
        kDcHidTrait.meta.id,
        kDcSerializableTrait.meta.id,
        ...extraTraitIds,
      ],
      attributeValues: {'capacity': capacity},
    );

/// A disc held by the library as a catalog SKU — a CD or DVD media SKU
/// carrying the `cd` or `dvd` trait (see [kDcCdTrait]/[kDcDvdTrait]).
cat.Sku discSku({
  required cat.Meta meta,
  required cat.Trait mediaTrait,
  required String modelNumber,
}) =>
    cat.Sku(
      meta: meta,
      manufacturerId: '',
      modelNumber: modelNumber,
      traitIds: [mediaTrait.meta.id],
    );

/// The physical machine at this site — an [Instance] of [dacalMachineSku].
///
/// The SKU is the class (\"a Dacal DC-300 CD library\"); this is the individual
/// article (serial `67808`). Everything true of the model lives on the SKU;
/// everything true of *this* unit (its serial, its location) lives here.
cat.Instance machineInstance({
  required cat.Meta meta,
  required String skuId,
  required String name,
  String? serialNumber,
  String? locateId,
}) =>
    cat.Instance(
      meta: meta,
      skuId: skuId,
      locateId: locateId,
      name: name,
      serialNumber: serialNumber,
    );
