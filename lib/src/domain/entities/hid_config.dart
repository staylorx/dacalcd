import 'package:equatable/equatable.dart';

/// The transport mechanism the Dacal HID bridge uses, as discovered by live
/// USB capture (USBPcap): commands ride as **GET_DESCRIPTOR STRING** control
/// transfers on endpoint 0 where the STRING INDEX is the opcode byte, and the
/// device answers with a string descriptor `LL 03 <token UTF-16LE>`.
const String kHidTransportStringDescriptor = 'hid_string_descriptor';

/// The status tokens a Dacal device reports in its response framing, in order
/// of the README contract: `ACK`, `BUSY`, `SOS`, `ERROR`.
const List<String> kDacalStatusTokens = ['ACK', 'BUSY', 'SOS', 'ERROR'];

/// Runtime USB/HID connection configuration for a Dacal CD carousel — a
/// Cypress CY7C64225 HID-UART bridge, VID `0x04b4` / PID `0x5a9b`.
///
/// This is the object that "captures all the connection info" reverse
/// engineered from live USB captures (see `docs/usb-capture-session-*.md`):
/// how the vendor software reaches the machine, so a future HID transport can
/// open this exact unit without another sniffing session. A CD library
/// machine is a SKU that carries the `hid` trait (see `kDcHidTrait`) as its
/// classification; this config is a first-class domain entity held as a
/// property of the machine instance ([Device.hidConfig]), mirroring
/// [serialConfig] — not stuffed into trait-attribute values.
///
/// It is a plain value object: no behaviour, no storage. Persisting it is the
/// caller's job via the repository / device store.
class HidConfig extends Equatable {
  /// Which transport mechanism the connection uses. Only
  /// [kHidTransportStringDescriptor] is known/verified today.
  final String transportKind;

  /// USB vendor id (`0x04b4` = Cypress).
  final int vid;

  /// USB product id (`0x5a9b` = Dacal D-101 / DC-300 / DC-016RW).
  final int pid;

  /// The host-controller/root-hub handle the machine sits behind
  /// (`\\.\USBPcap2` in the captures). This is the stable-ish handle: the
  /// per-device [deviceAddress] is reassigned on every replug.
  final String busFilter;

  /// The USB device address seen on the bus in the captures (`10`). Volatile —
  /// Windows reassigns it on replug — so treat it as last-seen, not fixed.
  final int? deviceAddress;

  /// The single interrupt-IN endpoint (`0x81`). There is NO interrupt-OUT
  /// endpoint on this bridge; the outbound direction uses control transfers
  /// (see [opcodeViaStringIndex]).
  final int interruptInEndpoint;

  /// USB `wMaxPacketSize` on the interrupt endpoint (3-byte HID reports).
  final int reportSize;

  /// USB `bInterval` of the interrupt endpoint (10 ms polling).
  final int pollInterval;

  /// True when the command byte is carried as the STRING-DESCRIPTOR INDEX of a
  /// GET_DESCRIPTOR control transfer (verified). Commands are not report data.
  final bool opcodeViaStringIndex;

  /// USB `wIndex` (language id) used on the string-descriptor transfers
  /// (`0x0409` = English (US)).
  final int stringLanguageId;

  /// The status tokens the device may return in its response framing.
  final List<String> statusTokens;

  /// The outbound (host-to-device) direction. Every command observed so far is
  /// a device-to-host GET_DESCRIPTOR; NO host-to-device data has been seen in
  /// captures, so this is a deliberately open seam awaiting a TX capture.
  final HidTxInfo tx;

  /// Creates an [HidConfig].
  const HidConfig({
    required this.transportKind,
    required this.vid,
    required this.pid,
    required this.busFilter,
    this.deviceAddress,
    this.interruptInEndpoint = 0x81,
    this.reportSize = 3,
    this.pollInterval = 10,
    this.opcodeViaStringIndex = true,
    this.stringLanguageId = 0x0409,
    this.statusTokens = kDacalStatusTokens,
    this.tx = const HidTxInfo(),
  });

  /// The canonical Dacal HID connection (Cypress 04B4:5A9B on `\\.\USBPcap2`).
  static const HidConfig dacal = HidConfig(
    transportKind: kHidTransportStringDescriptor,
    vid: 0x04b4,
    pid: 0x5a9b,
    busFilter: r'\\\\.\\USBPcap2',
    deviceAddress: 10,
  );

  /// Converts to JSON with snake_case keys, preserving every captured field.
  Map<String, dynamic> toJson() => {
    'transport_kind': transportKind,
    'vid': vid,
    'pid': pid,
    'bus_filter': busFilter,
    if (deviceAddress != null) 'device_address': deviceAddress,
    'interrupt_in_endpoint': interruptInEndpoint,
    'report_size': reportSize,
    'poll_interval': pollInterval,
    'opcode_via_string_index': opcodeViaStringIndex,
    'string_language_id': stringLanguageId,
    'status_tokens': statusTokens,
    'tx': tx.toJson(),
  };

  /// Parses an [HidConfig] from snake_case JSON, falling back to the
  /// canonical Dacal defaults when a field is missing.
  factory HidConfig.fromJson(Map<String, dynamic> json) =>
      HidConfig(
        transportKind: json['transport_kind'] as String? ??
            kHidTransportStringDescriptor,
        vid: json['vid'] as int? ?? 0x04b4,
        pid: json['pid'] as int? ?? 0x5a9b,
        busFilter: json['bus_filter'] as String? ?? '',
        deviceAddress: json['device_address'] as int?,
        interruptInEndpoint: json['interrupt_in_endpoint'] as int? ?? 0x81,
        reportSize: json['report_size'] as int? ?? 3,
        pollInterval: json['poll_interval'] as int? ?? 10,
        opcodeViaStringIndex: json['opcode_via_string_index'] as bool? ?? true,
        stringLanguageId: json['string_language_id'] as int? ?? 0x0409,
        statusTokens: (json['status_tokens'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            kDacalStatusTokens,
        tx: json['tx'] is Map<String, dynamic>
            ? HidTxInfo.fromJson(json['tx'] as Map<String, dynamic>)
            : const HidTxInfo(),
      );

  @override
  List<Object?> get props => [
    transportKind,
    vid,
    pid,
    busFilter,
    deviceAddress,
    interruptInEndpoint,
    reportSize,
    pollInterval,
    opcodeViaStringIndex,
    stringLanguageId,
    statusTokens,
    tx,
  ];
}

/// The outbound (host-to-device) half of the Dacal HID connection — an open
/// seam. Every command captured so far is a host READ (GET_DESCRIPTOR), and no
/// host-to-device bytes have appeared on the bus. This records that state and
/// leaves room for the TX mechanism to be filled in once a TX capture exists.
class HidTxInfo extends Equatable {
  /// The mechanism a host-to-device write would use. `'unproven'` until a
  /// capture shows one (candidates to probe: SET_REPORT / SET_DESCRIPTOR /
  /// interrupt-OUT on a different configuration).
  final String mechanism;

  /// Human note describing what is known (or not) about the TX direction.
  final String note;

  /// Creates a [HidTxInfo].
  const HidTxInfo({
    this.mechanism = 'unproven',
    this.note = 'No host-to-device data observed in captures; direction unproven.',
  });

  /// Converts to JSON with snake_case keys.
  Map<String, dynamic> toJson() => {
    'mechanism': mechanism,
    'note': note,
  };

  /// Parses a [HidTxInfo] from snake_case JSON, falling back to `'unproven'`.
  factory HidTxInfo.fromJson(Map<String, dynamic> json) => HidTxInfo(
    mechanism: json['mechanism'] as String? ?? 'unproven',
    note: json['note'] as String? ??
        'No host-to-device data observed in captures; direction unproven.',
  );

  @override
  List<Object?> get props => [mechanism, note];
}
