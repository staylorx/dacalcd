# BACKLOG — decalcd

Proposed, actionable work for the core package. This is a **queue, not a
warstory** (bible §1.3): one terse entry per unique, pick-up-able item. No
narrative, no rationale — the *why* lives in `CHANGELOG.md`, the operational
knowledge in `AGENTS.md` (see the doctrine repo's `templates/`).

Resolved items are **removed with no ceremony** — never parked under a "Done"
section.

## Open

- [ ] **The `serial_number` uniqueness the definition declares is enforced on
      machines only.** `kDcSerialNumberTraitAttribute` is `isUnique` (it comes
      from sku_catalog's `SerializableTrait`), and `AddDevice`/`UpdateDevice`
      refuse a duplicate machine serial — but the disc write paths
      (`AddDiscToLibrary`, `ChangeDiscInLibrary`) do not, so two disc copies can
      hold the same serial while the definition claims otherwise. Decide one way
      and record it: enforce it on the disc paths too (its own rule use case, the
      shape of `AssertUniqueInstanceName`), or state that the flag is descriptive
      here and say why.

- [ ] **`melos run format` is red at HEAD.** Dart 3.13's formatter (tall style)
      reflows ~39 files this tree was not formatted with, none of them touched by
      a given change — so the format gate fails for everybody and a feature diff
      must not carry the reflow. Land the repo-wide reformat as its own commit
      (touching nothing else), or pin the gate, and keep it out of feature work.

- [ ] **CI is red at `pub get`: the catalog is a `path:` dep.** The workflow
      checks out only this repo, so `sku_catalog: {path: ../../sku_catalog}` has
      nothing to resolve — every run fails at *Install dependencies*, on every
      commit (it predates the current work). `sku_catalog` is published on
      pub.dev up to 4.0.0, so `sku_catalog: ^4.0.0` is a working pin; the path
      dep stays the dev-time choice for cross-repo work. Pick one and get the
      gate green.

- [ ] **Finish multi-machine serial: drop the residual single-machine
      assumptions.** The per-machine connection path is done (`Device.serialConfig`,
      per-machine list/fetch/select/auto-detect, no shared app-wide port), but core
      still keys machine detection to one hardcoded serial
      (`machine_detector.kDecalMachineSerialCode`, probed by autoseek and the CLI
      `detect-machine` command), and the single-port file-backed
      `SerialConfigService`/`ISerialConfigStore`/`SerialConfigFileStore` stack is
      now unused by the app's serial path (only a failure/contract test exercises
      it). Make detection identity per-machine and remove the dead single-port
      config machinery once nothing references it.

- [ ] **Config §13 conformance.** Implement the three-layer precedence chain
      from bible §13.1 (`--config`/`-c` flag > env vars > default config file)
      in the CLI (`bin/decal.dart`, global options). YAML via `package:yaml`,
      platform-standard default path (§13.4), per-key fall-through (§13.2),
      hard error on a missing/readable `--config` path. Ship `config.example.yaml`
      and document the schema in `README.md`. Add tests proving each layer
      (§13.9): env trumps default config, `--config` trumps env, missing
      `--config` file exits non-zero. Currently the CLI is flag-only (`--db`,
      `--port`); this is the tracked path to §13 conformance unless the owner
      records it as a deliberate deviation.

## Resolved

(Closed items are removed, not logged.)