import 'package:equatable/equatable.dart';

import 'disc.dart';
import 'meta.dart';

/// One position in a [Device]'s carousel that can hold a [Disc].
///
/// [slotNumber] is unique per owning device (1..capacity). A slot is either
/// empty ([disc] is null) or occupied by exactly one disc.
class Slot extends Equatable {
  /// Creation metadata.
  final Meta meta;

  /// Id of the owning [Device].
  final String deviceId;

  /// Slot number, unique within the owning device (1..capacity).
  final int slotNumber;

  /// The [Disc] currently in this slot, or null when it is empty.
  final Disc? disc;

  /// Creates a [Slot].
  const Slot({
    required this.meta,
    required this.deviceId,
    required this.slotNumber,
    this.disc,
  });

  /// Whether this slot is occupied.
  bool get isOccupied => disc != null;

  /// Whether this slot is empty.
  bool get isEmpty => disc == null;

  /// Creates a copy with a new [disc].
  ///
  /// Nullable fields cannot be set to null through a plain copyWith, so a
  /// separate [empty] clears the disc.
  Slot copyWith({Meta? meta, String? deviceId, int? slotNumber, Disc? disc}) =>
      Slot(
        meta: meta ?? this.meta,
        deviceId: deviceId ?? this.deviceId,
        slotNumber: slotNumber ?? this.slotNumber,
        disc: disc ?? this.disc,
      );

  /// Returns a copy of this slot with its disc removed.
  Slot empty() =>
      Slot(meta: meta, deviceId: deviceId, slotNumber: slotNumber, disc: null);

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'device_id': deviceId,
    'slot_number': slotNumber,
    'disc': disc?.toJson(),
  };

  /// Creates a [Slot] from snake_case JSON.
  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    meta: Meta.fromJson(json),
    deviceId: json['device_id'] as String? ?? '',
    slotNumber: _slotNumberFromWire(value: json['slot_number']),
    disc: json['disc'] is Map<String, dynamic>
        ? Disc.fromJson(json['disc'] as Map<String, dynamic>)
        : null,
  );

  @override
  List<Object?> get props => [meta, deviceId, slotNumber, disc];
}

int _slotNumberFromWire({required Object? value}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
