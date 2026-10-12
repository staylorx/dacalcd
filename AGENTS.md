# AGENTS.md — instructions for agents working in this repo

Dart project, Topology C (single package that is the melos workspace root).
Conforms to the
[Dart/Flutter Bible](https://github.com/taybiz/dart-flutter-bible) — everything
below is this repo's local wiring only; the doctrine is linked, not restated
(bible §1.3 D.R.Y.).

## Reading order

- Read the bible compact blob first: `docs/00-compact.md` (link or vendored copy).
- Topology C specifics: bible §3.3 (a single package is still a melos workspace root).
- If this file contradicts the bible, the bible wins until changed by proposal.

## Repository identity

- On-disk folder: `dacalcd`.
- Package name / pub repository: `decalcd` at
  `https://github.com/taybiz/decalcd`.
- Production code is the `lib/` package (Dart, not Flutter): the serial
  transport + protocol layer for Dacal CD carousels plus the library domain.

## Layout (Topology C)

One package that IS the workspace root. No `workspace:` list, no `melos.yaml`;
the `melos:` key lives in `pubspec.yaml` (`useRootAsPackage: true`). That buys
the tool belt: one CI entry point (`melos run <task>`) plus the release flow
(`melos version` → changelog + tag, `melos publish`). Release tag is a plain
`vX.Y.Z`, not package-prefixed.

## Composition-root seams

Concrete adapters live OFF the public barrel `package:decalcd/decalcd.dart`
(deliberately) so `dart:io` deps never leak into the platform-agnostic public
surface. Downstream apps import them explicitly when wiring storage/config:

- `src/data/data.dart` — sembast-backed persistence (`ILibraryRepository`
  impl, schema, transaction scope/unit-of-work).
- `src/config/config.dart` — serial-config file-backed store + service.

Contracts (`ILibraryRepository`, config store, unit-of-work) stay public in
`src/domain/domain.dart`.

## Housekeeping

- CI entry point: `dart run melos run analyze` and `dart run melos run test`
  (CI calls the script contract, never raw `dart analyze` / `dart test`).
- Clean before committing: `dart run melos run analyze` = `dart analyze
  --fatal-infos --fatal-warnings` (**zero diagnostics of any severity**) and
  `dart run melos run test`.
- Error style: failures are values, nothing throws — use cases and repository
  methods return `TaskEither<DacalFailure, T>` (fpdart); call `.run()` for the
  `Future<Either<DacalFailure, T>>`. The failure hierarchy lives in
  `src/domain/failures/decal_failures.dart`.
