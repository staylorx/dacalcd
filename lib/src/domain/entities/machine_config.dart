import 'package:equatable/equatable.dart';

import 'hid_config.dart';
import 'serial_config.dart';

/// The decal-side, per-machine connection configuration held in the sidecar.
///
/// The shared `sku_catalog` model carries a machine's *identity and
/// classification* (as a [cat.Sku] and its physical unit as an [Instance]) but
/// deliberately not its per-unit connection wiring: sku_catalog's trait /
/// attribute model is about classification, and the user ruled that stuffing
/// `hidConfig`/`serialConfig` into trait-attribute values would bend that
/// schema past Dart/OOP. So connection config is a decal domain value kept
/// beside the catalog — a **sidecar** keyed by the machine [Instance]'s id —
/// holding exactly what a machine instance needs to be driven: its transport
/// (HID and/or serial) settings and its demo-mode flag.
///
/// It is a plain value object (no behaviour, no storage). Reading and writing
/// it is through the sembast sidecar [SembastMachineConfigRepository].
class MachineConfig extends Equatable {
  /// The sku_catalog [Instance] id this config belongs to (e.g.
  /// `'dc:instance:67808'`). The sidecar is keyed by this.
  final String instanceId;

  /// Per-machine USB/HID connection details, when the unit is HID-driven.
  final HidConfig? hidConfig;

  /// Per-machine serial connection details, when the unit is serial-driven.
  final SerialConfig? serialConfig;

  /// Per-machine demo-mode flag (falls back to simulated hardware when no
  /// physical machine can be detected).
  final bool demoMode;

  /// Creates a [MachineConfig].
  const MachineConfig({
    required this.instanceId,
    this.hidConfig,
    this.serialConfig,
    this.demoMode = false,
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    'instance_id': instanceId,
    'demo_mode': demoMode,
    if (hidConfig != null) 'hid_config': hidConfig!.toJson(),
    if (serialConfig != null) 'serial_config': serialConfig!.toJson(),
  };

  /// Parses a [MachineConfig] from snake_case JSON, falling back to defaults
  /// when a field is missing.
  factory MachineConfig.fromJson(Map<String, dynamic> json) => MachineConfig(
    instanceId: json['instance_id'] as String? ?? '',
    demoMode: json['demo_mode'] == true,
    hidConfig: json['hid_config'] is Map<String, dynamic>
        ? HidConfig.fromJson(json['hid_config'] as Map<String, dynamic>)
        : null,
    serialConfig: json['serial_config'] is Map<String, dynamic>
        ? SerialConfig.fromJson(json['serial_config'] as Map<String, dynamic>)
        : null,
  );

  @override
  List<Object?> get props => [instanceId, hidConfig, serialConfig, demoMode];
}
