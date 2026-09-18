import AgentLean

/-! Process wiring only: the arguments, the standard streams and the exit code. -/

/-- Runs the command line and exits with the code `AgentLean.Cli.run` returns. -/
def main (args : List String) : IO UInt32 := do
  AgentLean.Cli.run args (← IO.getStdout) (← IO.getStderr)
