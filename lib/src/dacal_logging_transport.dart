import 'dart:io';

import 'package:path/path.dart' as p;

import 'dacal_transport.dart';

/// A [DacalTransport] decorator that logs every byte written and read to a
/// capture file.
///
/// Useful for reverse-engineering the carousel protocol on a device whose
/// command set is not fully documented: point this at the live serial
/// transport, run the vendor software, and inspect the capture to learn the
/// exact bytes sent. Log lines are written incrementally so they survive a
/// process crash.
class DacalLoggingTransport implements DacalTransport {
  /// The underlying transport being observed.
  final DacalTransport inner;

  /// Absolute path of the capture log file.
  final String logPath;

  final IOSink _sink;
  final StringBuffer _buf;
  int _seq = 0;

  /// Creates a transport that mirrors [inner] and appends every frame to a
  /// file at [directory]/[fileName].
  DacalLoggingTransport(
    this.inner, {
    required String directory,
    String fileName = 'dacal_traffic.log',
    bool append = false,
  })  : logPath = p.join(directory, fileName),
        _sink = File(p.join(directory, fileName))
            .openWrite(mode: append ? FileMode.append : FileMode.write),
        _buf = StringBuffer();

  @override
  bool get isOpen => inner.isOpen;

  @override
  Future<String?> open() async {
    _log('OPEN');
    return inner.open();
  }

  @override
  Future<void> write(List<int> bytes) async {
    _log('TX ${_hex(bytes)}');
    await inner.write(bytes);
  }

  @override
  Future<List<int>> read(
    int count, {
    Duration timeout = const Duration(milliseconds: 1000),
  }) async {
    final data = await inner.read(count, timeout: timeout);
    _log('RX ${_hex(data)}');
    return data;
  }

  @override
  Future<void> close() async {
    _log('CLOSE');
    await inner.close();
    if (_buf.isNotEmpty) {
      _sink.write(_buf.toString());
      _buf.clear();
    }
    await _sink.flush();
    await _sink.close();
  }

  void _log(String line) {
    _buf.writeln('#${_seq++}: $line');
    if (_buf.length > 4096) {
      _sink.write(_buf.toString());
      _buf.clear();
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
