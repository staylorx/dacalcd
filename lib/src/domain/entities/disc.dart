import 'package:equatable/equatable.dart';

import 'meta.dart';

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

  /// Creates a [Disc].
  const Disc({
    required this.meta,
    required this.skuId,
    this.label,
    this.serialNumber,
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'sku_id': skuId,
    'label': label,
    'serial_number': serialNumber,
  };

  /// Creates a [Disc] from snake_case JSON.
  factory Disc.fromJson(Map<String, dynamic> json) => Disc(
    meta: Meta.fromJson(json),
    skuId: json['sku_id'] as String? ?? '',
    label: json['label'] as String?,
    serialNumber: json['serial_number'] as String?,
  );

  @override
  List<Object?> get props => [meta, skuId, label, serialNumber];
}
