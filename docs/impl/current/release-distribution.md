# Release Distribution

## Packaging

`lake exe repo dist [--tag vX.Y.Z]` produces the archive the
[specification](../../design/spec.md#release-distribution) requires.

- `scripts/Repo/Dist.lean` checks `--tag` against `BuildInfo.current.version` before building,
  then runs `lake build agent-lean`.
- It stages `dist/agent-lean-<version>-<target>/` with the executable (kept executable),
  `README.md` and `LICENSE`, archives it with the system `tar` (`-czf` to `.tar.gz`; `-acf` to
  `.zip` for Windows targets) and removes the staging directory. `<target>` is
  `System.Platform.target` of the Lean build running the tool, which matches the executable
  built by the same toolchain.

## Release workflow

`.github/workflows/release.yml` runs on pushed tags matching `v*.*.*`. The `gate` job runs the
lean-action gates. The `build` matrix runs `lake exe repo dist --tag <tag>` on `ubuntu-latest`,
`ubuntu-24.04-arm`, `macos-latest` and `windows-latest` and uploads each archive. The `publish`
job writes and verifies `SHA256SUMS` and runs
`gh release create <tag> dist/* --verify-tag --generate-notes`. `ci.yml` runs
`lake exe repo dist` for Linux x86_64 on every push and pull request.

## Tests

`AgentLeanTest/Repo/Dist.lean` covers option parsing, the tag check, archive names for Unix and
Windows targets and `repo` usage errors. The arm64, macOS and Windows archives are built only by
the release workflow.
