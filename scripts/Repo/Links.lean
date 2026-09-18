import Repo.Markdown
import Repo.Tree

/-!
# Documentation links

Relative Markdown links and heading anchors must resolve inside the repository.
-/

namespace Repo.Links

open System (FilePath)
open Repo.Markdown

/-- Resolves `.` and `..` in a `/`-separated path; `none` when it climbs above the root. -/
def normalize? (path : String) : Option String := do
  let step (parts : List String) (part : String) : Option (List String) :=
    match part, parts with
    | "", _ | ".", _ => some parts
    | "..", [] => none
    | "..", _ :: rest => some rest
    | _, _ => some (part :: parts)
  let parts ← (path.splitOn "/").foldlM step []
  return "/".intercalate parts.reverse

/-- The value of one hexadecimal digit given as an ASCII byte. -/
private def hexDigit? (b : UInt8) : Option UInt8 :=
  if 48 ≤ b && b ≤ 57 then some (b - 48)
  else if 65 ≤ b && b ≤ 70 then some (b - 55)
  else if 97 ≤ b && b ≤ 102 then some (b - 87)
  else none

/-- Decodes `%XX` escapes; `none` for a malformed escape or invalid UTF-8. -/
def percentDecode? (s : String) : Option String := do
  String.fromUTF8? ⟨(← go s.toUTF8.toList).toArray⟩
where
  /-- Decodes a byte list. -/
  go : List UInt8 → Option (List UInt8)
    | [] => some []
    | 37 :: hi :: lo :: rest => do
      return ((← hexDigit? hi) * 16 + (← hexDigit? lo)) :: (← go rest)
    | 37 :: _ => none
    | b :: rest => (b :: ·) <$> go rest

/-- The problem with one link target in the Markdown file `source`, or `none` when it resolves.
`anchors` maps every scanned Markdown path to its heading anchors. -/
def checkLink (root : FilePath) (source target : String)
    (anchors : List (String × List String)) : IO (Option String) := do
  if target.contains "://" || target.startsWith "mailto:" then return none
  let (file, anchor) := (splitFirst? target "#").getD (target, "")
  let resolved ← if file.isEmpty then pure source else do
    let some decoded := percentDecode? file | return some s!"bad link {target.quote}"
    let dir := ((splitLast? source "/").map (·.1)).getD ""
    let some resolved := normalize? s!"{dir}/{decoded}"
      | return some s!"link {target.quote} leaves the repository"
    unless ← (root / resolved).pathExists do return some s!"broken link {target.quote}"
    pure resolved
  -- Anchors into files that are not scanned Markdown are not checked.
  let some known := anchors.lookup resolved | return none
  if anchor.isEmpty || known.contains anchor then return none
  return some s!"missing anchor {target.quote}"

/-- One problem per broken relative link or anchor in the repository's Markdown files. -/
def check (root : FilePath) : IO (List String) := do
  let docs ← Tree.files root isMarkdown
  let anchors := docs.map fun (path, text) => (path, Markdown.anchors text)
  let mut problems := #[]
  for (path, text) in docs do
    for (line, n) in (proseLines text).zipIdx do
      for target in linkTargets line do
        if let some problem ← checkLink root path target anchors then
          problems := problems.push s!"{path}:{n + 1}: {problem}"
  return problems.toList

end Repo.Links
