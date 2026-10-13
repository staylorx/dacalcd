/// The Decal CD library model — entities, failures and the repository contract.
///
/// No operations live here, and no storage: implement the contract over
/// whatever you have, and reach the operations through the front door,
/// `package:decalcd/decalcd.dart`.
///
/// Presents FP-style tuples: every repository method and use case call returns
/// a fpdart `TaskEither<DecalFailure, T>`, so nothing runs until `.run()`.
library;

export 'json_coercion.dart';
export 'contracts/library_repository.dart';
export 'contracts/no_op_unit_of_work.dart';
export 'contracts/serial_config_store.dart';
export 'contracts/unit_of_work.dart';
export 'entities/device.dart';
export 'entities/disc.dart';
export 'entities/hid_config.dart';
export 'entities/meta.dart';
export 'entities/serial_config.dart';
export 'entities/slot.dart';
export 'entities/trait.dart';
export 'entities/trait_attribute_definition.dart';
export 'failures/decal_failures.dart';
