/// The logical command opcodes understood by the Dacal CD carousel firmware.
///
/// Opcode values are derived from reverse-engineered sources
/// (see the DACAL USB control-transfer protocol documented in the
/// `russwe/dacal` and `panako/DacalCDLibrary` projects).
enum DacalCommand {
  /// Identify the device; returns a device id string.
  id(0x0a),

  /// Reset the carousel / spindle.
  reset(0x0b),

  /// Begin a move-to-slot operation; a slim slot number must follow.
  moveTo(0x0c),

  /// Retract the pickup arm / close.
  retract(0x0e),

  /// Turn the LED position display on.
  ledOn(0x0f),

  /// Turn the LED position display off.
  ledOff(0x10),

  /// Query the device status; response carries ACK / BUSY / SOS text.
  getStatus(0x11);

  /// The raw byte sent on the wire for this command.
  final int code;

  const DacalCommand(this.code);
}
