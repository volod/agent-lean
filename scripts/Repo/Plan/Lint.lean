import Repo.Plan.Model

/-!
# Planning lint

Integrity checks across the capability registry, the plan and the task records. Every check is a
pure function from the parsed documents to a list of problems.
-/

namespace Repo.Plan

open Repo.Markdown

/-- Registry rows: unique ids, valid statuses, current pages for shipped rows, record groups. -/
def lintRegistry (inputs : Inputs) : List String := Id.run do
  let mut problems := #[]
  let mut seen : List String := []
  for c in inputs.registry do
    let id := c.id.quote
    if seen.contains c.id then problems := problems.push s!"registry: capability {id} listed twice"
    seen := c.id :: seen
    if c.status != "planned" && c.status != "shipped" then
      problems := problems.push
        s!"registry: capability {id} has status {c.status.quote}, want planned or shipped"
    if c.status == "shipped" && !c.implementation.contains "impl/current/" then
      problems := problems.push
        s!"registry: shipped capability {id} must link its current-state page"
    if (inputs.groups.lookup c.id).isNone then
      problems := problems.push
        s!"registry: capability {id} has no record group in the planning workflow table"
  if inputs.registry.isEmpty then
    problems := problems.push "registry: no capabilities parsed from the specification"
  return problems.toList

/-- Plan groups name registered capabilities, in registry order within each lane. -/
def lintGroupOrder (inputs : Inputs) : List String := Id.run do
  let order := inputs.registry.map (·.id)
  let mut lastInLane : List (Lane × Nat) := []
  let mut problems := #[]
  for g in inputs.plan.groups do
    let some index := order.idxOf? g.capability
      | problems := problems.push
          s!"plan:{g.line}: group {g.capability.quote} is not in the registry"
    if (lastInLane.lookup g.lane).any (index ≤ ·) then
      problems := problems.push
        s!"plan:{g.line}: group {g.capability.quote} is out of registry order in the {g.lane} lane"
    lastInLane := (g.lane, index) :: lastInLane
  return problems.toList

/-- Task ids are unique across the plan. -/
def lintDuplicateTasks (tasks : Array Task) : List String :=
  tasks.toList.zipIdx.filterMap fun (task, i) =>
    if (tasks.toList.take i).any (·.id == task.id) then
      some s!"plan:{task.line}: duplicate task id {task.id.quote}"
    else none

/-- The task id on a record's `- Id / capability / checkpoint:` line. -/
def recordTaskId? (body : String) : Option String :=
  (lines body).findSome? fun line => do
    let rest ← dropPrefix? line "- Id / capability / checkpoint: `"
    return (← splitFirst? rest "`").1

/-- Record names, sequences, id lines and indexing. -/
def lintRecords (inputs : Inputs) : List String := Id.run do
  let openIds := inputs.plan.tasks.toList.map (·.id)
  let mut sequences : List (String × String) := []
  let mut problems := #[]
  for r in inputs.records do
    let add (problem : String) (ps : Array String) := ps.push s!"record {r.file}: {problem}"
    match sequences.lookup r.sequence with
    | some previous =>
      problems := add s!"sequence {r.sequence} is already used by {previous}" problems
    | none => sequences := (r.sequence, r.file) :: sequences
    if recordTaskId? r.body != some r.taskId then
      problems := add
        s!"first scope line must be \"- Id / capability / checkpoint: `{r.taskId}` ...\"" problems
    if !inputs.recordIndex.contains s!"({r.file})" then
      problems := add "not linked from the records README" problems
    if openIds.contains r.taskId then
      problems := add s!"task {r.taskId.quote} is still in the plan" problems
  return problems.toList

/-- A planned capability has open tasks; a shipped one has none. -/
def lintOpenWork (inputs : Inputs) : List String :=
  inputs.registry.filterMap fun c =>
    let count := (inputs.plan.tasks.filter (·.capability == c.id)).size
    if c.status == "planned" && count == 0 then
      some s!"registry: planned capability {c.id.quote} has no open tasks"
    else if c.status == "shipped" && count > 0 then
      some s!"registry: shipped capability {c.id.quote} still has {count} open task(s)"
    else none

/-- The record stems (`0001-group-task`) linked as `(records/<stem>.md...)` in `text`. -/
def recordLinks (text : String) : List String :=
  (text.splitOn "(records/").drop 1 |>.filterMap fun after => do
    let (stem, _) ← splitFirst? after ".md"
    let sequence := (stem.take 4).toString
    let rest ← dropPrefix? (stem.drop 4).toString "-"
    if sequence.length == 4 && sequence.all Char.isDigit && isId rest then some stem else none

/-- Fields, statuses, the served capability, dependencies and unblocked tasks of one task. -/
def lintTask (task : Task) (openIds records : List String) : List String := Id.run do
  let mut problems := #[]
  if task.capability.isEmpty then problems := problems.push "not under a capability group heading"
  for field in task.lane.requiredFields do
    if (task.field field).isEmpty then problems := problems.push s!"missing field {field.quote}"
  let status := task.field task.lane.statusField
  if !status.isEmpty && !task.lane.statuses.contains status then
    problems := problems.push
      s!"{task.lane.statusField} {status.quote} is not valid in the {task.lane} lane"
  let serves := task.field "Serves"
  if !serves.isEmpty && !serves.startsWith s!"`{task.capability}`" then
    problems := problems.push s!"Serves must start with `{task.capability}`"
  for id in task.dependencies do
    unless openIds.contains id do
      problems := problems.push
        s!"dependency `{id}` is not an open task (link accepted work as records/...)"
  for stem in recordLinks (task.field "Dependencies") do
    unless records.contains stem do
      problems := problems.push s!"dependency record {stem}.md does not exist"
  if task.lane == .human then
    for id in backtickedIds (task.field "Unblocks") do
      unless openIds.contains id do
        problems := problems.push s!"unblocks `{id}`, which is not an open task"
  return problems.toList.map (s!"plan:{task.line}: task {task.id.quote}: " ++ ·)

/-- One dependency cycle among open tasks, its first id repeated at the end, or `none`. -/
def findCycle (tasks : List Task) : Option (List String) :=
  let ids := tasks.map (·.id)
  let edges := tasks.map fun t => (t.id, t.dependencies.filter ids.contains)
  -- Tasks left after peeling off those whose dependencies are all peeled lie on or lead into a
  -- cycle, and each of them depends on another one that is left.
  match peel edges.length edges with
  | [] => none
  | left@((start, _) :: _) => walk left left.length [start] start
where
  /-- Repeatedly removes tasks with no dependency among the remaining ones. -/
  peel : Nat → List (String × List String) → List (String × List String)
    | 0, edges => edges
    | fuel + 1, edges =>
      let blocked := edges.filter fun (_, deps) => deps.any fun d => edges.any (·.1 == d)
      if blocked.length == edges.length then edges else peel fuel blocked
  /-- Follows dependencies from `id` until one repeats; `path` holds the visited ids, newest
  first. -/
  walk (left : List (String × List String)) : Nat → List String → String → Option (List String)
    | 0, _, _ => none
    | fuel + 1, path, id => do
      let next ← (left.lookup id).bind (·.find? fun d => left.any (·.1 == d))
      if path.contains next then some (path.reverse.dropWhile (· != next) ++ [next])
      else walk left fuel (next :: path) next

/-- Every disagreement between the planning documents; empty when they agree. -/
def lint (inputs : Inputs) : List String :=
  let openIds := inputs.plan.tasks.toList.map (·.id)
  let records := inputs.records.map fun r => (dropSuffix? r.file ".md").getD r.file
  let cycle := (findCycle inputs.plan.tasks.toList).map fun ids =>
    s!"plan: dependency cycle {" -> ".intercalate ids}"
  lintRegistry inputs ++ lintGroupOrder inputs ++ lintDuplicateTasks inputs.plan.tasks ++
    lintRecords inputs ++ (inputs.plan.tasks.toList.flatMap (lintTask · openIds records)) ++
    lintOpenWork inputs ++ cycle.toList

end Repo.Plan
