import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// List all known devices.
class ListDevices {
  /// Creates a [ListDevices] use case.
  const ListDevices(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, List<Device>> call() => _repository.fetchDevices();
}
