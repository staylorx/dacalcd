/// Operations on the Decal CD library — querying devices, slots and discs, and
/// the insert/remove/locate actions.
///
/// Everything is typed against the repository contract in `../domain`; this
/// library ships no persistence.
///
/// Presents FP-style tuples: every use case call returns a fpdart
/// `TaskEither<DecalFailure, T>`; call `.run()` for a
/// `Future<Either<DecalFailure, T>>`.
library;

export 'add_disc_to_library.dart';
export 'change_disc_in_library.dart';
export 'get_device_by_serial_code.dart';
export 'get_disc.dart';
export 'get_slot_status.dart';
export 'id_generator.dart';
export 'insert_disc.dart';
export 'list_devices.dart';
export 'list_discs.dart';
export 'list_slots_for_device.dart';
export 'locate_disc.dart';
export 'new_meta.dart';
export 'remove_disc.dart';
export 'remove_disc_from_library.dart';
export 'sequence.dart';
