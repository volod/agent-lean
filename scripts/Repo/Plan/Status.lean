import Repo.Plan.Model

/-!
# Plan status

Open-work summary: task counts and the tasks that may start now.
-/

namespace Repo.Plan

/-- Summary of the open plan. -/
structure Status where
  /-- Open agent tasks. -/
  agentTasks : Nat
  /-- Open human tasks. -/
  humanTasks : Nat
  /-- Agent tasks with no open dependency, in plan order. -/
  eligible : List Task
  /-- Human tasks with no open dependency, in plan order. -/
  waitingHuman : List Task

namespace Status

/-- Counts and eligibility. A dependency on any open task, agent or human, blocks; accepted
records never block. -/
def ofPlan (plan : Plan) : Status :=
  let tasks := plan.tasks.toList
  let openIds := tasks.map (·.id)
  let ready := tasks.filter fun t => !t.dependencies.any openIds.contains
  let inLane (lane : Lane) (ts : List Task) := ts.filter (·.lane == lane)
  { agentTasks := (inLane .agent tasks).length
    humanTasks := (inLane .human tasks).length
    eligible := inLane .agent ready
    waitingHuman := inLane .human ready }

/-- The report `plan-status` prints, one fact per line. -/
def render (s : Status) : String :=
  let total := s.agentTasks + s.humanTasks
  let counts := s!"open tasks: {total} ({s.agentTasks} agent, {s.humanTasks} human)\n"
  let next := match s.eligible with
    | [] => "next agent task: none eligible\n"
    | next :: others =>
      s!"next agent task: {next.id} ({next.capability}, {next.field "Agent status"})\n" ++
        if others.isEmpty then "" else s!"also eligible: {", ".intercalate (others.map (·.id))}\n"
  let human := s.waitingHuman.map fun t =>
    s!"human action available: {t.id} ({t.field "Human status"})\n"
  counts ++ next ++ String.join human

end Status

end Repo.Plan
