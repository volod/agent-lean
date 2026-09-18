import Repo.Plan.Lint
import Repo.Plan.Parse
import Repo.Plan.Status

/-!
# Planning documents

`load` reads the capability registry in the design specification, the forward plan and the task
records; `lint` checks that they agree and `Status` summarizes open work.
-/

namespace Repo.Plan

open System (FilePath)

/-- Design specification holding the capability registry. -/
def specPath : String := "docs/design/spec.md"
/-- Forward plan. -/
def planPath : String := "docs/impl/plan.md"
/-- Planning workflow holding the record group table. -/
def workflowPath : String := "docs/guide/planning-workflow.md"
/-- Task records and their index. -/
def recordsPath : String := "docs/impl/records"

/-- Files in the records directory that are not task records. -/
def nonRecords : List String := ["README.md", "template.md"]

/-- Reads the planning documents under `root`. Badly named records are returned as problems;
an unreadable document or records directory is an error. -/
def load (root : FilePath) : IO (Inputs × List String) := do
  let read (path : String) : IO String := do
    try IO.FS.readFile (root / path)
    catch err => throw <| IO.userError s!"read {path}: {err}"
  let groups := parseGroupTable (← read workflowPath)
  let mut records := #[]
  let mut problems := #[]
  for entry in ← (root / recordsPath).readDir do
    let name := entry.fileName
    if !Markdown.isMarkdown name || nonRecords.contains name || (← entry.path.isDir) then continue
    match parseRecordName name groups with
    | .ok record => records := records.push { record with body := ← read s!"{recordsPath}/{name}" }
    | .error problem => problems := problems.push problem
  let inputs : Inputs := {
    registry := parseRegistry (← read specPath)
    plan := parsePlan (← read planPath)
    groups
    records := (records.qsort (·.file < ·.file)).toList
    recordIndex := ← read s!"{recordsPath}/README.md" }
  return (inputs, (problems.qsort (· < ·)).toList)

end Repo.Plan
