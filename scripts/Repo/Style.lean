import Repo.Markdown

/-!
# Lean source style

The layout rules Lean has no formatter for: lines of at most 100 characters, no tabs and no
trailing whitespace.
-/

namespace Repo.Style

/-- The longest line allowed in a Lean file, in characters. -/
def maxLineLength : Nat := 100

/-- Whether a file name is Lean source. -/
def isLean (name : String) : Bool := name.endsWith ".lean"

/-- The style problems of one line, without its location. -/
def lineProblems (line : String) : List String :=
  (if line.length > maxLineLength then
    [s!"line has {line.length} characters, the limit is {maxLineLength}"] else []) ++
  (if line.contains '\t' then ["tab character"] else []) ++
  (if line.endsWith " " then ["trailing whitespace"] else [])

/-- One problem per style violation in `files`, given as (relative path, text) pairs. -/
def check (files : List (String × String)) : List String :=
  files.flatMap fun (path, text) =>
    (Markdown.lines text).zipIdx.flatMap fun (line, n) =>
      (lineProblems line).map (s!"{path}:{n + 1}: " ++ ·)

end Repo.Style
