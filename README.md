# agent-lean

A copy-ready Lean 4 project skeleton for teams that want coding agents to work from one set of
rules, one product specification and one forward plan.

A fresh copy builds an `agent-lean` command and library, passes its quality gates, and has a
machine-checked plan whose first task gives the new repository its own identity. The Lake
layout, gates and planning workflow are meant to stay; the name and the product are yours.

## Quick start

Requirements: [elan](https://github.com/leanprover/elan) and Git. The pinned Lean release
installs itself on the first `lake` command.

```bash
lake exe repo ci             # build --wfail, test --wfail, plan, link and style checks
lake exe agent-lean version  # agent-lean 0.1.0 (https://github.com/volod/agent-lean, x86_64-unknown-linux-gnu)
lake exe repo plan-status    # next agent task: personalize-template-project
```

## Start a project from the template

1. Create a repository from this template and clone it.
2. Ask your agent to take the next task from `lake exe repo plan-status`. The first one,
   `personalize-template-project`, renames the package, libraries, executable and docs; give it
   the product name, repository URL and a one-line description.
3. Describe the product's first capability in the [specification](docs/design/spec.md), then
   plan and implement it as the [planning workflow](docs/guide/planning-workflow.md) describes.

## Daily commands

| Command | Purpose |
| --- | --- |
| `lake build` | Build the command into `.lake/build/bin/` |
| `lake exe agent-lean <args>` | Build and run the command |
| `lake test` | Build the test library, which runs every test |
| `lake lint` | Check the planning documents, Markdown links and Lean layout |
| `lake exe repo ci` | Run the required gate (what CI runs) |
| `lake exe repo dist` | Build a release archive for this host into `dist/` |
| `lake exe repo plan-status` | Count open tasks and show the next eligible one |

The [development guide](docs/guide/development.md) explains each one.

## Releases

Set the version in `AgentLean/BuildInfo.lean`, merge, then push the matching tag; the release
workflow checks, builds Linux (x86_64, arm64), macOS (arm64) and Windows (x86_64) archives on
native runners and publishes them with `SHA256SUMS`:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## How work flows

```text
docs/design/spec.md       what the product must do and how each capability is evaluated
        |
docs/impl/plan.md         only work that remains, ordered by the capability registry
        |
docs/impl/records/        one record per task: full scope, decisions, evidence
        |
docs/impl/current.md      what exists now, linking the records that prove it
```

`lake lint` fails when these documents disagree, a relative link or anchor is broken, or a Lean
line breaks the layout rules.

## Layout

```text
Main.lean           process wiring: arguments, streams, exit code
AgentLean.lean      library root; imports every product module
AgentLean/          product modules: Cli (command-line contract), BuildInfo (identity)
AgentLeanTest/      compile-time tests run by `lake test`
scripts/Repo/       dev-only tooling behind `lake exe repo` and `lake lint`
docs/               specification, plan, records, current state, guides
```

## Agent support

[AGENTS.md](AGENTS.md) is the only rule file. `CLAUDE.md` and `GEMINI.md` import it, and the
Cursor rule in `.cursor/rules/` points to it; Codex and other agents read `AGENTS.md` directly.

## License

MIT. See [LICENSE](LICENSE).
