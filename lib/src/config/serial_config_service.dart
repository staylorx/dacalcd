import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Facade over [ISerialConfigStore] presenting the save/load operations the
/// app calls at the boundary.
///
/// The Flutter app wires a concrete store here (a [SerialConfigFileStore]
/// pointed at its application-support directory, or a shared_preferences
/// adapter); this service is the fixed API the app depends on, so swapping
/// the backing store never touches the UI. Methods return lazy fpdart
/// [TaskEither]s, matching the rest of the core's FP style.
class SerialConfigService {
  /// The store backing this service.
  final ISerialConfigStore store;

  /// Creates a service over [store].
  SerialConfigService(this.store);

  /// Loads the saved config, or `null` when none has been saved.
  TaskEither<DecalFailure, SerialConfig?> load() => store.load();

  /// Persists [config] so the next run can restore it.
  TaskEither<DecalFailure, void> save(SerialConfig config) =>
      store.save(config);
}
