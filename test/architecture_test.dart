// Architecture & boundary rules for decalcd's domain + operations, enforced
// with dart_arch_test over the RESOLVED import graph (bible §2.9).
//
// Rules written down:
//  - The domain (`lib/src/domain`) is the inner area: it imports only itself
//    and its sanctioned value-type packages (equatable, fpdart).
//  - The use cases (`lib/src/usecases`) may use the domain, never the reverse.
//  - No internal library reaches through the public entry point.
//  - lib/src is private: the barrel is the only public door.

import 'dart:io';

import 'package:dart_arch_test/dart_arch_test.dart';
import 'package:test/test.dart';

/// The public entry point — the one door into the package (§2.6).
const _barrel = 'package:decalcd/decalcd.dart';

/// The two areas of `lib/src`, each with the packages its files may depend on.
const _allowedEdges = <String, Set<String>>{
  'domain': <String>{
    'package:decalcd/src/domain/',
    'package:fpdart/',
    'package:equatable/',
    'package:sku_catalog/',
  },
  'usecases': <String>{
    'package:decalcd/src/usecases/',
    'package:decalcd/src/domain/',
    'package:fpdart/',
    'package:equatable/',
  },
};

/// The package root — CWD under `dart test`, absolutized.
///
/// Never `Platform.script`: under some runners it points at the kernel snapshot
/// in a scratch dir, the graph comes back empty, and every rule passes
/// vacuously (§2.9).
String _packageRoot() => Directory.current.absolute.path;

void main() {
  late DependencyGraph graph;

  setUpAll(() async {
    graph = await Collector.buildGraph(_packageRoot(), force: true);
  });

  group('Given the architecture of decalcd', () {
    test(
      'When the graph is built, Then it resolved real libraries (not empty)',
      () {
        expect(graph, isNotEmpty);
        expect(Collector.allLibraries(graph), contains(_barrel));
        expect(
          Collector.allLibraries(graph),
          contains('package:decalcd/src/domain/domain.dart'),
        );
      },
    );

    for (final MapEntry(key: area, value: allowed) in _allowedEdges.entries) {
      test('Then $area depends only on the packages it is allowed', () {
        final violations = <String>[];
        for (final library in Collector.allLibraries(graph)) {
          if (!library.startsWith('package:decalcd/src/$area/')) continue;
          for (final dep in Collector.dependenciesOf(graph, library)) {
            if (dep.startsWith('dart:')) continue; // SDK is out of the graph
            if (!allowed.any(dep.startsWith)) {
              violations.add('$library -> $dep');
            }
          }
        }
        if (violations.isNotEmpty) {
          fail('BOUNDARY VIOLATIONS ($area):\n${violations.join('\n')}');
        }
      });
    }

    test('Then no internal library reaches through the public entry point', () {
      final violations = <String>[];
      for (final library in Collector.allLibraries(graph)) {
        if (!library.startsWith('package:decalcd/src/')) continue;
        if (Collector.dependenciesOf(graph, library).contains(_barrel)) {
          violations.add('$library -> $_barrel');
        }
      }
      if (violations.isNotEmpty) {
        fail('FRONT-DOOR CYCLES:\n${violations.join('\n')}');
      }
    });

    test('Then lib/src is private: no lib/ file reaches past src/', () {
      final violations = <String>[];
      for (final library in Collector.allLibraries(graph)) {
        // The privacy rule protects the published lib surface, so only callers
        // inside the package's lib (the barrel, reached as package:decalcd) are
        // checked. In-package tests (file://) reach src/ directly on purpose.
        if (!library.startsWith('package:decalcd/')) continue;
        if (library.startsWith('package:decalcd/src/')) continue;
        if (library == _barrel) continue;
        for (final dep in Collector.dependenciesOf(graph, library)) {
          if (dep.startsWith('package:decalcd/src/')) {
            violations.add('$library -> $dep');
          }
        }
      }
      if (violations.isNotEmpty) {
        fail('PRIVATE-IMPORT VIOLATIONS:\n${violations.join('\n')}');
      }
    });

    test('Then the published library reaches no file: URI (test doubles)', () {
      final violations = <String>[];
      for (final library in Collector.allLibraries(graph)) {
        if (!library.startsWith('package:decalcd/')) continue;
        for (final dep in Collector.dependenciesOf(graph, library)) {
          if (dep.startsWith('file:')) violations.add('$library -> $dep');
        }
      }
      if (violations.isNotEmpty) {
        fail('DOUBLE-DEPENDENCY VIOLATIONS:\n${violations.join('\n')}');
      }
    });

    test('Then there are no import cycles, workspace-wide', () {
      shouldBeFreeOfCycles(allFiles(), graph);
    });
  });
}
