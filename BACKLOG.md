# BACKLOG — decalcd

Proposed, actionable work for the core package. This is a **queue, not a
warstory** (bible §1.3): one terse entry per unique, pick-up-able item. No
narrative, no rationale — the *why* lives in `CHANGELOG.md`, the operational
knowledge in `AGENTS.md` (see the doctrine repo's `templates/`).

Resolved items are **removed with no ceremony** — never parked under a "Done"
section.

## Open

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