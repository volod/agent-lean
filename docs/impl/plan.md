# agent-lean Implementation Plan

Forward-only: this file holds only work that remains. Product behavior, boundaries and
evaluation belong in the [specification](../design/spec.md); task shape, statuses, ordering and
records in the [planning workflow](../guide/planning-workflow.md); available behavior in
[current state](current.md). Run `lake exe repo plan-status` for counts and the next eligible
task.

Every task keeps `lake exe repo ci` green, adds deterministic, network-free tests, proves cheap
contract properties as theorems, and adds each new dependency to the
[dependency table](../design/spec.md#dependencies) in the same change.

## Agent Implementation Tasks

### Project identity -- `project-identity`

#### personalize-template-project

Give a repository created from this template its own identity before any product work starts.

- Serves: `project-identity` -- [Project identity](../design/spec.md#project-identity)
- Agent status: CLEAR
- Dependencies: none.
- User-visible outcome: The package, libraries, executable, README and specification name and
  describe the new product; `lake exe <name> version` prints the new name and repository URL.
- Scope boundary: Rename `name`, the libraries, the executable and `testDriver` in
  `lakefile.toml`; the `AgentLean` and `AgentLeanTest` directories, root modules, namespaces and
  imports; `name` and `repository` in `AgentLean/BuildInfo.lean`; and the expected names in
  tests. Rewrite the README and the purpose, scope and identity sections of the specification.
  Keep the version, `scripts/Repo`, gates and documentation lifecycle. Do not add capabilities,
  dependencies or architecture.
- Data and artifact paths: `lakefile.toml`, `lake-manifest.json`, `AgentLean.lean`, `AgentLean/`,
  `AgentLeanTest/`, `Main.lean`, `scripts/Repo/`, `README.md`, `AGENTS.md`, `docs/`.
- Execution path: Take the product name, repository URL and one-line description from the owner,
  or derive the URL from `git remote get-url origin`. Apply the renames, run `lake update` to
  refresh the manifest name, then `lake exe repo ci` and `lake exe <name> version`.
- Acceptance gates: `git grep -n -e agent-lean -e AgentLean` finds no reference that denotes the
  active project; `lake exe repo ci` passes; `lake exe <name> version` prints the new name and
  repository URL; `project-identity` is `shipped` with a current-state page. A negative result
  names the missing owner input instead of inventing it.
- Documentation target: new `docs/impl/current/project-identity.md`, linked from
  [current state](current.md) and the registry.
- Review checkpoint: none.

## Human-Assisted Tasks

None open. Add a task here when acceptance needs human judgment, authorization, private access or
spending authority.
