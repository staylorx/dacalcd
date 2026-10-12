import 'package:equatable/equatable.dart';

import 'meta.dart';

/// A named classification that can be attached to a domain entity.
///
/// Traits capture *kinds* of identity generically: instead of every entity
/// hard-coding its own notion of, say, "has a serial number", that notion is
/// expressed as a [Trait] (this one: [kSerializableTrait]) carrying typed
/// trait attributes (see [TraitAttributeDefinition]) whose values are read
/// per entity. The Decal CD library uses this to model each CD library
/// machine as [kSerializableTrait]: its serial number is the
/// [kSerialNumberTraitAttributeKey] trait-attribute value.
class Trait extends Equatable {
  /// Identity + timestamp metadata.
  final Meta meta;

  /// Machine name of the trait (e.g. `'serializable'`).
  final String name;

  /// Creates a [Trait].
  const Trait({required this.meta, required this.name});

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {...meta.toJson(), 'name': name};

  /// Creates a [Trait] from snake_case JSON.
  factory Trait.fromJson(Map<String, dynamic> json) => Trait(
    meta: Meta.fromJson(json),
    name: json['name'] as String? ?? '',
  );

  @override
  List<Object?> get props => [meta, name];
}

/// Canonical name of the trait an entity carries when it is serializable —
/// i.e. its identity includes a serial number captured generically as a trait
/// attribute value.
const String kSerializableTraitName = 'serializable';

/// Canonical trait-attribute key under which a serial number is stored on a
/// [kSerializableTrait] entity. This is the `trait_attribute` of
/// `serial_number` referenced by the data model.
const String kSerialNumberTraitAttributeKey = 'serial_number';

/// Canonical id of the "serializable" trait. Referenced by both the trait
/// and its trait attributes, so the linkage holds without const-eval chains.
const String kSerializableTraitId = 'trait:serializable';

/// The canonical "serializable" trait.
///
/// A CD library machine is serializable: its identity is its serial number
/// (e.g. `'67808'`), captured generically via the
/// [kSerialNumberTraitAttributeKey] trait attribute (see
/// [kSerialNumberTraitAttribute]).
const Trait kSerializableTrait = Trait(
  meta: Meta(id: kSerializableTraitId, notes: '', createdAt: '', updatedAt: ''),
  name: kSerializableTraitName,
);
