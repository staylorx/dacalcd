import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// Get a single CD library machine by its opaque id.
///
/// Returns [NotFoundFailure] when no machine has [id].
class GetDeviceById {
  /// Creates a [GetDeviceById] use case.
  const GetDeviceById(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, Device> call({required String id}) =>
      _repository.fetchDeviceById(id: id);
}
