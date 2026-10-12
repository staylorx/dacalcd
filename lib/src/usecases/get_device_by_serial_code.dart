import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Get a device by its unique serial code.
class GetDeviceBySerialCode {
  /// Creates a [GetDeviceBySerialCode] use case.
  const GetDeviceBySerialCode(this._repository);

  final ILibraryRepository _repository;

  /// Executes the use case.
  TaskEither<DecalFailure, Device> call({required String serialCode}) =>
      _repository.fetchDeviceBySerialCode(serialCode: serialCode);
}
