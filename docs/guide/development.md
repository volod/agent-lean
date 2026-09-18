# Development Guide

## Requirements

- [elan](https://github.com/leanprover/elan). The first `lake` command in the repository
  installs the Lean release pinned in `lean-toolchain`; Lean bundles its own C compiler and
  linker.
- `tar` for `lake exe repo dist`; Linux, macOS and Windows 10+ ship it.
- Network access the first time, to download the toolchain.

## First run

```bash
lake exe repo ci             # every required gate
lake exe agent-lean version  # agent-lean 0.1.0 (https://github.com/volod/agent-lean, x86_64-unknown-linux-gnu)
lake exe repo plan-status    # the next eligible task
```

## Commands

Run `lake` from the repository root. `lake exe repo` builds the tooling in `scripts/` on first
use.

| Command | Runs | Purpose |
| --- | --- | --- |
| `lake build` | | Build `.lake/build/bin/agent-lean` and the modules it imports |
| `lake exe agent-lean <args>` | | Build and run the command |
| `lake test` | | Build `AgentLeanTest`; every `#guard`, `#guard_msgs`, `example` and `#eval` in it runs |
| `lake lint` | `lake exe repo lint` | Planning documents agree; relative Markdown links and anchors resolve; Lean lines fit 100 columns without tabs or trailing whitespace |
| `lake exe repo ci` | `lake build --wfail`; `lake test --wfail`; `lake exe repo lint` | Required before accepting a task; CI runs the same steps |
| `lake exe repo plan-status` | | Open task counts and the next eligible task |
| `lake exe repo dist [--tag vX.Y.Z]` | `lake build agent-lean`, then `tar` | Archive in `dist/`; `--tag` requires that version |
| `lake env lean <file>` | | Check one file against the built modules |
| `lake clean` | | Remove `.lake/build`; delete `dist/` by hand |

Lake rebuilds only what changed, so `lake test` replays a test module whose imports are
unchanged instead of rerunning it.

## Toolchain and dependencies

- To move to a newer Lean, change `lean-toolchain`, run `lake update` to refresh
  `lake-manifest.json`, then fix what `lake exe repo ci` reports. The String and `Std` APIs
  change between releases; follow the deprecation warnings.
- Add a dependency as a `[[require]]` entry in `lakefile.toml` with a pinned `rev`, run
  `lake update <name>`, and list it in the [dependency table](../design/spec.md#dependencies);
  commit `lakefile.toml` and `lake-manifest.json` together. A Mathlib dependency also needs
  `lake exe cache get` and a matching `lean-toolchain`.
- Package-wide options live under `[leanOptions]` in `lakefile.toml`; a library overrides them
  with its own `leanOptions`.

## Test layout

| Path | Purpose |
| --- | --- |
| `AgentLean/*.lean` | Theorems that pin cheap contract properties, beside the code |
| `AgentLeanTest/<Module>.lean` | Tests of one product module; `AgentLeanTest/Repo/` tests the tooling |
| `AgentLeanTest/Fixture.lean` | `expect`, `withTree` temporary file trees, `capture` for in-memory streams, `closedStream` |
| `AgentLeanTest/testdata/` | Committed inputs and golden outputs. Add it with its first file |

Rules:

- `lake test` builds the test library (`globs = ["AgentLeanTest.+"]`), so a new file under
  `AgentLeanTest/` runs without registration. A failing `#guard`, a mismatched `#guard_msgs`, an
  `example` that does not check or an `#eval` that throws fails the build.
- Use `#guard` for pure values, `#guard_msgs in #eval` for exact output, and `#eval show IO Unit
  from do ...` with `expect` for IO. Tables of cases beat one test per case.
- Tests are deterministic and network-free. Build fixtures with `withTree`, which removes them;
  never commit large or binary fixtures when a test can generate them.
- Reusable test helpers live in `AgentLeanTest/Fixture.lean`, never in product code.

## Versioning and releases

Versions follow [Semantic Versioning](https://semver.org) (`0.y.z` before 1.0). The single source
is `version` in `BuildInfo.current` (`AgentLean/BuildInfo.lean`); `agent-lean version` and the
archive names read it.

To release, bump the version, run `lake exe repo ci`, merge, then tag that commit and push the
tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow rebuilds each target from a clean checkout of the tag, fails when the tag
and the version differ, and publishes the archives and `SHA256SUMS` as a GitHub release.
`lake exe repo dist` builds the same archive for the host locally.

## CI

`.github/workflows/ci.yml` runs on `ubuntu-latest` for pushes to `main` and for pull requests.
[lean-action](https://github.com/leanprover/lean-action) installs elan, restores the `.lake`
cache and runs `lake build --wfail`, `lake test --wfail` and `lake lint`, the steps of
`lake exe repo ci`; the job then runs `lake exe repo dist`. `.github/workflows/release.yml` runs
on `v*.*.*` tags: the same gates, then `lake exe repo dist --tag <tag>` on each native runner,
then checksums and `gh release create`. Keep workflows thin wrappers over `lake` so local and CI
results agree.
