import Repo.Plan.Model

/-!
# Planning parsers

Parsers for the planning documents. They never fail: whatever they cannot parse is left for the
lint to report.
-/

namespace Repo.Plan

open Repo.Markdown

/-- The capability of a ``Title -- `capability` `` group heading. -/
def groupCapability? (heading : String) : Option String := do
  let (title, id) ← splitLast? (trim heading) " -- "
  if (trim title).isEmpty then none else soleId? id

/-- The id of a `task-id` or `task-id (optional)` task heading. -/
def taskId? (heading : String) : Option String :=
  let heading := trim heading
  let id := match dropSuffix? heading "(optional)" with
    | some id => if id.endsWith " " then some (trim id) else none
    | none => some heading
  id.filter isId

/-- Splits a `- Field name: value` line. -/
def fieldLine? (line : String) : Option (String × String) := do
  let (name, value) ← splitFirst? (← dropPrefix? line "- ") ":"
  let valid := (name.toList.head?.any Char.isUpper) &&
    name.toList.all fun c => c.isAlpha || c == ' ' || c == '-'
  if valid then some (name, trim value) else none

/-- State of the line-by-line plan parser. -/
private structure PlanParser where
  plan : Plan := {}
  lane : Option Lane := none
  capability : String := ""
  task : Option Task := none
  /-- Whether an indented line continues the task's most recent field. -/
  continuing : Bool := false

/-- Moves the task being read, if any, into the plan. -/
private def PlanParser.flush (p : PlanParser) : PlanParser :=
  match p.task with
  | some task => { p with plan.tasks := p.plan.tasks.push task, task := none, continuing := false }
  | none => { p with continuing := false }

/-- Reads one line of a task body into `task`. -/
private def PlanParser.body (p : PlanParser) (task : Task) (line : String) : PlanParser :=
  if let some field := fieldLine? line then
    { p with task := some { task with fields := field :: task.fields }, continuing := true }
  else if (trim line).isEmpty then { p with continuing := false }
  else match p.continuing, task.fields with
    | true, (name, value) :: rest =>
      let value := if value.isEmpty then trim line else s!"{value} {trim line}"
      { p with task := some { task with fields := (name, value) :: rest } }
    | _, _ => p

/-- Reads one numbered line of the plan. -/
private def PlanParser.step (p : PlanParser) (entry : String × Nat) : PlanParser :=
  let (line, i) := entry
  let p := if ["## ", "### ", "#### "].any (line.startsWith ·) then p.flush else p
  if line.startsWith "## " then { p with lane := Lane.ofHeading? line, capability := "" }
  else if let some rest := dropPrefix? line "### " then
    match p.lane, groupCapability? rest with
    | some lane, some id =>
      let group : Group := { capability := id, lane, line := i + 1 }
      { p with capability := id, plan.groups := p.plan.groups.push group }
    | _, _ => { p with capability := "" }
  else if let some rest := dropPrefix? line "#### " then
    match p.lane, taskId? rest with
    | some lane, some id =>
      { p with task := some { id, capability := p.capability, lane, line := i + 1 } }
    | _, _ => p
  else match p.task with
    | some task => p.body task line
    | none => p

/-- Parses `plan.md`. Field values may continue on indented lines. -/
def parsePlan (text : String) : Plan :=
  ((lines text).zipIdx.foldl PlanParser.step {}).flush.plan

/-- Parses the `## Capability Registry` table of the specification. The id is the first cell that
is exactly one backticked id; status and implementation cells are found by their headings. -/
def parseRegistry (text : String) : List Capability := Id.run do
  let mut inRegistry := false
  let mut columns : Option (Option Nat × Option Nat) := none
  let mut registry := #[]
  for line in lines text do
    if line.startsWith "## " then
      inRegistry := trim line == "## Capability Registry"
      continue
    let some cells := tableCells? line | continue
    unless inRegistry do continue
    let some (status, implementation) := columns
      | columns := some (cells.idxOf? "Status", cells.idxOf? "Implementation"); continue
    let cell (i : Option Nat) : String := (i.bind (cells[·]?)).getD ""
    if let some id := cells.findSome? soleId? then
      registry := registry.push { id, status := cell status, implementation := cell implementation }
  return registry.toList

/-- Parses the capability-to-record-group table of the planning workflow: two-cell rows whose
cells each hold a backticked id. -/
def parseGroupTable (text : String) : List (String × String) :=
  (lines text).filterMap fun line => do
    let [capability, group] ← tableCells? line | none
    return (← (backtickedIds capability).head?, ← (backtickedIds group).head?)

/-- Splits `NNNN-<group>-<task-id>.md` using the known group abbreviations, longest first. The
error is the lint problem for a malformed name or an unknown group. -/
def parseRecordName (name : String) (groups : List (String × String)) : Except String Record := do
  let malformed := s!"record {name}: name must be NNNN-<group>-<task-id>.md"
  let some stem := dropSuffix? name ".md" | throw malformed
  let sequence := (stem.take 4).toString
  let some rest := dropPrefix? (stem.drop 4).toString "-" | throw malformed
  unless sequence.length == 4 && sequence.all Char.isDigit && isId rest do throw malformed
  let groupNames := (groups.map (·.2)).mergeSort fun a b => a.length ≥ b.length
  let taskId? := groupNames.findSome? fun group =>
    (dropPrefix? rest s!"{group}-").filter (!·.isEmpty)
  let some taskId := taskId?
    | throw s!"record {name}: unknown group; add it to the planning workflow table"
  return { file := name, sequence, taskId }

end Repo.Plan
