import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../catalog/dacal_catalog.dart';
import 'hid_config.dart';
import 'machine_config.dart';
import 'serial_config.dart';

/// A physical CD library machine — the catalog's machine [cat.Instance], not a
/// parallel model.
///
/// decalcd's old `Device` re-declared its identity (`manufacturer`, `sku`,
/// `model`, `capacity`, `serialNumber`) alongside the shared `sku_catalog`
/// model — duplicated facts that would drift apart and cost us later to
/// converge. Under the catalog-backed model those live in exactly one place:
/// the physical machine is an [Instance] of a machine [Sku] (see
/// [dacalMachineSku]). This class **is** that instance and adds only what is
/// genuinely decalcd's:
///
/// * a reference to its machine [machineSku], so consumers keep reading
///   `sku`/`manufacturer`/`model`/`capacity` as convenient projections of the
///   SKU (no stored copy of them);
/// * the typed per-unit connection wiring ([hidConfig], [serialConfig],
///   [demoMode]) — serial/HID connection detail is a first-class domain
///   entity, not a trait-attribute value, and is persisted to the config
///   sidecar keyed by this instance's id (see [SembastMachineConfigRepository]).
///
/// Every machine is [kDcSerializableTrait]: its serial number is captured
/// generically on that trait (see [traitAttributeValues]).
class Device extends cat.Instance {
  /// Creates a [Device] — a machine [cat.Instance] plus its connection wiring.
  Device({
    required super.meta,
    required super.skuId,
    super.locateId,
    required super.name,
    super.serialNumber,
    super.imageIds = const [],
    super.traitIds = const [],
    super.attributeValues = const {},
    super.icon,
    this.machineSku,
    this.hidConfig,
    this.serialConfig,
    this.demoMode = false,
  });

  /// The trait attributes that capture a CD library machine's identity.
  static const List<cat.TraitAttributeDefinition> traitAttributeDefinitions = [
    kDcSerialNumberTraitAttribute,
  ];

  /// The machine's catalog SKU, when loaded. Identity projections below
  /// (`sku`, `manufacturer`, `model`, `capacity`) read from it — they are
  /// conveniences over the single source of truth, never stored duplicates.
  final cat.Sku? machineSku;

  /// Per-machine USB/HID connection details (Cypress CY7C64225 HID-UART
  /// bridge, VID 0x04b4 / PID 0x5a9b) reverse-engineered from live USBPcap
  /// captures. A first-class domain entity held as a property of the machine
  /// instance, not a trait-attribute value.
  final HidConfig? hidConfig;

  /// Per-machine serial-port connection details (e.g. `COM3` at 9600 baud).
  final SerialConfig? serialConfig;

  /// Per-machine demo mode flag (fall back to simulated hardware when no
  /// physical machine can be detected). A machine in demo mode typically has
  /// no [serialConfig].
  final bool demoMode;

  /// The machine SKU / model number (e.g. `'DC-300'`), projected from
  /// [machineSku].
  String get sku => machineSku?.modelNumber ?? '';

  /// Manufacturer display name, projected from [machineSku] (the human-facing
  /// name, falling back to the catalog manufacturer id when unset).
  String get manufacturer =>
      (machineSku?.attributeValues['manufacturer'] as String?) ??
      machineSku?.manufacturerId ??
      '';

  /// Marketing model name, projected from [machineSku] (falls back to the
  /// model number when no marketing name is stored).
  String get model =>
      (machineSku?.attributeValues['model'] as String?) ??
      machineSku?.modelNumber ??
      '';

  /// Total number of CD slots on this machine (e.g. `150`), projected from the
  /// [machineSku] `capacity` attribute.
  int get capacity =>
      (machineSku?.attributeValues['capacity'] as num?)?.toInt() ?? 0;

  /// Returns a copy of this machine with a new per-machine [serialConfig].
  Device copyWithSerialConfig(SerialConfig? serialConfig) => Device(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name,
    serialNumber: serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
    machineSku: machineSku,
    hidConfig: hidConfig,
    serialConfig: serialConfig,
    demoMode: demoMode,
  );

  /// Returns a copy of this machine with a new per-machine [hidConfig].
  Device copyWithHidConfig(HidConfig? hidConfig) => Device(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name,
    serialNumber: serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
    machineSku: machineSku,
    hidConfig: hidConfig,
    serialConfig: serialConfig,
    demoMode: demoMode,
  );

  /// Returns a copy of this machine with the per-machine [demoMode] flag set.
  Device copyWithDemoMode(bool demoMode) => Device(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name,
    serialNumber: serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
    machineSku: machineSku,
    hidConfig: hidConfig,
    serialConfig: serialConfig,
    demoMode: demoMode,
  );

  /// Rebuilds this machine with a (typically timestamp-refreshed) instance
  /// [meta] and optional field updates; any omitted field is carried over.
  ///
  /// The connection triples ([serialConfig], [hidConfig], [demoMode]) and
  /// [machineSku] use `??` semantics, so pass an explicit value to change one.
  Device rebuild({
    required cat.Meta meta,
    String? serialNumber,
    String? name,
    Object? serialConfig = _unset,
    Object? hidConfig = _unset,
    bool? demoMode,
    cat.Sku? machineSku,
  }) => Device(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name ?? this.name,
    serialNumber: serialNumber ?? this.serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
    machineSku: machineSku ?? this.machineSku,
    hidConfig: identical(hidConfig, _unset)
        ? this.hidConfig
        : hidConfig as HidConfig?,
    serialConfig: identical(serialConfig, _unset)
        ? this.serialConfig
        : serialConfig as SerialConfig?,
    demoMode: demoMode ?? this.demoMode,
  );

  /// The traits this machine carries. A CD library machine is
  /// [kDcSerializableTrait]: its serial number is exposed generically.
  Set<cat.Trait> get traits => {kDcSerializableTrait};

  /// Sentinel meaning "carry over the current value" for the connection fields
  /// below (so an explicit `null` can clear a config, matching `?? null ->
  /// unchanged` not applying to connection state).
  static const Object _unset = Object();

  /// Trait-attribute values keyed by attribute key. The serial number is the
  /// `serial_number` value on the `serializable` trait.
  Map<String, dynamic> get traitAttributeValues =>
      {kSerialNumberTraitAttributeKey: serialNumber};

  /// This machine as its bare catalog [cat.Instance] — the identity half of a
  /// machine, with no decal-side connection config. The storage adapter writes
  /// this to the shared instance store; the machine [cat.Sku] goes to the SKU
  /// store and the connection config to the sidecar (see [config]).
  cat.Instance toInstance() => cat.Instance(
    meta: meta,
    skuId: skuId,
    locateId: locateId,
    name: name,
    serialNumber: serialNumber,
    imageIds: imageIds,
    traitIds: traitIds,
    attributeValues: attributeValues,
    icon: icon,
  );

  /// The decal-side connection config for this machine — the sidecar value
  /// keyed by [meta]'s id (see [MachineConfig]). Holds the transport wiring
  /// sku_catalog's classification model deliberately does not.
  MachineConfig get config => MachineConfig(
    instanceId: meta.id,
    hidConfig: hidConfig,
    serialConfig: serialConfig,
    demoMode: demoMode,
  );

  /// Builds a [Device] from its catalog parts — a machine [cat.Instance], its
  /// machine [machineSku] and its sidecar [config]. Inverse of [toInstance]
  /// (+ [config]); the storage adapter uses it to reassemble a machine that was
  /// persisted across the catalog and sidecar stores.
  factory Device.fromParts({
    required cat.Instance instance,
    cat.Sku? machineSku,
    MachineConfig? config,
  }) => Device(
    meta: instance.meta,
    skuId: instance.skuId,
    locateId: instance.locateId,
    name: instance.name,
    serialNumber: instance.serialNumber,
    imageIds: instance.imageIds,
    traitIds: instance.traitIds,
    attributeValues: instance.attributeValues,
    icon: instance.icon,
    machineSku: machineSku,
    hidConfig: config?.hidConfig,
    serialConfig: config?.serialConfig,
    demoMode: config?.demoMode ?? false,
  );

  /// Serializes the machine as one blob — its catalog instance fields plus the
  /// decal connection config and its embedded machine [SKU].
  ///
  /// The catalog-backed storage adapter no longer stores this blob: it writes
  /// the instance, SKU and config to their own stores (see [toInstance] and
  /// [config]). This single-blob form is kept for the legacy-record migration
  /// (schema v2) and for value-level round-trip tests.
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['demo_mode'] = demoMode;
    if (serialConfig != null) json['serial_config'] = serialConfig!.toJson();
    if (hidConfig != null) json['hid_config'] = hidConfig!.toJson();
    if (machineSku != null) json['machine_sku'] = machineSku!.toJson();
    return json;
  }

  /// Creates a [Device] from a snake_case record — the catalog instance fields
  /// via [cat.Instance.fromJson] plus connection config and an optional
  /// embedded [machineSku]. A legacy blob that lacks `machine_sku` is backfilled
  /// from its old parallel identity fields (`sku`/`model`/`capacity`).
  factory Device.fromJson(Map<String, dynamic> json) {
    final instance = cat.Instance.fromJson(json);
    cat.Sku? sku;
    final skuJson = json['machine_sku'];
    if (skuJson is Map<String, dynamic> && skuJson.isNotEmpty) {
      sku = cat.Sku.fromJson(skuJson);
    } else {
      final legacySku = json['sku'] as String? ?? '';
      final legacyModel = json['model'] as String? ?? '';
      final legacyManufacturer = json['manufacturer'] as String? ?? '';
      if (legacySku.isNotEmpty) {
        final legacyCapacity = _intFromWire(value: json['capacity']);
        sku = dacalMachineSku(
          meta: cat.Meta(
            id: 'dc:sku:machine:${instance.meta.id}',
            notes: '',
            createdAt: '',
            updatedAt: '',
          ),
          modelNumber: legacySku,
          manufacturerModelNumber: legacyModel.isNotEmpty ? legacyModel : null,
          capacity: legacyCapacity,
        ).copyWith(
          attributeValues: {
            'capacity': legacyCapacity,
            if (legacyModel.isNotEmpty) 'model': legacyModel,
            if (legacyManufacturer.isNotEmpty) 'manufacturer': legacyManufacturer,
          },
        );
      }
    }
    return Device(
      meta: instance.meta,
      skuId: instance.skuId,
      locateId: instance.locateId,
      name: instance.name,
      serialNumber: instance.serialNumber,
      imageIds: instance.imageIds,
      traitIds: instance.traitIds,
      attributeValues: instance.attributeValues,
      icon: instance.icon,
      machineSku: sku,
      serialConfig: json['serial_config'] is Map<String, dynamic>
          ? SerialConfig.fromJson(json['serial_config'] as Map<String, dynamic>)
          : null,
      hidConfig: json['hid_config'] is Map<String, dynamic>
          ? HidConfig.fromJson(json['hid_config'] as Map<String, dynamic>)
          : null,
      demoMode: json['demo_mode'] == true,
    );
  }

  @override
  List<Object?> get props => [
    meta,
    skuId,
    locateId,
    name,
    skuModelNumber,
    serialNumber,
    imageIds,
    traitIds,
    attributeValues,
    icon,
    machineSku,
    hidConfig,
    serialConfig,
    demoMode,
  ];
}

int _intFromWire({required Object? value}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

