/// The config persistence adapters.
///
/// Like `src/data`, this is a **composition-root seam**, deliberately NOT
/// exported through the public `package:decalcd/decalcd.dart` barrel — the
/// concrete file-backed store depends on `dart:io`, so it must not leak into
/// the platform-agnostic public surface. Downstream apps (CLI, Flutter)
/// import it explicitly when they wire up their settings storage:
///
/// ```dart
/// import 'package:decalcd/src/config/config.dart';
/// ```
library;

export 'serial_config_file_store.dart';
export 'serial_config_service.dart';
