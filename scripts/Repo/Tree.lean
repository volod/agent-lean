/-!
# Repository files

The source files the checks read: everything below the root except build output, vendored code,
product samples and hidden directories.
-/

namespace Repo.Tree

open System (FilePath)

/-- Directories never scanned: release output, vendored code and product samples. Hidden
directories other than `.github`, such as `.lake` and `.git`, are skipped too. -/
def skippedDirs : List String := ["dist", "vendor", "node_modules", "testdata"]

/-- Whether the checks scan a directory with this name. -/
def scanned (name : String) : Bool :=
  (!name.startsWith "." || name == ".github") && !skippedDirs.contains name

/-- Every scanned file below `root` whose name satisfies `keep`, with its text, keyed by
`/`-separated relative path and sorted by it. -/
def files (root : FilePath) (keep : String → Bool) : IO (List (String × String)) := do
  let enter (dir : FilePath) : IO Bool := pure (dir == root || dir.fileName.any scanned)
  let rootLength := root.toString.length + 1
  let mut found := #[]
  for path in ← root.walkDir enter do
    if keep (path.fileName.getD "") && !(← path.isDir) then
      let relative := String.ofList <| (path.toString.drop rootLength).toString.toList.map
        fun c => if c == '\\' then '/' else c
      found := found.push (relative, ← IO.FS.readFile path)
  return (found.qsort (·.1 < ·.1)).toList

end Repo.Tree
