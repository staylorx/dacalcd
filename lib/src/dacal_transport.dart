/// Abstraction over the underlying byte channel to the carousel.
///
/// The real implementation is backed by `package:serial_port_win32`; tests
/// (and the capture logger) supply their own implementations. This is the seam
/// the dart-flutter-bible requires the communication layer to present.
abstract interface class DacalTransport {
  /// True once [open] has succeeded and before [close] is called.
  bool get isOpen;

  /// Opens the underlying byte channel. Returns a human-readable error
  /// message on failure, or `null` on success.
  Future<String?> open();

  /// Writes every byte in [bytes] to the device.
  Future<void> write(List<int> bytes);

  /// Reads up to [count] bytes from the device, waiting up to [timeout].
  /// Returns the bytes read (possibly fewer than [count] on timeout).
  Future<List<int>> read(int count, {Duration timeout});

  /// Closes the channel and frees any OS handles.
  Future<void> close();
}
