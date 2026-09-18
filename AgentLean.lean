import AgentLean.BuildInfo
import AgentLean.Cli

/-!
# agent-lean

A template for Lean 4 projects built by people and coding agents. `Main.lean` only wires the
process. `AgentLean.Cli` owns the command-line contract; every other module takes typed input and
returns typed values and errors to it. This root module imports every product module.
-/
