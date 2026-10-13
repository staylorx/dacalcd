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
export 'catalog/dacal_catalog.dart';
export 'contracts/library_repository.dart';
export 'contracts/no_op_unit_of_work.dart';
export 'contracts/serial_config_store.dart';
export 'contracts/unit_of_work.dart';
export 'entities/device.dart';
export 'entities/disc.dart';
export 'entities/hid_config.dart';
export 'entities/machine_config.dart';
export 'entities/meta.dart';
export 'entities/serial_config.dart';
export 'entities/slot.dart';
export 'failures/decal_failures.dart';
// The trait system is owned by sku_catalog — re-export its types so the front
// door (package:decalcd/decalcd.dart) still exposes Trait/TraitScope/etc.
export 'package:sku_catalog/sku_catalog.dart'
    show Trait, TraitScope, TraitAttributeDefinition, DataType;
