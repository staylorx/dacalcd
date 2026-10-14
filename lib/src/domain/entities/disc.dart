import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../catalog/dacal_catalog.dart';

/// A physical CD/DVD held by the library — the catalog's disc [cat.Instance],
/// not a parallel model.
///
/// decalcd's old `Disc` re-declared its identity (`skuId`, `label`,
/// `serialNumber`, `traits`) alongside the shared `sku_catalog` model — facts
/// that belong on the media *SKU* and the disc *instance*. Under the
/// catalog-backed model each lives where the catalog puts it:
///
/// * the media class (a CD "Album X" — its `cd`/`dvd` classification, its
///   `slottable` classification and its model number) is a disc [cat.Sku]
///   (see [discSku]);
/// * the individual article — this disc — is a [cat.Instance] of that SKU.
///
/// Slotting a disc **is** that reification: a disc that occupies a slot is an
/// instance carrying its `slot_number` attribute value (see
/// [kSlotNumberTraitAttributeKey]) — placement is a value on the instance, so
/// the disc has to be an instance in order to take one.
///
/// This class **is** that instance and adds only the reference to its media
/// [discSku], so [traits] and the media kind read as projections of the SKU
/// rather than stored duplicates.
class Disc extends cat.Instance {
  /// Creates a [Disc] — a disc [cat.Instance] of [discSku].
  Disc({
    required super.meta,
    required super.skuId,
    super.locateId,
    required super.name,
    super.skuModelNumber,
    super.serialNumber,
    super.imageIds = const [],
    super.traitIds = const [],
    super.attributeValues = const {},
    super.icon,
    this.discSku,
  });

  /// The media SKU this disc instantiates, when loaded. The media kind and
  /// classification below project from it — never stored duplicates.
  final cat.Sku? discSku;

  /// The physical label / barcode printed on the media — the instance's own
  /// display name (null when the disc is unnamed).
  String? get label => name.isEmpty ? null : name;

  /// The slot (`1..capacity`) this disc currently occupies — the value of its
  /// `slot_number` attribute (see [kSlotNumberTraitAttributeKey]). Null when
  /// the disc is not slotted.
  int? get slotNumber =>
      (attributeValues[kSlotNumberTraitAttributeKey] as num?)?.toInt();

  /// Whether this disc currently occupies a slot.
  bool get isSlotted => slotNumber != null;

  /// The media-kind + classification traits this disc carries, projected from
  /// [discSku]: a CD disc is [kDcCdTrait], a DVD is [kDcDvdTrait], and every
  /// disc SKU is [kDcSlottableTrait].
  Set<cat.Trait> get traits => {
    for (final id in discSku?.traitIds ?? const <String>[])
      ?kCanonicalTraitsById[id],
  };

  /// Returns a copy of this disc placed in [slotNumber] — or, when
  /// [slotNumber] is null, cleared of its placement. The instance's identity
  /// ([meta], [name], [serialNumber]) is untouched: slotting is a value on the
  /// disc, not a different disc.
  Disc withSlot(int? slotNumber) {
    // The spread carries the existing values, so clearing has to *remove* the
    // key rather than omit a fresh entry.
    final values = {...attributeValues};
    if (slotNumber == null) {
      values.remove(kSlotNumberTraitAttributeKey);
    } else {
      values[kSlotNumberTraitAttributeKey] = slotNumber;
    }
    return Disc(
      meta: meta,
      skuId: skuId,
      locateId: locateId,
      name: name,
      skuModelNumber: skuModelNumber,
      serialNumber: serialNumber,
      imageIds: imageIds,
      traitIds: traitIds,
      attributeValues: values,
      icon: icon,
      discSku: discSku,
    );
  }

  /// This disc as its bare catalog [cat.Instance] — the identity half, with no
  /// decal-side additions. The storage adapter writes this to the shared
  /// instance store alongside the machine instances (see
  /// `SembastLibraryRepository`).
  cat.Instance toInstance() => cat.Instance(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name,
    skuModelNumber: skuModelNumber,
    serialNumber: serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
  );

  /// Builds a [Disc] from its catalog parts — a disc [cat.Instance] and its
  /// media [cat.Sku]. Inverse of [toInstance]; the storage adapter uses it to
  /// reassemble a disc that was persisted across the catalog stores.
  factory Disc.fromParts({required cat.Instance instance, cat.Sku? discSku}) =>
      Disc(
        meta: instance.meta,
        skuId: instance.skuId,
        locateId: instance.locateId,
        name: instance.name,
        skuModelNumber: instance.skuModelNumber,
        serialNumber: instance.serialNumber,
        imageIds: instance.imageIds,
        traitIds: instance.traitIds,
        attributeValues: instance.attributeValues,
        icon: instance.icon,
        discSku: discSku,
      );

  /// Serializes the disc as one blob — its catalog instance fields plus its
  /// embedded media [discSku].
  ///
  /// The catalog-backed storage adapter writes the instance and the SKU to
  /// their own stores; this single-blob form is kept for the legacy-record
  /// migration and for value-level round-trip tests.
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (discSku != null) json['disc_sku'] = discSku!.toJson();
    return json;
  }

  /// Creates a [Disc] from a snake_case record — the catalog instance fields
  /// via [cat.Instance.fromJson] plus an optional embedded media [discSku].
  ///
  /// A legacy blob that predates the catalog split (no `disc_sku`) is
  /// backfilled: its old `label` becomes the instance name and its old `traits`
  /// names resolve to a synthesised media SKU, so classification still lands on
  /// a SKU rather than on the instance.
  factory Disc.fromJson(Map<String, dynamic> json) {
    var instance = cat.Instance.fromJson(json);

    // Pre-catalog blobs stored the printable label under `label`.
    final legacyLabel = json['label'] as String?;
    if (instance.name.isEmpty && (legacyLabel?.isNotEmpty ?? false)) {
      instance = instance.copyWith(name: legacyLabel);
    }

    cat.Sku? sku;
    final skuJson = json['disc_sku'];
    if (skuJson is Map<String, dynamic> && skuJson.isNotEmpty) {
      sku = cat.Sku.fromJson(skuJson);
    } else if (instance.skuId.isNotEmpty) {
      final names =
          (json['traits'] as List<dynamic>?)
              ?.map((n) => n.toString())
              .where(kCanonicalTraits.containsKey)
              .toSet() ??
          const <String>{};
      final media = names.contains('dvd')
          ? kDcDvdTrait
          : (names.contains('cd') ? kDcCdTrait : null);
      if (media != null) {
        sku = dacalDiscSku(
          skuId: instance.skuId,
          mediaTrait: media,
          modelNumber: instance.name.isEmpty ? instance.skuId : instance.name,
        );
      }
    }

    return Disc.fromParts(instance: instance, discSku: sku);
  }

  @override
  List<Object?> get props => [...super.props, discSku];
}
