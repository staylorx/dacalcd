import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Delete a single CD library machine.
///
/// Removes the machine identified by [deviceId] and, in the same storage
/// step, all of its slots (cascade) so a deleted machine leaves no orphaned
/// records. Returns [NotFoundFailure] when no machine has [deviceId].
class DeleteDevice {
  /// Creates a [DeleteDevice] use case.
  const DeleteDevice(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, void> call({required String deviceId}) =>
      _repository.deleteDevice(id: deviceId);
}
