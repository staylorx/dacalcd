import 'package:equatable/equatable.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

/// Immutable identity + timestamp record carried by every persistent entity.
class Meta extends Equatable {
  /// Opaque identifier. The library stores, returns and compares it and never
  /// parses, orders, or does arithmetic on it.
  final String id;

  /// Freeform notes.
  final String notes;

  /// UTC ISO-8601 creation timestamp.
  final String createdAt;

  /// UTC ISO-8601 last-update timestamp.
  final String updatedAt;

  /// Creates a [Meta].
  const Meta({
    required this.id,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    'id': id,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  /// Parses a [Meta] from a snake_case JSON record.
  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    id: json['id'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
  );

  @override
  List<Object?> get props => [id, notes, createdAt, updatedAt];
}

/// The boundary between decalcd's own identity record and the catalog's.
///
/// Catalog entities ([cat.Instance], [cat.Sku]) carry `cat.Meta`; decalcd's
/// own entities ([Slot], ...) carry this one. The two meet wherever a use case
/// touches both — most visibly when a [Disc] (now a catalog instance) is built
/// alongside decalcd-side records.
extension CatalogMeta on Meta {
  /// This identity as the catalog's [cat.Meta].
  cat.Meta get asCatalog => cat.Meta(
    id: id,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
