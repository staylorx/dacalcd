import 'package:decalcd/src/dacal_transport.dart';

/// An in-memory [DacalTransport] used to fake the carousel in tests and the
/// smoke demo. Callers queue queued reads; the transport returns them in
/// order and records everything that was written.
class FakeDacalTransport implements DacalTransport {
  final List<List<int>> _readQueue = [];
  final List<List<int>> written = [];
  bool _open = false;
  bool failOpen = false;

  /// Queues [frames] as the responses the transport will return on read.
  void queueReads(List<List<int>> frames) => _readQueue.addAll(frames);

  @override
  bool get isOpen => _open;

  @override
  Future<String?> open() async {
    if (failOpen) return 'boom';
    _open = true;
    return null;
  }

  @override
  Future<void> write(List<int> bytes) async {
    written.add(List.of(bytes));
  }

  @override
  Future<List<int>> read(int count,
      {Duration timeout = const Duration(milliseconds: 1000)}) async {
    if (_readQueue.isNotEmpty) {
      return List.of(_readQueue.removeAt(0));
    }
    return const [];
  }

  @override
  Future<void> close() async {
    _open = false;
  }
}

/// Builds a framed ACK response exactly like the firmware sends it:
/// two-byte little-endian length, then the UTF-16LE token bytes.
List<int> ackFrame() => _frame('ACK');
List<int> busyFrame() => _frame('BUSY');
List<int> sosFrame() => _frame('SOS');
List<int> errorFrame() => _frame('ERROR');

List<int> _frame(String token) {
  final tokenBytes = <int>[];
  for (final unit in token.codeUnits) {
    tokenBytes.addAll([unit & 0xff, (unit >> 8) & 0xff]);
  }
  final length = 2 + tokenBytes.length;
  return [length & 0xff, (length >> 8) & 0xff, ...tokenBytes];
}
