/-!
# Markdown reading

The little Markdown reading the planning and link checks share: lines, fenced code, headings,
GitHub anchors, inline links, table rows and backticked ids, plus the `String` operations they use.
-/

namespace Repo.Markdown

/-- `s` without leading and trailing ASCII whitespace. -/
def trim (s : String) : String := s.trimAscii.toString

/-- `s` without the prefix `p`, or `none` when `s` does not start with it. -/
def dropPrefix? (s p : String) : Option String := (s.dropPrefix? p).map (·.toString)

/-- `s` without the suffix `p`, or `none` when `s` does not end with it. -/
def dropSuffix? (s p : String) : Option String := (s.dropSuffix? p).map (·.toString)

/-- Splits `s` around the first occurrence of `sep`. -/
def splitFirst? (s sep : String) : Option (String × String) :=
  match s.splitOn sep with
  | first :: rest@(_ :: _) => some (first, sep.intercalate rest)
  | _ => none

/-- Splits `s` around the last occurrence of `sep`. -/
def splitLast? (s sep : String) : Option (String × String) :=
  match (s.splitOn sep).reverse with
  | last :: rest@(_ :: _) => some (sep.intercalate rest.reverse, last)
  | _ => none

/-- The lines of `text` without `\n` or `\r\n` terminators. -/
def lines (text : String) : List String :=
  if text.isEmpty then []
  else
    let parts := (text.splitOn "\n").map fun line => ((line.dropSuffix? "\r").getD line).toString
    if text.endsWith "\n" then parts.dropLast else parts

/-- Whether a file name has the `.md` extension, in any case. -/
def isMarkdown (name : String) : Bool :=
  (System.FilePath.mk name).extension.any (·.toLower == "md")

/-- The lines of `text` with fenced code blocks blanked, so line numbers stay aligned. -/
def proseLines (text : String) : List String :=
  let step (acc : List String × Bool) (line : String) : List String × Bool :=
    let (out, inFence) := acc
    if line.trimAsciiStart.toString.startsWith "```" then ("" :: out, !inFence)
    else if inFence then ("" :: out, inFence)
    else (line :: out, inFence)
  ((lines text).foldl step ([], false)).1.reverse

/-- The text of an ATX heading (`## Title`), or `none` for any other line. -/
def heading? (line : String) : Option String :=
  let level := (line.toList.takeWhile (· == '#')).length
  let rest := (line.drop level).toString
  if level < 1 || level > 6 || !(rest.startsWith " " || rest.startsWith "\t") then none
  else
    let text := trim ((trim rest).dropEndWhile (· == '#')).toString
    if text.isEmpty then none else some text

/-- The GitHub anchor of a heading. -/
def slug (heading : String) : String :=
  String.ofList <| heading.toLower.toList.filterMap fun c =>
    if c == ' ' then some '-'
    else if c == '-' || c == '_' || c.isAlphanum then some c
    else none

/-- The anchor of every heading in `text`, with GitHub's `-1`, `-2` suffixes for repeats. -/
def anchors (text : String) : List String :=
  let step (acc : List String × List String) (slug : String) : List String × List String :=
    let (out, seen) := acc
    let n := seen.count slug
    ((if n == 0 then slug else s!"{slug}-{n}") :: out, slug :: seen)
  (((proseLines text).filterMap heading?).map slug |>.foldl step ([], [])).1.reverse

/-- The characters before the first `c` and those after it, or `none` without a `c`. -/
private def splitAtChar? (chars : List Char) (c : Char) : Option (List Char × List Char) :=
  (chars.idxOf? c).map fun i => (chars.take i, chars.drop (i + 1))

/-- After an opening `[`: the target of `text](target)` and the rest of the line. -/
private def linkAfterOpen? (chars : List Char) : Option (String × List Char) := do
  let (_, rest) ← splitAtChar? chars ']'
  let '(' :: tail := rest | none
  let (target, after) ← splitAtChar? tail ')'
  if target.isEmpty || target.any Char.isWhitespace then none
  else some (String.ofList target, after)

/-- The targets of the inline links (`[text](target)`) in one line. -/
def linkTargets (line : String) : List String :=
  go line.length line.toList
where
  /-- Scans `chars`; `fuel` bounds the steps, since every step consumes a character. -/
  go : Nat → List Char → List String
    | 0, _ | _, [] => []
    | fuel + 1, c :: rest =>
      if c != '[' then go fuel rest
      else match linkAfterOpen? rest with
        | some (target, after) => target :: go fuel after
        | none => go fuel rest

/-- The trimmed cells of a table row, or `none` when the line is not a row. -/
def tableCells? (line : String) : Option (List String) := do
  let inner ← dropPrefix? (trim line) "|"
  let inner := (dropSuffix? inner "|").getD inner
  return (inner.splitOn "|").map trim

/-- Whether `s` is an id: lowercase ASCII letters, digits and inner hyphens. -/
def isId (s : String) : Bool :=
  match s.toList with
  | [] => false
  | first :: rest =>
    (first.isLower || first.isDigit) && rest.all fun c => c.isLower || c.isDigit || c == '-'

/-- Every backticked id in `text`, in order. -/
def backtickedIds (text : String) : List String :=
  let parts := text.splitOn "`"
  parts.zipIdx.filterMap fun (part, i) =>
    if i % 2 == 1 && i + 1 < parts.length && isId part then some part else none

/-- The id when `cell` is exactly one backticked id. -/
def soleId? (cell : String) : Option String := do
  let id ← dropSuffix? (← dropPrefix? cell "`") "`"
  if isId id then some id else none

end Repo.Markdown
