import 'package:equatable/equatable.dart';

import 'meta.dart';
import 'trait.dart';

/// A typed attribute definition belonging to a [Trait].
///
/// Mirrors the sku_catalog model's trait-attribute concept: a [Trait] groups
/// one or more [TraitAttributeDefinition]s, and an entity that carries the
/// trait stores a value for each attribute key it defines. The data model
/// uses this to capture serial numbers generically — [kSerialNumberTraitAttribute]
/// is the `serial_number` trait attribute on the [kSerializableTrait].
class TraitAttributeDefinition extends Equatable {
  /// Identity + timestamp metadata.
  final Meta meta;

  /// Id of the owning [Trait].
  final String traitId;

  /// Machine key of the attribute (e.g. `'serial_number'`).
  final String key;

  /// Human-readable display label (e.g. `'Serial Number'`).
  final String displayLabel;

  /// Creates a [TraitAttributeDefinition].
  const TraitAttributeDefinition({
    required this.meta,
    required this.traitId,
    required this.key,
    required this.displayLabel,
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    ...meta.toJson(),
    'trait_id': traitId,
    'key': key,
    'display_label': displayLabel,
  };

  /// Creates a [TraitAttributeDefinition] from snake_case JSON.
  factory TraitAttributeDefinition.fromJson(Map<String, dynamic> json) =>
      TraitAttributeDefinition(
        meta: Meta.fromJson(json),
        traitId: json['trait_id'] as String? ?? '',
        key: json['key'] as String? ?? '',
        displayLabel: json['display_label'] as String? ?? '',
      );

  @override
  List<Object?> get props => [meta, traitId, key, displayLabel];
}

/// Canonical id of the `serial_number` trait attribute definition.
const String kSerialNumberTraitAttributeId = 'trait_attribute:serial_number';

/// The canonical `serial_number` trait attribute, hanging off the
/// [kSerializableTrait].
///
/// The trait attribute's [key] is [kSerialNumberTraitAttributeKey]
/// (`'serial_number'`) and its [traitId] is the [kSerializableTrait]'s id
/// ([kSerializableTraitId]), so any entity that carries the serializable
/// trait exposes its serial number generically under this attribute.
const TraitAttributeDefinition kSerialNumberTraitAttribute =
    TraitAttributeDefinition(
      meta: Meta(
        id: kSerialNumberTraitAttributeId,
        notes: '',
        createdAt: '',
        updatedAt: '',
      ),
      traitId: kSerializableTraitId,
      key: kSerialNumberTraitAttributeKey,
      displayLabel: 'Serial Number',
    );
