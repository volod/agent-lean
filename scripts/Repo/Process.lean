/-!
# Child processes

Runs the build tools the repository commands wrap, echoing each command line.
-/

namespace Repo

/-- Runs `cmd args` in `cwd` with inherited streams, echoing the command line to stderr, and fails
unless it exits with `0`. -/
def runStep (cwd : System.FilePath) (cmd : String) (args : List String) : IO Unit := do
  let line := " ".intercalate (cmd :: args)
  IO.eprintln s!"$ {line}"
  let child ← IO.Process.spawn { cmd, args := args.toArray, cwd }
  let code ← child.wait
  unless code == 0 do throw <| IO.userError s!"{line}: exit code {code}"

end Repo
