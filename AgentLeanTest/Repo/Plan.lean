import Repo.Plan
import AgentLeanTest.Fixture

/-! Tests for `Repo.Plan`: parsing, every lint defect on temporary trees, and the status report. -/

open Repo.Plan AgentLeanTest

def specText : String := "# Spec\n\n## Capability Registry\n\n\
  | # | Capability | Status | Implementation |\n| --- | --- | --- | --- |\n\
  | 1 | `alpha` | shipped | [Current](../impl/current/alpha.md) |\n\
  | 2 | `beta` | planned | [Open work](../impl/plan.md) |\n\n## After\n"

def workflowText : String := "# Workflow\n\n| Capability id | Group abbrev |\n| --- | --- |\n\
  | `alpha` | `al` |\n| `beta` | `be` |\n"

def recordPath : String := "docs/impl/records/0001-al-first-task.md"

def agentTask (id deps : String) : String := s!"#### {id}\n\nDo it.\n\n\
  - Serves: `beta` -- [Spec](../design/spec.md)\n- Agent status: CLEAR\n\
  - Dependencies: {deps}\n- User-visible outcome: o\n- Scope boundary: s\n\
  - Data and artifact paths: p\n- Execution path:\n  multi-line\n  execution\n\
  - Acceptance gates: g\n- Documentation target: d\n- Review checkpoint: none.\n\n"

def validPlan : String := "# Plan\n\n## Agent Implementation Tasks\n\n### Beta -- `beta`\n\n" ++
  agentTask "build-beta" "[First](records/0001-al-first-task.md)." ++
  agentTask "finish-beta" "`build-beta`; `wait-human`." ++
  "## Human-Assisted Tasks\n\n### Beta -- `beta`\n\n#### wait-human\n\nDecide.\n\n\
  - Serves: `beta` -- x\n- Human status: HUMAN-GATED\n- Dependencies: none.\n\
  - Requested input or decision: d\n- Unblocks: `finish-beta`.\n"

/-- A consistent planning tree with `plan` as the plan, then `changes` applied. -/
def tree (plan : String) (changes : List (String × String) := []) : List (String × String) :=
  [(specPath, specText), (workflowPath, workflowText), (planPath, plan),
    ("docs/impl/records/README.md", "| [0001](0001-al-first-task.md) | x |\n"),
    ("docs/impl/records/template.md", "# Template\n"),
    (recordPath, "# First\n\n- Id / capability / checkpoint: `first-task` / `alpha` / none\n")]
    ++ changes

/-- Every problem `load` and `lint` report for a tree. -/
def lintTree (files : List (String × String)) : IO (List String) :=
  withTree files fun root => do
    let (inputs, problems) ← load root
    return problems ++ lint inputs

#guard (parsePlan validPlan).tasks.size == 3
#guard (parsePlan validPlan).groups.size == 2
#guard (parsePlan validPlan).tasks[0]?.map (·.field "Execution path") == some "multi-line execution"

#eval show IO Unit from do
  let problems ← lintTree (tree validPlan)
  expect problems.isEmpty s!"unexpected problems:\n{"\n".intercalate problems}"

-- (case, tree, expected problem substring)
#eval show IO Unit from do
  let edited (old new : String) := tree (validPlan.replace old new)
  let cases : List (String × List (String × String) × String) := [
    ("unknown dependency", edited "`build-beta`;" "`ghost-task`;",
      "dependency `ghost-task` is not an open task"),
    ("missing record", edited "0001-al-first-task" "0009-al-gone",
      "0009-al-gone.md does not exist"),
    ("cycle", edited "[First](records/0001-al-first-task.md)." "`finish-beta`.",
      "dependency cycle"),
    ("self cycle", edited "[First](records/0001-al-first-task.md)." "`build-beta`.",
      "dependency cycle build-beta -> build-beta"),
    ("missing field", edited "- Scope boundary: s\n" "", "missing field \"Scope boundary\""),
    ("bad status", edited "Agent status: CLEAR" "Agent status: DONE", "Agent status \"DONE\""),
    ("wrong serves", edited "- Serves: `beta`" "- Serves: `alpha`",
      "Serves must start with `beta`"),
    ("group not in registry", edited "### Beta -- `beta`" "### Gamma -- `gamma`",
      "group \"gamma\" is not in the registry"),
    ("accepted task still planned", edited "#### build-beta" "#### first-task",
      "task \"first-task\" is still in the plan"),
    ("duplicate task", edited "#### finish-beta" "#### build-beta",
      "duplicate task id \"build-beta\""),
    ("planned capability without tasks", tree "# Plan\n\n## Agent Implementation Tasks\n",
      "planned capability \"beta\" has no open tasks"),
    ("shipped capability without current page",
      tree validPlan [(specPath, specText.replace "../impl/current/alpha.md" "../impl/plan.md")],
      "shipped capability \"alpha\" must link its current-state page"),
    ("record not indexed", tree validPlan [("docs/impl/records/README.md", "empty\n")],
      "not linked from the records README"),
    ("record with unknown group", tree validPlan [("docs/impl/records/0002-zz-other.md", "x")],
      "unknown group"),
    ("malformed record name", tree validPlan [("docs/impl/records/notes.md", "x")],
      "name must be NNNN-<group>-<task-id>.md"),
    ("reused record sequence", tree validPlan [("docs/impl/records/0001-be-other-task.md",
      "- Id / capability / checkpoint: `other-task` / `beta` / none\n")],
      "sequence 0001 is already used"),
    ("record without id line", tree validPlan [(recordPath, "# First\n")],
      "first scope line must be")]
  for (name, files, want) in cases do
    let problems := "\n".intercalate (← lintTree files)
    expect (problems.contains want)
      s!"{name}: want a problem containing {want.quote}, got:\n{problems}"

-- A missing planning document is an error that names it.
#eval show IO Unit from do
  let files := (tree validPlan).filter (·.1 != planPath)
  let result ← (withTree files load).toBaseIO
  match result with
  | .ok _ => expect false "load succeeded without the plan"
  | .error err => expect ((toString err).contains planPath) s!"error {err} does not name the plan"

#guard (parseRecordName "0007-dist-extra-ship-it.md" [("a", "dist"), ("b", "dist-extra")]
  |>.toOption.map fun r => (r.sequence, r.taskId)) == some ("0007", "ship-it")
#guard (parseRecordName "0007-dist-.md" [("a", "dist")]).toOption.isNone
#guard (parseRecordName "007-dist-x.md" [("a", "dist")]).toOption.isNone

/--
info: open tasks: 3 (2 agent, 1 human)
next agent task: build-beta (beta, CLEAR)
human action available: wait-human (HUMAN-GATED)
-/
#guard_msgs in
#eval IO.print (Status.ofPlan (parsePlan validPlan)).render
