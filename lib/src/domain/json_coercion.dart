/// Returns a `Map<String, dynamic>` view of [value], or `{}` if [value] is not
/// a map.
///
/// Defensive parse of legacy records that may be null, primitives, or lists.
Map<String, dynamic> asStringMap({required Object? value}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// Converts a wire list of strings into a typed [List<String>].
///
/// Returns an empty list when [value] is missing or malformed.
List<String> stringListFromWire({required Object? value}) =>
    (value as List?)?.cast<String>() ?? <String>[];
