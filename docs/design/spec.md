# agent-lean Specification

## Purpose

`agent-lean` is a copy-ready template for Lean 4 projects that people and coding agents develop
together. A fresh copy builds, tests and plans on day one: it ships an `agent-lean` command and
library, one set of agent rules, quality gates shared by local work and CI, and a planning
workflow in which every change traces from a specified capability to tests, theorems and
current-state documentation.

This specification is living. Behavior, boundaries and evaluation belong here, in capability
sections below or in capability pages copied from the [page template](template.md). Remaining
work belongs in the [plan](../impl/plan.md); delivered behavior in
[current state](../impl/current.md); modules and their imports in the
[architecture](architecture.md). A need discovered during implementation enters here first,
through [capability changes](../guide/planning-workflow.md#capability-changes).

## Scope

In scope:

- one Lake package with a product library, one executable, a test library and repository
  tooling, building natively on Linux, macOS and Windows;
- release archives with checksums, published to GitHub Releases from a version tag;
- `lake` entry points shared by local work and CI;
- gates for warnings-as-errors builds, tests, planning integrity, documentation links and Lean
  source layout;
- `AGENTS.md` as the only rule source, with adapters for Claude, Gemini and Cursor;
- a capability registry, forward plan, task records and current-state pages.

Out of scope until a specified capability needs them: a business domain, Mathlib, concurrency,
configuration files, persistence, network services, FFI, Reservoir publishing, code signing and
deployment.

## Design principles

1. **Core first.** Lean core and `Std` only; every dependency is justified in the
   [dependency table](#dependencies).
2. **Thin edges.** `Main.lean` wires the process, `Cli` owns the command-line contract, and
   library modules return typed values and errors to it.
3. **Contracts as code.** A property that is cheap to prove is a theorem beside the code;
   otherwise a compile-time test pins it.
4. **One workflow.** `lake` commands run every gate; CI runs the same commands.
5. **Deterministic evidence.** Tests are network-free and repeatable; acceptance is proven by
   commands another contributor can rerun.
6. **Traceable work.** Specification, plan, record and current-state page agree, and `lake lint`
   checks it.

## Cross-cutting rules

### Toolchain and build

- `lean-toolchain` pins the Lean release; `lakefile.toml` configures the package and
  `lake-manifest.json` is committed. Both toolchain files change together in one task.
- Package `agent-lean`, library `AgentLean`, executable `agent-lean` (`agent-lean.exe`), test
  library `AgentLeanTest`, tooling library `Repo` and executable `repo`.
- Package options: `autoImplicit` and `relaxedAutoImplicit` off, `linter.missingDocs` on (off in
  the test library). Gates build with `--wfail`, so any warning, including `sorry`, fails them.
- The version is `BuildInfo.current.version` in `AgentLean/BuildInfo.lean`; `lakefile.toml`
  declares none, so it has one source. Release tags are `vMAJOR.MINOR.PATCH` and must equal it.
  See [release distribution](#release-distribution).
- Gates run on Linux. Other platforms are built by the release workflow; platform-specific code
  branches on `System.Platform` inside a dedicated module.

### Dependencies

The product and tooling have no Lake dependencies. Lean core and `Std` ship with the toolchain.

| Dependency | Kind | Use |
| --- | --- | --- |
| none | | |

Adding a row is a specification change: name the need, the core alternative that was rejected
and why, and pin the revision in `lakefile.toml`.

### Command-line contract

- Synopsis: `agent-lean <command>`. Commands: `version`, `help`; `-h` and `--help` print the same
  help.
- stdout carries command results and requested help only; usage errors and diagnostics go to
  stderr, prefixed with `agent-lean: `.
- Exit codes: `0` success, `1` failure (including a failed write), `2` usage error. Signals keep
  the default disposition; a capability that must clean up on interruption specifies its own
  handling.

## Project foundation

The repository builds, tests and checks itself from a fresh clone with only elan.
`lake exe repo ci` runs every required gate, and GitHub Actions runs the same `lake` commands
plus `lake exe repo dist`.

Boundary: the foundation owns layout, tooling and gates, not product behavior.

Evaluation: `lake exe repo ci` passes on a fresh clone; the tooling tests reproduce each defect
the planning lint detects; the command-line tests drive `Cli.run` through every exit code and
`parse_name` proves every command parses from its name. A negative result names the failing gate
and never weakens it.

## Release distribution

`lake exe repo dist [--tag vX.Y.Z]` builds the executable for the host and writes
`dist/agent-lean-<version>-<target>.tar.gz`, or `.zip` for Windows, where `<target>` is
`System.Platform.target`, the name Lake itself uses for build archives. The archive holds one
directory of the same name containing the executable, `README.md` and `LICENSE`. The version
comes from the same definition as `agent-lean version`, so an archive never disagrees with its
binary. `--tag` fails before building when the tag is not `v` followed by that version.

Pushing a tag `vMAJOR.MINOR.PATCH` publishes a GitHub release: the release workflow runs the
gates, then builds archives with `--tag` on native runners for Linux x86_64 and arm64, macOS
arm64 and Windows x86_64, because Lake does not cross-compile. It writes `SHA256SUMS` in
`sha256sum -c` format, verifies it and uploads the archives and checksums with generated notes.

Boundary: no signing, SBOM, installers, Reservoir or package-manager publishing, and no
byte-for-byte reproducible archives.

Evaluation: tests cover option parsing, the tag check and archive names; CI runs
`lake exe repo dist` on every push and pull request. A negative result keeps the previous release
and names the failing runner or the mismatched tag.

## Project identity

`agent-lean version` prints one line naming the command, version, repository and target, for
example `agent-lean 0.1.0 (https://github.com/volod/agent-lean, x86_64-unknown-linux-gnu)`. After
a repository is created from the template, its package, libraries, namespaces, executable,
repository URL, README and this specification name and describe the new product.

Boundary: identity only. It does not choose the product's domain, dependencies or architecture.

Evaluation: tests agree on the identity; no template name remains where it denotes the active
project; `lake exe repo ci` passes. A negative result names the missing owner input (product
name, repository URL, description) instead of inventing it.

## Capability Registry

Every capability appears exactly once. Status is `planned` while it has open plan tasks and
`shipped` once its current-state page exists and no task remains. Row order is the
implementation line the plan follows.

| # | Capability | Status | How it is evaluated | Implementation |
| --- | --- | --- | --- | --- |
| 1 | `project-foundation` | shipped | `lake exe repo ci` passes on a fresh clone; tooling and command-line tests | [Current](../impl/current/project-foundation.md) |
| 2 | `release-distribution` | shipped | Dist tests; `lake exe repo dist` in CI; checksums verified before publishing | [Current](../impl/current/release-distribution.md) |
| 3 | `project-identity` | planned | Identity tests pass and no stale template identity remains after personalization | [Open work](../impl/plan.md#project-identity----project-identity) |

## Development integrity

[AGENTS.md](../../AGENTS.md) defines the task cycle; the
[planning workflow](../guide/planning-workflow.md) defines task shape, lanes, records and
checkpoints.

- Task records under `docs/impl/records/` keep the full accepted task, amendments, decisions and
  evidence. Current pages describe available behavior and link records. The plan holds only
  unresolved work.
- Tests are compile-time checks in `AgentLeanTest/`, deterministic and network-free; IO tests
  build fixtures in temporary directories. See the
  [test layout](../guide/development.md#test-layout).
- Coverage percentages are diagnostic, never a gate.
- Checks that need a real external system, credentials or human judgment are human-assisted or
  declared runs, never part of `lake exe repo ci`.

## Success criteria

A team creates a repository from the template, completes the first plan task to give it its own
identity, and then adds capabilities by specifying them here, planning tasks, and closing each
task with a record and a current-state page, while `lake exe repo ci` stays green. A contributor
can tell what the product promises, what remains, what exists and how each capability is proven
from the repository alone.
