import Repo.Markdown

/-!
# Planning model

The capability registry, the forward plan and the task records as data. The formats are defined in
`docs/guide/planning-workflow.md`.
-/

namespace Repo.Plan

/-- A top-level section of the plan. -/
inductive Lane where
  /-- `## Agent Implementation Tasks`. -/
  | agent
  /-- `## Human-Assisted Tasks`. -/
  | human
  deriving Repr, DecidableEq

namespace Lane

/-- The lane a `## ` heading opens, or `none` for any other heading. -/
def ofHeading? (line : String) : Option Lane :=
  match Markdown.trim line with
  | "## Agent Implementation Tasks" => some .agent
  | "## Human-Assisted Tasks" => some .human
  | _ => none

/-- Fields every task of the lane carries, in workflow order. -/
def requiredFields : Lane → List String
  | .agent => ["Serves", "Agent status", "Dependencies", "User-visible outcome", "Scope boundary",
      "Data and artifact paths", "Execution path", "Acceptance gates", "Documentation target",
      "Review checkpoint"]
  | .human => ["Serves", "Human status", "Dependencies", "Requested input or decision", "Unblocks"]

/-- The field that holds the task status. -/
def statusField : Lane → String
  | .agent => "Agent status"
  | .human => "Human status"

/-- Statuses valid in the lane. -/
def statuses : Lane → List String
  | .agent => ["CLEAR", "RUN NEEDED"]
  | .human => ["HUMAN-GATED", "BLOCKED BY HUMAN"]

instance : ToString Lane := ⟨fun | .agent => "agent" | .human => "human"⟩

end Lane

/-- One `#### task-id` block of the plan. -/
structure Task where
  /-- Stable task slug. -/
  id : String
  /-- Capability of the enclosing group heading; empty outside a group. -/
  capability : String
  /-- Lane the task sits in. -/
  lane : Lane
  /-- One-based line of the task heading. -/
  line : Nat
  /-- `- Field: value` pairs, most recent first. -/
  fields : List (String × String) := []
  deriving Repr

namespace Task

/-- A field value, or `""` when the field is missing. -/
def field (task : Task) (name : String) : String := (task.fields.lookup name).getD ""

/-- Backticked task ids in the `Dependencies` field; record links are not ids. -/
def dependencies (task : Task) : List String := Markdown.backtickedIds (task.field "Dependencies")

end Task

/-- One ``### Title -- `capability` `` heading inside a lane. -/
structure Group where
  /-- Capability id of the group. -/
  capability : String
  /-- Lane the group sits in. -/
  lane : Lane
  /-- One-based line of the heading. -/
  line : Nat
  deriving Repr

/-- The parsed forward plan. -/
structure Plan where
  /-- Capability groups in document order. -/
  groups : Array Group := #[]
  /-- Open tasks in document order. -/
  tasks : Array Task := #[]
  deriving Repr

/-- One row of the capability registry. -/
structure Capability where
  /-- Capability id. -/
  id : String
  /-- `planned` or `shipped`. -/
  status : String
  /-- Text of the implementation cell. -/
  implementation : String
  deriving Repr

/-- One task record file, named `NNNN-<group>-<task-id>.md`. -/
structure Record where
  /-- File name. -/
  file : String
  /-- Four-digit sequence. -/
  sequence : String
  /-- Task id from the file name. -/
  taskId : String
  /-- File contents. -/
  body : String := ""
  deriving Repr

/-- Everything a lint run reads. -/
structure Inputs where
  /-- Registry rows in implementation order. -/
  registry : List Capability
  /-- The forward plan. -/
  plan : Plan
  /-- Capability id to record group abbreviation. -/
  groups : List (String × String)
  /-- Task records sorted by file name. -/
  records : List Record
  /-- Text of the records README. -/
  recordIndex : String

end Repo.Plan
