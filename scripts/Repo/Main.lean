import Repo

/-!
# `lake exe repo`

Repository tooling, run from the repository root as `lake exe repo <command>`. It is never
shipped; see `docs/guide/development.md`.
-/

namespace Repo.Main

open System (FilePath)

/-- The usage text. -/
def usage : String := "\
Usage: lake exe repo <command>

Commands:
  ci           Required gate: lake build --wfail, lake test --wfail, then lint
  lint         Check planning documents, Markdown links and Lean style (`lake lint`)
  plan-status  Count open tasks and show the next eligible one
  dist         Build and archive the command for this host into dist/
               [--tag vX.Y.Z] (must equal the version)
  help         Show this help
"

/-- A repository command. -/
inductive Command where
  /-- The required gate. -/
  | ci
  /-- Planning and link checks. -/
  | lint
  /-- Open-work summary. -/
  | planStatus
  /-- Release archive for the host. -/
  | dist (options : Dist.Options)
  /-- Usage text. -/
  | help

/-- Parses the arguments after `repo`; the error is a usage message. -/
def Command.parse : List String → Except String Command
  | ["ci"] => .ok .ci
  | ["lint"] => .ok .lint
  | ["plan-status"] => .ok .planStatus
  | "dist" :: rest => .dist <$> Dist.Options.parse rest
  | ["help"] | ["-h"] | ["--help"] => .ok .help
  | [] => .error "missing command"
  | command :: _ => .error s!"unknown command or arguments: {command}"

/-- The capability registry, plan and task records agree, every relative Markdown link and
anchor resolves, and Lean sources keep the layout rules. Every check reports its problems on
stderr before any fails. -/
def lintRepository (root : FilePath) : IO Unit := do
  let (inputs, problems) ← Plan.load root
  let results := [("lint-spec-plan", problems ++ Plan.lint inputs),
    ("lint-doc-links", ← Links.check root),
    ("lint-lean-style", Style.check (← Tree.files root Style.isLean))]
  for (check, problems) in results do
    for problem in problems do IO.eprintln problem
    let verdict := if problems.isEmpty then "ok" else s!"{problems.length} problem(s)"
    IO.println s!"{check}: {verdict}"
  let failed := (results.filter (!·.2.isEmpty)).map (·.1)
  unless failed.isEmpty do throw <| IO.userError s!"{", ".intercalate failed} failed"

/-- Runs one command in the repository `root`. -/
def Command.run (root : FilePath) : Command → IO Unit
  | .ci => do
    runStep root "lake" ["build", "--wfail"]
    runStep root "lake" ["test", "--wfail"]
    lintRepository root
  | .lint => lintRepository root
  | .planStatus => do
    let (inputs, _) ← Plan.load root
    IO.print (Plan.Status.ofPlan inputs.plan).render
  | .dist options => do IO.println (← Dist.dist root options)
  | .help => IO.print usage

end Repo.Main

open Repo.Main in
/-- Runs one repository command from the current directory: exit `0` on success, `1` on failure
and `2` on invalid arguments. -/
def main (args : List String) : IO UInt32 := do
  match Command.parse args with
  | .error message =>
    IO.eprintln s!"repo: {message}\n\n{usage}"
    return 2
  | .ok command =>
    let root ← IO.currentDir
    unless ← (root / "lakefile.toml").pathExists do
      IO.eprintln "repo: run from the repository root, where lakefile.toml is"
      return 1
    try
      command.run root
      return 0
    catch err =>
      IO.eprintln s!"repo: {err}"
      return 1
