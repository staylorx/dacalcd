import 'package:equatable/equatable.dart';

import 'meta.dart';
import 'serial_config.dart';
import 'trait.dart';
import 'trait_attribute_definition.dart';

/// A physical CD library machine (the carousel that holds the discs).
///
/// This is the library's machine type — e.g. a Dacal "CD Library II"
/// (SKU `DC-300`) with serial number `'67808'` at this site. Each machine is
/// identified by its [serialNumber] and modelled as a catalog SKU: the
/// instance fields [manufacturer], [sku], [model] and [capacity] describe
/// the machine model, while [serialNumber] is unique to this physical unit.
///
/// The library can manage **multiple** machines — the repository returns a
/// `List<Device>` (see `ILibraryRepository.fetchDevices`) and each machine
/// carries its own per-unit serial-port/comm connection in [serialConfig],
/// so connection details are per machine rather than a single app-wide port.
///
/// Every machine is [kSerializableTrait]: its serial number is captured
/// generically as the [kSerialNumberTraitAttributeKey] trait-attribute value
/// on the `serializable` trait (see [traitAttributeValues]).
class Device extends Equatable {
  /// The trait attributes that capture a CD library machine's identity.
  static const List<TraitAttributeDefinition> traitAttributeDefinitions = [
    kSerialNumberTraitAttribute,
  ];

  /// Creation metadata.
  final Meta meta;

  /// Manufacturer of the machine (e.g. `'Dacal'`).
  final String manufacturer;

  /// Manufacturer SKU / model number (e.g. `'DC-300'`).
  final String sku;

  /// Marketing model name (e.g. `'CD Library II'`).
  final String model;

  /// Serial number unique to this physical machine (e.g. `'67808'`).
  final String serialNumber;

  /// Total number of CD slots on this machine (e.g. `150`), the trait
  /// attribute on the carousel SKU.
  final int capacity;

  /// Optional display name.
  final String? name;

  /// Per-machine serial-port/comm connection details (e.g. `COM3` at 9600
  /// baud). One per CD library machine — never a single app-wide port.
  final SerialConfig? serialConfig;

  /// Creates a [Device].
  const Device({
    required this.meta,
    required this.manufacturer,
    required this.sku,
    required this.model,
    required this.serialNumber,
    required this.capacity,
    this.name,
    this.serialConfig,
  });

  /// Returns a copy of this machine with a new per-machine [serialConfig].
  ///
  /// Connection details belong to a single machine (one serial port per CD
  /// library machine), so it is set per instance rather than app-wide.
  Device copyWithSerialConfig(SerialConfig? serialConfig) => Device(
    meta: meta,
    manufacturer: manufacturer,
    sku: sku,
    model: model,
    serialNumber: serialNumber,
    capacity: capacity,
    name: name,
    serialConfig: serialConfig,
  );

  /// The traits this machine carries. A CD library machine is
  /// [kSerializableTrait]: its serial number is exposed generically.
  Set<Trait> get traits => {kSerializableTrait};

  /// Trait-attribute values keyed by attribute key. The serial number is the
  /// `serial_number` value on the `serializable` trait.
  Map<String, dynamic> get traitAttributeValues =>
      {kSerialNumberTraitAttributeKey: serialNumber};

  /// Converts to JSON with snake_case keys. The serial number is stored both
  /// as the typed `serial_number` field and as the `serial_number`
  /// trait-attribute value on the `serializable` trait.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'manufacturer': manufacturer,
    'sku': sku,
    'model': model,
    'serial_number': serialNumber,
    'capacity': capacity,
    'name': name,
    'traits': [for (final t in traits) t.name],
    'trait_attribute_values': traitAttributeValues,
    if (serialConfig != null) 'serial_config': serialConfig!.toJson(),
  };

  /// Creates a [Device] from snake_case JSON.
  factory Device.fromJson(Map<String, dynamic> json) => Device(
    meta: Meta.fromJson(json),
    manufacturer: json['manufacturer'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    model: json['model'] as String? ?? '',
    serialNumber: json['serial_number'] as String? ?? '',
    capacity: _intFromWire(value: json['capacity']),
    name: json['name'] as String?,
    serialConfig: json['serial_config'] is Map<String, dynamic>
        ? SerialConfig.fromJson(json['serial_config'] as Map<String, dynamic>)
        : null,
  );

  @override
  List<Object?> get props => [
    meta,
    manufacturer,
    sku,
    model,
    serialNumber,
    capacity,
    name,
    serialConfig,
  ];
}

int _intFromWire({required Object? value}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
