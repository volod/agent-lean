import Repo.Style

/-! Tests for `Repo.Style`: line length, tabs and trailing whitespace. -/

open Repo.Style

#guard lineProblems (String.ofList (List.replicate 100 'x')) == []
#guard lineProblems (String.ofList (List.replicate 101 'x')) ==
  ["line has 101 characters, the limit is 100"]
#guard lineProblems "\tdef x := 1 " == ["tab character", "trailing whitespace"]
#guard isLean "Cli.lean" && !isLean "Cli.olean.md"
#guard check [("A.lean", "ok\nbad \n")] == ["A.lean:2: trailing whitespace"]
