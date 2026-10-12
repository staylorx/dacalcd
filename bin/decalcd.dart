import 'dart:async';

import 'package:decalcd/decalcd.dart';

/// Minimal smoke demo of the communication layer against an in-memory fake
/// transport (no hardware needed). The richer CLI/TUI live in sibling
/// packages that build on this layer.
Future<void> main() async {
  // A fake transport that echoes an ACK for every command.
  final transport = _EchoAckTransport();
  final client = DacalClient(transport);

  final opened = await client.open();
  opened.fold(
    (failure) {
      stdoutLn('open failed: $failure');
      return;
    },
    (_) async {
      stdoutLn('opened (fake transport)');

      await client.send(DacalCommand.getStatus).then((r) => stdoutLn(
          'getStatus -> ${r.fold((f) => '$f', (ok) => ok.status.token)}'));
      await client
          .moveToSlot(5)
          .then((r) => stdoutLn(
              'moveToSlot(5) -> ${r.fold((f) => '$f', (ok) => ok.status.token)}'));
      await client.close();
    },
  );
}

class _EchoAckTransport implements DacalTransport {
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  Future<String?> open() async {
    _open = true;
    return null;
  }

  @override
  Future<void> write(List<int> bytes) async {}

  @override
  Future<List<int>> read(int count, {Duration timeout = const Duration(milliseconds: 1000)}) async {
    // Two-byte little-endian length (8) + UTF-16LE "ACK" (6 bytes).
    return [8, 0, 0x41, 0, 0x43, 0, 0x4b, 0];
  }

  @override
  Future<void> close() async {
    _open = false;
  }
}

void stdoutLn(String s) => print(s);
