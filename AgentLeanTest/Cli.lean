import AgentLean
import AgentLeanTest.Fixture

/-! Tests for `AgentLean.Cli` and `AgentLean.BuildInfo`: parsing, streams and exit codes. -/

open AgentLean AgentLean.Cli AgentLeanTest

#guard parse ["version"] matches .ok .version
#guard parse ["help"] matches .ok .help
#guard parse ["-h"] matches .ok .help
#guard parse ["--help"] matches .ok .help
#guard parse [] matches .error .missingCommand
#guard parse ["nope"] matches .error (.unknownCommand "nope")
#guard parse ["--nope"] matches .error (.unknownCommand "--nope")
#guard parse ["version", "x"] matches .error (.unexpectedArgument .version "x")

-- Every command is listed exactly once, so the usage text names each one.
example : Command.all.length = 2 := rfl
#guard Command.all.all fun c => usage.contains s!"  {c.name}  "

#guard BuildInfo.render
    { name := "app", version := "1.2.3", repository := "https://example.com/app",
      target := "x86_64-unknown-linux-gnu" } ==
  "app 1.2.3 (https://example.com/app, x86_64-unknown-linux-gnu)"
#guard BuildInfo.current.name == "agent-lean"
#guard BuildInfo.current.target == System.Platform.target

/--
info: Usage: agent-lean <command>

Commands:
  version  Print the build identity
  help     Print this help (also -h, --help)
-/
#guard_msgs in
#eval IO.print usage

-- (arguments, exit code, stdout substring, stderr substring); "" means the stream stays empty.
#eval show IO Unit from do
  let cases : List (List String × UInt32 × String × String) := [
    (["version"], exitOk, "agent-lean 0.1.0 (https://github.com/volod/agent-lean, ", ""),
    (["help"], exitOk, "Usage:", ""),
    (["--help"], exitOk, "Usage:", ""),
    ([], exitUsage, "", "agent-lean: missing command"),
    (["nope"], exitUsage, "", "unknown command 'nope'"),
    (["version", "x"], exitUsage, "", "'version' takes no arguments, got 'x'")]
  for (args, code, out, err) in cases do
    let (got, stdout, stderr) ← capture (run args)
    let expectStream (name got want : String) :=
      expect (if want.isEmpty then got.isEmpty else got.contains want)
        s!"{args}: {name} = {got.quote}, want {want.quote}"
    expect (got == code) s!"{args}: exit code {got}, want {code}; stderr: {stderr}"
    expectStream "stdout" stdout out
    expectStream "stderr" stderr err

-- A failed write is a failure, reported on stderr.
#eval show IO Unit from do
  let (code, _, stderr) ← capture fun _ stderr => run ["version"] closedStream stderr
  expect (code == exitFailure) s!"exit code {code}, want {exitFailure}"
  expect (stderr.startsWith "agent-lean: ") s!"stderr = {stderr.quote}"
