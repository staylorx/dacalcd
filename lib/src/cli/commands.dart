// Commands for the Decal CD library CLI. `part of` the cli.dart library so
// they share its imports and the LineWriter / DecalCliDeps types.

part of '../cli/cli.dart';

/// Folds a settled [Either] into an exit code + output: on a `Right` applies
/// [onOk] to the value; on a `Left` writes its message to [deps.err] and
/// returns 1.
Future<int> foldExit<T>(
  Either<DecalFailure, T> result,
  DecalCliDeps deps, {
  required FutureOr<int> Function(T value) onOk,
}) async {
  return result.fold((failure) {
    deps.err('error: ${failure.message}');
    return 1;
  }, (value) async => onOk(value));
}

/// Runs an fpdart task, folding its [Either] result through [foldExit].
Future<int> runTask<T>(
  TaskEither<DecalFailure, T> task,
  DecalCliDeps deps, {
  required FutureOr<int> Function(T value) onOk,
}) async => foldExit(await task.run(), deps, onOk: onOk);

/// Resolves a machine reference — an opaque id or a serial number — to the
/// matching [Device], trying the opaque-id lookup first and falling back to
/// the serial-number lookup.
Future<Either<DecalFailure, Device>> resolveDeviceByIdOrSerial(
  DecalCliDeps deps,
  String ref,
) async {
  final byId = await GetDeviceById(deps.library).call(id: ref).run();
  if (byId.isRight()) return byId;
  return GetDeviceBySerialCode(deps.library).call(serialCode: ref).run();
}

/// `decal devices` — list every known carousel device.
class ListDevicesCommand extends Command<int> {
  /// Creates the command bound to [deps].
  ListDevicesCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'devices';

  @override
  String get description => 'List all carousel devices known to the library.';

  @override
  Future<int> run() => runTask(
    _deps.service.listDevices(),
    _deps,
    onOk: (devices) {
      if (devices.isEmpty) {
        _deps.out('No devices.');
        return 0;
      }
      for (final device in devices) {
        _deps.out(
          '${device.serialNumber}  '
          '(id ${device.meta.id}, manufacturer ${device.manufacturer}, '
          'sku ${device.sku}, model ${device.model}, capacity '
          '${device.capacity})',
        );
      }
      return 0;
    },
  );
}

/// `decal device-info <id-or-serial>` — show one device's details.
class ShowDeviceCommand extends Command<int> {
  /// Creates the command bound to [deps].
  ShowDeviceCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'device-info';

  @override
  String get description =>
      'Show details for a carousel device, by id or serial code.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err('usage: decal device-info <id-or-serial>');
      return 1;
    }
    final device = await resolveDeviceByIdOrSerial(_deps, rest.first);
    return foldExit(
      device,
      _deps,
      onOk: (d) {
        _deps.out('Device ${d.serialNumber}');
        _deps.out('  id:           ${d.meta.id}');
        _deps.out('  manufacturer: ${d.manufacturer}');
        _deps.out('  sku:          ${d.sku}');
        _deps.out('  model:        ${d.model}');
        _deps.out('  serial:       ${d.serialNumber}');
        _deps.out('  capacity:     ${d.capacity}');
        if (d.name.isNotEmpty) _deps.out('  name:         ${d.name}');
        return 0;
      },
    );
  }
}

/// `decal device-add <manufacturer> <sku> <model> <serial> <capacity> [name]`
/// — register a new CD library machine.
class DeviceAddCommand extends Command<int> {
  /// Creates the command bound to [deps].
  DeviceAddCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'device-add';

  @override
  String get description =>
      'Register a new CD library machine (manufacturer, sku, model, '
          'serial, capacity, optional name).';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length < 5) {
      _deps.err(
        'usage: decal device-add <manufacturer> <sku> <model> '
        '<serial> <capacity> [name]',
      );
      return Future.value(1);
    }
    final capacity = parsePositiveInt(rest[4], _deps, 'capacity');
    if (capacity == null) return Future.value(1);
    final name = rest.length > 5 ? rest[5] : null;

    return runTask(
      AddDevice(repository: _deps.library).call(
        manufacturer: rest[0],
        sku: rest[1],
        model: rest[2],
        serialNumber: rest[3],
        capacity: capacity,
        name: name,
      ),
      _deps,
      onOk: (device) {
        _deps.out(
          'Registered machine ${device.serialNumber} '
          '(id ${device.meta.id}, model ${device.model}).',
        );
        return 0;
      },
    );
  }
}

/// `decal device-remove <id-or-serial>` — delete a machine and its slots.
class DeviceRemoveCommand extends Command<int> {
  /// Creates the command bound to [deps].
  DeviceRemoveCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'device-remove';

  @override
  String get description =>
      'Delete a CD library machine (and its slots), by id or serial.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err('usage: decal device-remove <id-or-serial>');
      return 1;
    }
    final device = await resolveDeviceByIdOrSerial(_deps, rest.first);
    return device.fold(
      (failure) {
        _deps.err('error: ${failure.message}');
        return 1;
      },
      (d) => runTask(
        DeleteDevice(_deps.library).call(deviceId: d.meta.id),
        _deps,
        onOk: (_) {
          _deps.out('Removed machine ${d.serialNumber} (id ${d.meta.id}).');
          return 0;
        },
      ),
    );
  }
}

/// `decal device-update <id-or-serial> [options]` — update a machine.
class DeviceUpdateCommand extends Command<int> {
  /// Creates the command bound to [deps].
  DeviceUpdateCommand(this._deps) {
    argParser
      ..addOption('manufacturer')
      ..addOption('sku')
      ..addOption('model')
      ..addOption('serial', help: 'new serial number')
      ..addOption('capacity', help: 'new slot capacity')
      ..addOption('name', help: 'new display name');
  }

  final DecalCliDeps _deps;

  @override
  String get name => 'device-update';

  @override
  String get description =>
      'Update a CD library machine by id or serial; only supplied options '
          'change.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err(
        'usage: decal device-update <id-or-serial> [--manufacturer=..] '
        '[--sku=..] [--model=..] [--serial=..] [--capacity=..] [--name=..]',
      );
      return 1;
    }
    final args = argResults!;
    final capacityRaw = args['capacity'] as String?;
    final capacity = capacityRaw == null
        ? null
        : parsePositiveInt(capacityRaw, _deps, 'capacity');
    if (capacityRaw != null && capacity == null) return 1;

    final device = await resolveDeviceByIdOrSerial(_deps, rest.first);
    return device.fold(
      (failure) {
        _deps.err('error: ${failure.message}');
        return 1;
      },
      (d) => runTask(
        UpdateDevice(repository: _deps.library).call(
          deviceId: d.meta.id,
          manufacturer: args['manufacturer'] as String?,
          sku: args['sku'] as String?,
          model: args['model'] as String?,
          serialNumber: args['serial'] as String?,
          capacity: capacity,
          name: args['name'] as String?,
        ),
        _deps,
        onOk: (updated) {
          _deps.out(
            'Updated machine ${updated.serialNumber} (id ${updated.meta.id}).',
          );
          return 0;
        },
      ),
    );
  }
}

/// `decal slots <device-id>` — list the slots of a device.
class ListSlotsCommand extends Command<int> {
  /// Creates the command bound to [deps].
  ListSlotsCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'slots';

  @override
  String get description =>
      'List the slots of a carousel device (device id shown by `decal devices`).';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err('usage: decal slots <device-id>');
      return Future.value(1);
    }
    final deviceId = rest.first;
    return runTask(
      ListSlotsForDevice(_deps.library).call(deviceId: deviceId),
      _deps,
      onOk: (slots) {
        if (slots.isEmpty) {
          _deps.out('No slots for device $deviceId.');
        } else {
          for (final slot in slots) {
            final disc = slot.disc;
            if (disc == null) {
              _deps.out('  ${slot.slotNumber}: empty');
            } else {
              _deps.out(
                '  ${slot.slotNumber}: ${disc.skuId} '
                '(disc id ${disc.meta.id}'
                '${disc.serialNumber == null ? '' : ', serial ${disc.serialNumber}'})',
              );
            }
          }
        }
        return 0;
      },
    );
  }
}

/// `decal insert <device-id> <slot> <sku-id>` — place a disc into a slot.
class InsertDiscCommand extends Command<int> {
  /// Creates the command bound to [deps].
  InsertDiscCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'insert';

  @override
  String get description =>
      'Insert a disc (by catalog sku) into a device slot.';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length < 3) {
      _deps.err('usage: decal insert <device-id> <slot> <sku-id>');
      return Future.value(1);
    }
    final deviceId = rest[0];
    final slot = parsePositiveInt(rest[1], _deps, 'slot');
    if (slot == null) return Future.value(1);
    final skuId = rest[2];

    final disc = Disc(meta: newMeta(), skuId: skuId);
    final insert = InsertDisc(
      repository: _deps.library,
      unitOfWork: _deps.unitOfWork,
    );
    return runTask(
      insert.call(deviceId: deviceId, slotNumber: slot, disc: disc),
      _deps,
      onOk: (filledSlot) {
        _deps.out(
          'Inserted disc ${disc.skuId} into $deviceId slot '
          '${filledSlot.slotNumber} (disc id ${disc.meta.id}).',
        );
        return 0;
      },
    );
  }
}

/// `decal remove <device-id> <slot>` — empty a slot (remove its disc).
class RemoveDiscCommand extends Command<int> {
  /// Creates the command bound to [deps].
  RemoveDiscCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'remove';

  @override
  String get description =>
      'Remove the disc from a device slot, leaving it empty.';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      _deps.err('usage: decal remove <device-id> <slot>');
      return Future.value(1);
    }
    final deviceId = rest[0];
    final slot = parsePositiveInt(rest[1], _deps, 'slot');
    if (slot == null) return Future.value(1);

    return runTask(
      RemoveDisc(_deps.library).call(deviceId: deviceId, slotNumber: slot),
      _deps,
      onOk: (emptiedSlot) {
        _deps.out('Emptied $deviceId slot ${emptiedSlot.slotNumber}.');
        return 0;
      },
    );
  }
}

/// `decal locate <disc-id>` — find the slot holding a disc.
class LocateDiscCommand extends Command<int> {
  /// Creates the command bound to [deps].
  LocateDiscCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'locate';

  @override
  String get description =>
      'Locate the device slot currently holding a disc (by disc id).';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err('usage: decal locate <disc-id>');
      return Future.value(1);
    }
    final discId = rest.first;
    return runTask(
      LocateDisc(_deps.library).call(discId: discId),
      _deps,
      onOk: (slot) {
        if (slot == null) {
          _deps.out('Disc $discId is not in any slot.');
        } else {
          _deps.out(
            'Disc $discId is in device ${slot.deviceId} slot '
            '${slot.slotNumber}.',
          );
        }
        return 0;
      },
    );
  }
}

/// `decal carousel <slot>` — move the carousel to a slot.
///
/// This is the one command that reaches the USB/serial layer (via the
/// injected [DacalClient]) rather than the repository. When no carousel is
/// wired, it reports it instead of crashing.
class CarouselCommand extends Command<int> {
  /// Creates the command bound to [deps].
  CarouselCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'carousel';

  @override
  String get description =>
      'Move the carousel spindle to a slot (USB/serial device command).';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      _deps.err('usage: decal carousel <slot>');
      return 1;
    }
    final slot = parsePositiveInt(rest.first, _deps, 'slot');
    if (slot == null) return 1;

    final carousel = _deps.carousel;
    if (carousel == null) {
      _deps.err('No carousel is wired into this CLI.');
      return 1;
    }

    // The carousel layer uses its own DacalFailure hierarchy (distinct from
    // the domain DecalFailure), so fold it manually here.
    final result = await carousel.moveToSlot(slot);
    return result.fold(
      (failure) {
        _deps.err('carousel error: $failure');
        return 1;
      },
      (response) {
        _deps.out('carousel moved to slot $slot (${response.status.token}).');
        return 0;
      },
    );
  }
}

/// `decal --port COM3 detect` — probe for the Decal CD machine and report
/// whether it is reachable.
///
/// Runs the core machine probe [probeMachine], which opens the configured
/// port and issues the protocol's status query (a ping) to the machine. When
/// no port has been wired in, the probe cannot run and is reported as absent.
class DetectMachineCommand extends Command<int> {
  /// Creates the command bound to [deps].
  DetectMachineCommand(this._deps);

  final DecalCliDeps _deps;

  @override
  String get name => 'detect';

  @override
  String get description => 'Probe for the Decal CD machine and report '
      'whether it is reachable.';

  @override
  Future<int> run() async {
    final carousel = _deps.carousel;
    if (carousel == null) {
      _deps.err('No carousel is wired into this CLI (no --port given).');
      return 1;
    }

    final result = await probeMachine(carousel).run();
    return result.fold(
      (failure) {
        _deps.err('detect error: $failure');
        return 1;
      },
      (probe) {
        if (probe.detected) {
          final detected = probe as MachineDetected;
          _deps.out(
            'Machine detected (device $kDecalMachineSerialCode): '
            '${detected.status.token}.',
          );
          return 0;
        }
        _deps.err('No machine detected: ${(probe as MachineNotDetected).reason}');
        return 1;
      },
    );
  }
}
