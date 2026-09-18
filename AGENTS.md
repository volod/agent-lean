# Project rules

Canonical rules for every agent and contributor. `CLAUDE.md`, `GEMINI.md` and `.cursor/rules/`
only point here; never put rules in them. Read the selected task, the code it touches and the
design sections it links. Load other guidance only when a condition under
[Read when needed](#read-when-needed) applies.

## Project

`agent-lean` is a template for Lean 4 projects built by people and coding agents. The
[specification](docs/design/spec.md) says what the product must do and how each capability is
evaluated, the [architecture](docs/design/architecture.md) owns modules and import direction,
the [plan](docs/impl/plan.md) holds only remaining work, [task records](docs/impl/records/README.md)
keep evidence and decisions, and [current state](docs/impl/current.md) describes what exists.

## Guardrails

- Preserve unrelated work. Diagnostic or review requests do not authorize code changes.
- Do not commit, push, rewrite history or revert user changes unless explicitly asked.
- Lean is pinned in `lean-toolchain`; elan installs it. Run gates through `lake`; the
  [development guide](docs/guide/development.md#commands) lists them.
- Use Lean core and `Std` only. Add a Lake dependency only after adding it to the
  [dependency table](docs/design/spec.md#dependencies); commit `lakefile.toml` and
  `lake-manifest.json` together.
- `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `implemented_by` and `@[extern]` are
  forbidden in product code; allowing one is a specification change.
- Never hardcode machine-specific paths. Never put secrets in code, logs, fixtures or docs.
- Docs, output and identifiers are ASCII. Lean source may also use the Unicode notation Lean
  itself prints: arrows, the placeholder dot, anonymous-constructor brackets, products,
  comparisons and logical connectives.

## Lean conventions

- `Main.lean` only calls `AgentLean.Cli.run`. Product modules live in `AgentLean/` and are all
  imported by `AgentLean.lean`; tests in `AgentLeanTest/`; repository tooling in `scripts/Repo/`.
  Follow the [import direction](docs/design/architecture.md#import-direction). Name modules for
  what they provide; no `Util`, `Common`, `Helpers` or `Misc`.
- Names follow Lean core: types, structures, inductives and namespaces `UpperCamelCase`;
  functions and values `lowerCamelCase`; theorems `snake_case` stating the claim
  (`parse_name`). `?` marks an `Option` result, `!` a panicking variant.
- `autoImplicit` is off and `linter.missingDocs` is on. Every file has a `/-! -/` module
  docstring after its imports and every public declaration a `/-- -/` docstring. Builds run with
  `--wfail`: fix warnings; silence one only with `set_option ... in` on the narrowest
  declaration, with a comment saying why.
- Only `Cli` reads arguments, writes to stdout or stderr and picks exit codes. Other modules are
  pure or take streams (`IO.FS.Stream`), paths and clocks as parameters. Expected failures are
  values: return `Except` with an error inductive, or throw an `IO` error that names the input.
  `panic!`, `get!` and `xs[i]!` only assert invariants.
- Prefer structural recursion, then `termination_by`, then fuel; `partial def` only for IO
  loops that depend on the outside world. Accumulate in `Array`, pattern-match on `List`.
- State cheap contract properties as theorems beside the code (`rfl`, `decide`, `simp`,
  `omega`, `cases <;> ...`). Do not raise `maxHeartbeats`; split the proof.
- Tests mirror their module under `AgentLeanTest/` and run when `lake test` builds them: `#guard`
  and `example` for pure code, `#guard_msgs in #eval` for output, and `#eval` blocks that throw
  through `AgentLeanTest.expect` for IO, with file trees from `AgentLeanTest.withTree`. Tests are
  deterministic and network-free and assert behavior, not incidental details. A bug fix starts
  with a failing test.
- Two-space indentation, `fun x =>`, and the layout `lake lint` checks: lines of at most 100
  characters, no tabs, no trailing whitespace. Keep `open` inside a namespace or scoped with
  `open ... in`; leave no `#eval`, `#check` or `#print` in product modules. Keep files at about
  300 lines or less; split at real seams.

## Task cycle

1. Run `lake exe repo plan-status`, select one eligible task and note the counts. Check its
   dependencies and the records they link. Do not start blocked work.
2. Create the task record from the [template](docs/impl/records/template.md) using the
   [naming rules](docs/guide/planning-workflow.md#record-file-naming), paste the full task text
   and index it. Identify the affected modules and reusable code; do not silently broaden scope.
3. Implement and self-review. Tests cover the happy path, the main edge cases and a regression
   for every bug fixed.
4. Verify with `lake exe repo ci`. Record failures and unrun checks honestly. Fix causes; never
   weaken a gate. Failed acceptance keeps the task open.
5. Before stopping, update the record with evidence, decisions, audit notes and the next action.
   On acceptance: update the narrow `docs/impl/current/` page and link the record; remove the
   task from the plan and replace references to its id with the record link; mark the capability
   `shipped` when its last task is done. Run `lake lint`, report the task counts before and after
   and the next eligible task, inspect `git status` and remove temporary files.

## Read when needed

- **Adding or changing capabilities or tasks:** the
  [planning workflow](docs/guide/planning-workflow.md). Specify behavior and evaluation before
  planning or coding.
- **Concerns outside the task, or a checkpoint task:** the
  [audit rules](docs/guide/planning-workflow.md#audit-notes-and-checkpoints). Route each concern
  to exactly one owner.
- **Human-assisted tasks:** agents prepare inputs and report what is needed; they never mark a
  human task done. See [task lanes](docs/guide/planning-workflow.md#task-lanes).
- **Toolchain, dependencies, commands, CI, releases or test layout:** the
  [development guide](docs/guide/development.md).
