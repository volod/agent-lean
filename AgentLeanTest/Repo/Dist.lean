import Repo.Dist
import Repo.Main

/-! Tests for `Repo.Dist` and the `repo` command line: options, the tag check, archive names. -/

open Repo.Dist

#guard (Options.parse []).toOption == some {}
#guard (Options.parse ["--tag", "v1.2.3"]).toOption == some { tag := some "v1.2.3" }
#guard (Options.parse ["--tag"]).toOption.isNone
#guard (Options.parse ["--target", "x"]).toOption.isNone

#guard (checkTag "1.2.3" "v1.2.3").toOption.isSome
#guard (checkTag "1.2.3" "v1.2.4").toOption.isNone
#guard (checkTag "1.2.3" "1.2.3").toOption.isNone

def info (target : String) : AgentLean.BuildInfo :=
  { name := "app", version := "1.2.3", repository := "", target }

#guard archiveName (info "x86_64-unknown-linux-gnu") == "app-1.2.3-x86_64-unknown-linux-gnu.tar.gz"
#guard archiveName (info "x86_64-w64-windows-gnu") == "app-1.2.3-x86_64-w64-windows-gnu.zip"

open Repo.Main in
#guard [[], ["bogus"], ["ci", "extra"], ["dist", "--bogus"]].all
  fun args => (Command.parse args).toOption.isNone
