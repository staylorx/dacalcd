import 'package:decalcd/decalcd.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

/// A fake [IPortEnumerator] that returns a fixed list of ports, so the test
/// never touches the Windows COM registry.
final class FakePortEnumerator implements IPortEnumerator {
  /// The port names [listAvailablePorts] returns.
  final List<String> ports;

  /// When true, enumeration itself fails with a [DacalConnectionError].
  final bool failing;

  /// Creates an enumerator over [ports]. Set [failing] to exercise the
  /// enumeration-error path.
  FakePortEnumerator(this.ports, {this.failing = false});

  @override
  TaskEither<DacalFailure, List<String>> listAvailablePorts() => failing
      ? TaskEither.left(
          DacalConnectionError('Failed to enumerate COM ports: test'),
        )
      : TaskEither.right(ports);
}

void main() {
  group('AutoseekService', () {
    /// A probe that answers `true` only for the ports in [foundOn].
    TaskEither<DacalFailure, bool> Function(String) probeOn(
      Set<String> foundOn,
    ) =>
        (port) => TaskEither.right(foundOn.contains(port));

    test('returns AutoseekFound for the first port that answers', () async {
      final enumerator = FakePortEnumerator(['COM1', 'COM3', 'COM7']);
      final service = AutoseekService(
        enumerator: enumerator,
        probe: probeOn({'COM3'}),
      );

      final result = await service.seek().run();

      expect(result.isRight(), isTrue);
      final outcome = result.getRight().toNullable();
      expect(outcome, isA<AutoseekFound>());
      expect((outcome as AutoseekFound).portName, 'COM3');
    });

    test('returns AutoseekNotFound when no enumerated port answers', () async {
      final enumerator = FakePortEnumerator(['COM1', 'COM3']);
      final service = AutoseekService(
        enumerator: enumerator,
        probe: probeOn(const {}),
      );

      final result = await service.seek().run();

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), isA<AutoseekNotFound>());
    });

    test('returns AutoseekNotFound when there are no ports to probe', () async {
      final service = AutoseekService(
        enumerator: FakePortEnumerator(const []),
        probe: probeOn(const {}),
      );

      final result = await service.seek().run();

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), isA<AutoseekNotFound>());
    });

    test('skips ports whose probe fails and keeps seeking', () async {
      // The first port cannot even be probed (open failure -> Left), the
      // second answers. Autoseek must not stop on the failed port.
      final enumerator = FakePortEnumerator(['COM1', 'COM3']);
      final service = AutoseekService(
        enumerator: enumerator,
        probe: (port) => port == 'COM1'
            ? TaskEither.left(DacalConnectionError('COM1 is contested'))
            : TaskEither.right(true),
      );

      final result = await service.seek().run();

      expect(result.isRight(), isTrue);
      final outcome = result.getRight().toNullable();
      expect(outcome, isA<AutoseekFound>());
      expect((outcome as AutoseekFound).portName, 'COM3');
    });

    test('surfaces an enumeration failure as a Left', () async {
      final service = AutoseekService(
        enumerator: FakePortEnumerator(const [], failing: true),
        probe: probeOn(const {}),
      );

      final result = await service.seek().run();

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<DacalConnectionError>());
    });

    test('probes ports in enumeration order until the first match', () async {
      final probed = <String>[];
      final enumerator = FakePortEnumerator(['COM1', 'COM2', 'COM3']);
      final service = AutoseekService(
        enumerator: enumerator,
        probe: (port) {
          probed.add(port);
          return TaskEither.right(port == 'COM2');
        },
      );

      final result = await service.seek().run();

      // Seeking is sequential and stops at the first match: COM1 and COM2 are
      // probed, COM3 is never reached.
      expect(probed, ['COM1', 'COM2']);
      expect((result.getRight().toNullable() as AutoseekFound).portName,
          'COM2');
    });
  });
}
