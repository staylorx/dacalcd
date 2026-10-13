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

/// Canonical trait-attribute key under which a serial number is stored on a
/// serializable entity. Kept here (a plain string) so `Device.traitAttributeValues`
/// and the storage/UI layers agree on the key without a mirror entity.
const String kSerialNumberTraitAttributeKey = 'serial_number';

/// Canonical trait-attribute key under which a disc's occupied slot number is
/// stored on a slottable entity. A slot is an attribute **value** (placement is
/// an instance fact, not connection wiring), so it hangs off the `slottable`
/// trait on the disc [Instance] rather than being a sidecar.
const String kSlotNumberTraitAttributeKey = 'slot_number';

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

/// The canonical `serial_number` trait attribute, hanging off
/// [kDcSerializableTrait] — the real sku_catalog definition.
const cat.TraitAttributeDefinition kDcSerialNumberTraitAttribute =
    cat.TraitAttributeDefinition(
      meta: cat.Meta(
        id: 'dc:trait_attribute:serial_number',
        notes: '',
        createdAt: '',
        updatedAt: '',
      ),
      traitId: 'dc:trait:serializable',
      key: kSerialNumberTraitAttributeKey,
      displayLabel: 'Serial Number',
      dataType: cat.DataType.string,
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

/// The `slottable` trait: a SKU whose physical instances can occupy a slot in a
/// CD library machine. Applies to disc media SKUs — a disc (the SKU) is
/// *classifiable* as slottable, while the concrete slot number is an attribute
/// **value** on each disc [Instance] (see [discInstance]).
const cat.Trait kDcSlottableTrait = cat.Trait(
  meta: cat.Meta(
    id: 'dc:trait:slottable',
    notes: '',
    createdAt: '',
    updatedAt: '',
  ),
  name: 'slottable',
  scope: [cat.TraitScope.sku],
);

/// The canonical `slot_number` trait attribute, hanging off
/// [kDcSlottableTrait]. An int whose value — placed on a disc [Instance] —
/// is the slot (1..capacity) that physical disc occupies.
const cat.TraitAttributeDefinition kDcSlotNumberTraitAttribute =
    cat.TraitAttributeDefinition(
      meta: cat.Meta(
        id: 'dc:trait_attribute:slot_number',
        notes: '',
        createdAt: '',
        updatedAt: '',
      ),
      traitId: 'dc:trait:slottable',
      key: kSlotNumberTraitAttributeKey,
      displayLabel: 'Slot Number',
      dataType: cat.DataType.number,
    );

/// Registry of every canonical trait by name, used to resolve a persisted
/// trait name back to its canonical [cat.Trait] on load (see `Disc.fromJson`).
const Map<String, cat.Trait> kCanonicalTraits = {
  'serializable': kDcSerializableTrait,
  'hid': kDcHidTrait,
  'cd': kDcCdTrait,
  'dvd': kDcDvdTrait,
  'slottable': kDcSlottableTrait,
};

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
/// carrying the `cd` or `dvd` media trait and the `slottable` trait (its
/// physical copies can occupy a slot; see [discInstance]).
cat.Sku discSku({
  required cat.Meta meta,
  required cat.Trait mediaTrait,
  required String modelNumber,
}) =>
    cat.Sku(
      meta: meta,
      manufacturerId: '',
      modelNumber: modelNumber,
      traitIds: [mediaTrait.meta.id, kDcSlottableTrait.meta.id],
    );

/// A physical disc in the library — an [Instance] of a disc [Sku] (see
/// [discSku]).
///
/// The SKU is the media class (a CD "Album X" — kind + slottable); this is the
/// individual article. Its placement is an attribute value: when the disc is in
/// a slot, its `slot_number` value (the `slottable` trait attribute) holds
/// `1..capacity`. A disc with no `slot_number` is currently not loaded in a
/// slot.
cat.Instance discInstance({
  required cat.Meta meta,
  required String skuId,
  required String name,
  int? slotNumber,
}) =>
    cat.Instance(
      meta: meta,
      skuId: skuId,
      locateId: null,
      name: name,
      attributeValues: {
        kSlotNumberTraitAttributeKey: ?slotNumber,
      },
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
