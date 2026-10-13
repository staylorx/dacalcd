import 'package:fpdart/fpdart.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';
import 'id_generator.dart';
import 'list_devices.dart';
import 'new_meta.dart';

/// Register a new CD library machine.
///
/// Creates the machine's catalog model — a machine [cat.Sku] carrying its
/// identity ([manufacturer], [sku]/model number, [model], [capacity]) and the
/// physical machine as an [cat.Instance] of that SKU ([serialNumber], [name]) —
/// and returns it as a [Device] (the instance plus its per-machine [serialConfig]).
///
/// A blank [serialNumber] is refused with [InvalidInputFailure] and a serial
/// already used by another machine with [AlreadyExistsFailure]; [capacity]
/// must be positive. The machine's [Meta] is minted internally via [newMeta];
/// pass [idGenerator] to control the id (tests use a deterministic generator).
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
      final minted = newMeta(idGenerator: _idGenerator);
      final catMeta = cat.Meta(
        id: minted.id,
        notes: minted.notes,
        createdAt: minted.createdAt,
        updatedAt: minted.updatedAt,
      );
      final machineSku = dacalMachineSku(
        meta: catMeta,
        modelNumber: sku,
        capacity: capacity,
      ).copyWith(
        attributeValues: {
          'capacity': capacity,
          'model': model,
          'manufacturer': manufacturer,
        },
      );
      final device = Device(
        meta: catMeta,
        skuId: machineSku.meta.id,
        name: name ?? model,
        serialNumber: serialNumber,
        machineSku: machineSku,
        serialConfig: serialConfig,
      );
      return _repository.saveDevice(device: device);
    });
  }
}
