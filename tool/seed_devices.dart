import 'dart:io';

import 'package:decalcd/decalcd.dart';
import 'package:decalcd/src/data/data.dart';
import 'package:sembast/sembast_io.dart';

Future<void> main(List<String> args) async {
  final dbPath = args[0];
  final db = await databaseFactoryIo.openDatabase(
    dbPath,
    version: librarySchemaVersion,
    onVersionChanged: libraryMigrations,
  );
  final scope = SembastTransactionScope();
  final repo = SembastLibraryRepository(database: db, scope: scope);
  final now = DateTime.now().toUtc().toIso8601String();
  final device = Device(
    meta: Meta(id: 'dev-67808', notes: '', createdAt: now, updatedAt: now),
    manufacturer: 'Dacal',
    sku: 'DC-300',
    model: 'CD Library II',
    serialNumber: '67808',
    capacity: 150,
    name: 'Main Rack',
  );
  await repo.saveDevice(device: device).run();
  for (var n = 1; n <= 3; n++) {
    await repo
        .updateSlot(
          slot: Slot(
            meta: Meta(
              id: 'dev-67808-slot-$n',
              notes: '',
              createdAt: now,
              updatedAt: now,
            ),
            deviceId: 'dev-67808',
            slotNumber: n,
          ),
        )
        .run();
  }
  await db.close();
  stdout.writeln('seeded');
}
