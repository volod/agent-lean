/-!
# Test fixtures

Assertions for `#eval` tests and throwaway file trees. An `#eval` that throws fails `lake test`.
-/

namespace AgentLeanTest

open System (FilePath)

/-- Fails the enclosing `#eval` with `message` unless `ok`. -/
def expect (ok : Bool) (message : String) : IO Unit :=
  unless ok do throw <| IO.userError message

/-- Writes one file below `root`, creating its parent directories. -/
def writeTree (root : FilePath) (path text : String) : IO Unit := do
  let file := root / path
  if let some parent := file.parent then IO.FS.createDirAll parent
  IO.FS.writeFile file text

/-- Runs `action` on a new temporary directory holding `files` as (relative path, text) pairs,
and removes the directory afterwards. -/
def withTree {α : Type} (files : List (String × String)) (action : FilePath → IO α) : IO α := do
  let root ← IO.FS.createTempDir
  try
    for (path, text) in files do writeTree root path text
    action root
  finally
    IO.FS.removeDirAll root

/-- A stream that fails every write, like a closed pipe. -/
def closedStream : IO.FS.Stream where
  flush := pure ()
  read _ := pure .empty
  write _ := throw <| IO.userError "closed"
  getLine := pure ""
  putStr _ := throw <| IO.userError "closed"
  isTty := pure false

/-- Runs `action` with two in-memory streams; returns its result and what it wrote to each. -/
def capture {α : Type} (action : IO.FS.Stream → IO.FS.Stream → IO α) :
    IO (α × String × String) := do
  let out ← IO.mkRef {}
  let err ← IO.mkRef {}
  let result ← action (.ofBuffer out) (.ofBuffer err)
  let text (buffer : IO.Ref IO.FS.Stream.Buffer) : IO String := do
    return String.fromUTF8! (← buffer.get).data
  return (result, ← text out, ← text err)

end AgentLeanTest
