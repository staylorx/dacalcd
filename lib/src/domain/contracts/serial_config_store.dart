import 'package:fpdart/fpdart.dart';

import '../entities/serial_config.dart';
import '../failures/decal_failures.dart';

/// Contract for persisting the serial [SerialConfig] between app runs.
///
/// Implement this over a config file, shared_preferences, or any
/// key/value store. Every method returns an FP-style tuple and never throws:
/// a storage fault is surfaced as a [StorageFailure] value so callers can
/// switch on it like any other [DecalFailure].
abstract interface class ISerialConfigStore {
  /// Loads the saved config, or `null` when none has been saved yet.
  TaskEither<DecalFailure, SerialConfig?> load();

  /// Persists [config] so the next app run can restore it.
  TaskEither<DecalFailure, void> save(SerialConfig config);
}
