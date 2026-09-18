import AgentLean.BuildInfo

/-!
# Command-line contract

Parsing, usage text, the standard streams and exit codes. This is the only module that writes to
stdout or stderr or decides an exit code. Commands return values and errors; `run` renders them.
-/

namespace AgentLean.Cli

/-- Exit code for success. -/
def exitOk : UInt32 := 0
/-- Exit code for a command that failed. -/
def exitFailure : UInt32 := 1
/-- Exit code for invalid arguments. -/
def exitUsage : UInt32 := 2

/-- A command the program accepts. -/
inductive Command where
  /-- Print the build identity. -/
  | version
  /-- Print the usage text. -/
  | help
  deriving Repr, DecidableEq

namespace Command

/-- Every command, in help order. -/
def all : List Command := [.version, .help]

/-- The word that selects the command. -/
def name : Command → String
  | .version => "version"
  | .help => "help"

/-- One line for the usage text. -/
def summary : Command → String
  | .version => "Print the build identity"
  | .help => "Print this help (also -h, --help)"

end Command

/-- Why the arguments are not a valid command line. -/
inductive UsageError where
  /-- No arguments were given. -/
  | missingCommand
  /-- The first argument names no command. -/
  | unknownCommand (word : String)
  /-- The command takes no arguments but got one. -/
  | unexpectedArgument (command : Command) (argument : String)
  deriving Repr, DecidableEq

/-- The message shown before the usage text. -/
def UsageError.message : UsageError → String
  | .missingCommand => "missing command"
  | .unknownCommand word => s!"unknown command '{word}'"
  | .unexpectedArgument command argument =>
    s!"'{command.name}' takes no arguments, got '{argument}'"

/-- Parses the arguments that follow the program name. -/
def parse (args : List String) : Except UsageError Command :=
  match args with
  | [] => .error .missingCommand
  | word :: rest =>
    let command? :=
      if word == "-h" || word == "--help" then some .help
      else Command.all.find? (·.name == word)
    match command?, rest with
    | none, _ => .error (.unknownCommand word)
    | some command, [] => .ok command
    | some command, argument :: _ => .error (.unexpectedArgument command argument)

/-- Every command is selected by its own name. -/
theorem parse_name (command : Command) : parse [command.name] = .ok command := by
  cases command <;> rfl

/-- The usage text, ending with a newline. -/
def usage : String :=
  let width := Command.all.foldl (fun w c => max w c.name.length) 0
  let line (c : Command) := s!"  {c.name.pushn ' ' (width - c.name.length)}  {c.summary}\n"
  s!"Usage: {BuildInfo.current.name} <command>\n\nCommands:\n" ++ String.join (Command.all.map line)

/-- Runs a parsed command, writing its result to `stdout`. -/
def execute (stdout : IO.FS.Stream) : Command → IO Unit
  | .version => stdout.putStrLn (toString BuildInfo.current) *> stdout.flush
  | .help => stdout.putStr usage *> stdout.flush

/-- Runs one command line and returns the process exit code. `args` excludes the program name. -/
def run (args : List String) (stdout stderr : IO.FS.Stream) : IO UInt32 := do
  -- A failed write to stderr has nowhere left to be reported; the exit code still is.
  let report (message : String) : IO Unit :=
    try stderr.putStr s!"{BuildInfo.current.name}: {message}\n" catch _ => pure ()
  match parse args with
  | .error err =>
    report s!"{err.message}\n\n{usage}"
    return exitUsage
  | .ok command =>
    try
      execute stdout command
      return exitOk
    catch err =>
      report (toString err)
      return exitFailure

end AgentLean.Cli
