import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';

/// A file-backed [ISerialConfigStore] that persists [SerialConfig] as a
/// single JSON document.
///
/// The config lives in a plain text file (for example
/// `<appData>/decalcd/serial_config.json`). Reading and writing are converted
/// at this boundary into [StorageFailure] values via `TaskEither.tryCatch`,
/// so the store never throws.
class SerialConfigFileStore implements ISerialConfigStore {
  /// The path of the JSON config file.
  final String filePath;

  /// Creates a store that persists to [filePath].
  SerialConfigFileStore(this.filePath);

  @override
  TaskEither<DecalFailure, SerialConfig?> load() => TaskEither.tryCatch(
    () async {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return SerialConfig.fromJson(decoded);
    },
    (Object error, StackTrace stackTrace) =>
        StorageFailure('Failed to read serial config: $error'),
  );

  @override
  TaskEither<DecalFailure, void> save(SerialConfig config) =>
      TaskEither.tryCatch(
        () async {
          final file = File(filePath);
          await file.create(recursive: true);
          await file.writeAsString(jsonEncode(config.toJson()));
        },
        (Object error, StackTrace stackTrace) =>
            StorageFailure('Failed to write serial config: $error'),
      );
}
