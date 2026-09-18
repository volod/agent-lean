/-!
# Build identity

The name, version, repository and platform of the running build. `BuildInfo.current` is the single
source of the release version: release tags and archive names are derived from it.
-/

namespace AgentLean

/-- Identity of one build of the command. -/
structure BuildInfo where
  /-- Package and command name. -/
  name : String
  /-- Release version, `MAJOR.MINOR.PATCH`. -/
  version : String
  /-- Repository URL. -/
  repository : String
  /-- Target triple the binary was built for, as Lean reports it. -/
  target : String
  deriving Repr, DecidableEq

namespace BuildInfo

/-- The identity of this build. -/
def current : BuildInfo where
  name := "agent-lean"
  version := "0.1.0"
  repository := "https://github.com/volod/agent-lean"
  target := System.Platform.target

/-- One line, for example
`agent-lean 0.1.0 (https://github.com/volod/agent-lean, x86_64-unknown-linux-gnu)`. -/
def render (info : BuildInfo) : String :=
  s!"{info.name} {info.version} ({info.repository}, {info.target})"

instance : ToString BuildInfo := ⟨render⟩

end BuildInfo

end AgentLean
