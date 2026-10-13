/// The sembast-backed persistence adapters.
///
/// This is a **composition-root seam**, deliberately NOT exported through the
/// public `package:decalcd/decalcd.dart` barrel. Downstream apps (CLI, TUI,
/// Flutter) import it explicitly when they wire up their storage:
///
/// ```dart
/// import 'package:decalcd/src/data/data.dart';
/// ```
///
/// The [ILibraryRepository] contract itself lives in the public domain barrel;
/// only these concrete adapters are private here. Users are expected to hold
/// a [Database] open for the lifetime of the repository and close it when
/// done.
library;

export 'sembast_catalog_repository.dart';
export 'sembast_library_repository.dart';
export 'sembast_schema.dart';
export 'sembast_transaction_scope.dart';
export 'sembast_unit_of_work.dart';
