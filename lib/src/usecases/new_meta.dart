import 'dart:math';

import '../domain/domain.dart';
import 'id_generator.dart';

/// Builds a fresh [Meta] with a random id and the current UTC timestamp.
///
/// Use case internals that construct entities share this so every write path
/// gets consistent created/updated stamps without depending on the UI ring.
///
/// Pass [idGenerator] to mint the id your own way; the default is a random
/// UUID v4.
Meta newMeta({String notes = '', IdGenerator? idGenerator}) {
  final now = DateTime.now().toUtc().toIso8601String();
  final id = (idGenerator ?? _uuid4)();
  return Meta(id: id, notes: notes, createdAt: now, updatedAt: now);
}

String _uuid4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex({required int start, required int end}) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(start: 0, end: 4)}-${hex(start: 4, end: 6)}-'
      '${hex(start: 6, end: 8)}-${hex(start: 8, end: 10)}-'
      '${hex(start: 10, end: 16)}';
}
