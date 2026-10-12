import 'package:equatable/equatable.dart';

import 'meta.dart';

/// A physical Decal CD carousel: the machine that holds the discs.
///
/// Each machine is unique by [serialCode] (for example `'67808'` on the unit
/// this library was written against). The carousel itself is a catalog [Sku]
/// (e.g. Manufacturer `Decal`, model `whatever-150`) whose total CD count is a
/// trait attribute; see [skuId] and [capacity].
class Device extends Equatable {
  /// Creation metadata.
  final Meta meta;

  /// Serial code unique to this physical machine (e.g. `'67808'`).
  final String serialCode;

  /// Id of the catalog [Sku] that models this carousel model.
  ///
  /// The CD carousel is itself a SKU in the catalog; the CD/DVD discs are
  /// other SKUs. That is the skuassociation seam the catalog leans on.
  final String skuId;

  /// Total number of CD slots on this machine (e.g. `150`), the trait
  /// attribute on the carousel SKU.
  final int capacity;

  /// Optional display name.
  final String? name;

  /// Creates a [Device].
  const Device({
    required this.meta,
    required this.serialCode,
    required this.skuId,
    required this.capacity,
    this.name,
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'serial_code': serialCode,
    'sku_id': skuId,
    'capacity': capacity,
    'name': name,
  };

  /// Creates a [Device] from snake_case JSON.
  factory Device.fromJson(Map<String, dynamic> json) => Device(
    meta: Meta.fromJson(json),
    serialCode: json['serial_code'] as String? ?? '',
    skuId: json['sku_id'] as String? ?? '',
    capacity: _intFromWire(value: json['capacity']),
    name: json['name'] as String?,
  );

  @override
  List<Object?> get props => [meta, serialCode, skuId, capacity, name];
}

int _intFromWire({required Object? value}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
