# Project Foundation

## Layout and command

One Lake package, `agent-lean`, on the Lean release pinned in `lean-toolchain`, with no Lake
dependencies. The [architecture](../../design/architecture.md) lists the tree and the import
direction.

- `Main.lean` passes the arguments and the stdout and stderr streams to `AgentLean.Cli.run` and
  exits with the code it returns.
- `AgentLean/Cli.lean` parses into a `Command` (`version`, `help`, `-h`, `--help`), renders
  requested help on stdout and usage errors on stderr, and maps results to the exit codes of the
  [command-line contract](../../design/spec.md#command-line-contract). The theorem `parse_name`
  proves every command parses from its own name.
- `AgentLean/BuildInfo.lean` holds the name, version and repository and reads the target from
  `System.Platform.target`.
- The Linux executable links the Lean runtime statically and the system C library dynamically.

## Gates

`lake exe repo ci` runs `lake build --wfail`, `lake test --wfail` and `lake exe repo lint`. The
package sets `autoImplicit` and `relaxedAutoImplicit` off and `linter.missingDocs` on (off in the
test library), so undocumented declarations and `sorry` fail the build. `lakefile.toml` names
`AgentLeanTest` as the test driver and `repo lint` as the lint driver, so `lake test` and
`lake lint` run them. `.github/workflows/ci.yml` runs the same steps through lean-action, then
`lake exe repo dist`, on `ubuntu-latest` for pushes to `main` and for pull requests. The
[development guide](../../guide/development.md) lists every command.

## Planning tooling

`scripts/Repo/Plan.lean` loads the documents; `Plan/Model`, `Plan/Parse`, `Plan/Lint` and
`Plan/Status` hold the data, parsers, checks and report behind `lake lint` and
`lake exe repo plan-status`. `scripts/Repo/Links.lean` checks relative links,
`scripts/Repo/Style.lean` checks Lean line length, tabs and trailing whitespace,
`scripts/Repo/Tree.lean` lists the files both scan, and `scripts/Repo/Markdown.lean` holds the
Markdown reading they share. The checks cover registry statuses, current-page links for shipped
rows, plan groups in registry order, the fields and statuses of each lane, dependencies that
resolve to open tasks or existing records without cycles, and records that are named, indexed
and unique. Relative Markdown links and heading anchors outside fenced code must resolve. The
status report names the next eligible task.

## Agent rules

`AGENTS.md` is the only rule source. `CLAUDE.md` and `GEMINI.md` import it with `@`, and
`.cursor/rules/project-rules.mdc` links it, so rules change in one place.

## Tests

- `AgentLeanTest/Cli.lean`: parsing, the usage text, identity rendering, streams and exit codes
  for every case of the contract, and a failed write.
- `AgentLeanTest/Repo/Plan.lean`: each lint defect on temporary repository trees, multi-line
  fields, record-name parsing, a missing document and the status report.
- `AgentLeanTest/Repo/Links.lean`, `AgentLeanTest/Repo/Markdown.lean`: broken links and anchors,
  skipped directories, path normalization, percent-decoding, GitHub slugs and fence handling.
- `AgentLeanTest/Repo/Style.lean`: each layout rule and problem locations.
