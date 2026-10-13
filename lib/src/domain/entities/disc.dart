import 'package:equatable/equatable.dart';

import 'meta.dart';
import 'trait.dart';

/// A CD/DVD held by the library — a catalog [Sku].
///
/// A disc is a SKU (the CD or DVD as a product model). The correlation between
/// a carousel slot and the disc it holds is expressed by a [Slot] referencing
/// a [Disc], and the library leans on the catalog's SkuAssociation links to
/// relate discs to the media they carry.
class Disc extends Equatable {
  /// Creation metadata.
  final Meta meta;

  /// Id of the catalog [Sku] this disc instantiates.
  ///
  /// For a CD carousel, the discs are CD/DVD SKUs — distinct from the carousel
  /// SKU itself.
  final String skuId;

  /// Optional physical label / barcode printed on the media.
  final String? label;

  /// Optional disc-specific serial number.
  final String? serialNumber;

  /// Media-kind traits this disc carries: a CD disc is [kCdTrait], a DVD is
  /// [kDvdTrait]. The media kind of a disc is expressed as a trait, mirroring
  /// how a machine carries `serializable`/`hid`.
  final Set<Trait> traits;

  /// Creates a [Disc].
  const Disc({
    required this.meta,
    required this.skuId,
    this.label,
    this.serialNumber,
    this.traits = const {},
  });

  /// Trait-attribute values keyed by attribute key. Empty today — a disc's
  /// media kind is a trait, not a trait attribute value — present for symmetry
  /// with [Device] so trait-driven attributes can be added later.
  Map<String, dynamic> get traitAttributeValues => const {};

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'sku_id': skuId,
    'label': label,
    'serial_number': serialNumber,
    'traits': [for (final t in traits) t.name],
  };

  /// Creates a [Disc] from snake_case JSON.
  factory Disc.fromJson(Map<String, dynamic> json) => Disc(
    meta: Meta.fromJson(json),
    skuId: json['sku_id'] as String? ?? '',
    label: json['label'] as String?,
    serialNumber: json['serial_number'] as String?,
    traits: (json['traits'] as List<dynamic>?)
            ?.map((n) => _resolveTrait(n.toString()))
            .toSet() ??
        const {},
  );

  @override
  List<Object?> get props => [meta, skuId, label, serialNumber, traits];
}

/// Resolves a persisted trait name to its canonical [Trait], falling back to a
/// generic [Trait] when the name is not one of the known classifications.
Trait _resolveTrait(String name) =>
    kCanonicalTraits[name] ??
    Trait(meta: Meta(id: 'trait:$name', notes: '', createdAt: '', updatedAt: ''), name: name);

