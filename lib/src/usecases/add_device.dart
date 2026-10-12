import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';
import 'id_generator.dart';
import 'list_devices.dart';
import 'new_meta.dart';

/// Register a new CD library machine.
///
/// Creates a [Device] carrying the machine's catalog identity ([manufacturer],
/// [sku], [model]), its unique [serialNumber], [capacity] and an optional
/// [name] / per-machine [serialConfig]. The library can hold many machines,
/// each identified by its serial number.
///
/// A blank [serialNumber] is refused with [InvalidInputFailure] and a serial
/// already used by another machine with [AlreadyExistsFailure]; [capacity]
/// must be positive. The machine's [Meta] is minted internally via [newMeta];
/// pass [idGenerator] to control the id (tests use a deterministic generator).
///
/// The serial is stored as the `serial_number` value of the `serializable`
/// trait (see [Device.traitAttributeValues]) and is retrievable that way on
/// every read.
class AddDevice {
  /// Creates an [AddDevice] use case.
  const AddDevice({
    required ILibraryRepository repository,
    IdGenerator? idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final ILibraryRepository _repository;
  final IdGenerator? _idGenerator;

  /// Executes the use case, returning the newly registered [Device].
  TaskEither<DecalFailure, Device> call({
    required String manufacturer,
    required String sku,
    required String model,
    required String serialNumber,
    required int capacity,
    String? name,
    SerialConfig? serialConfig,
  }) {
    if (serialNumber.trim().isEmpty) {
      return TaskEither.left(
        InvalidInputFailure('A machine must have a non-empty serial number'),
      );
    }
    if (capacity < 1) {
      return TaskEither.left(
        InvalidInputFailure('A machine must have a positive capacity'),
      );
    }
    return ListDevices(_repository).call().flatMap((devices) {
      final duplicate = devices.any((d) => d.serialNumber == serialNumber);
      if (duplicate) {
        return TaskEither.left(
          AlreadyExistsFailure(
            'A machine with serial "$serialNumber" is already registered',
          ),
        );
      }
      final device = Device(
        meta: newMeta(idGenerator: _idGenerator),
        manufacturer: manufacturer,
        sku: sku,
        model: model,
        serialNumber: serialNumber,
        capacity: capacity,
        name: name,
        serialConfig: serialConfig,
      );
      return _repository.saveDevice(device: device);
    });
  }
}
