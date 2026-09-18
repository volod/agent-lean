import Repo.Links
import AgentLeanTest.Fixture

/-! Tests for `Repo.Links`: path normalization, decoding and the repository link check. -/

open Repo.Links AgentLeanTest

#guard normalize? "docs/impl/../design/spec.md" == some "docs/design/spec.md"
#guard normalize? "/./a//b" == some "a/b"
#guard normalize? "a/../../b" == none
#guard percentDecode? "my%20file.md" == some "my file.md"
#guard percentDecode? "bad%2" == none
#guard percentDecode? "bad%zz" == none

#eval show IO Unit from do
  let files := [
    ("README.md", "[ok](docs/a.md#archive----core) [web](https://x.y) [self](#top)\n# Top\n"),
    ("docs/a.md", "# A\n## Archive -- `core`\n[bad](missing.md)\n[anchor](#nope)\n" ++
      "[up](../../x.md)\n[space](my%20file.md) [dir](../AgentLean)\n" ++
      "```\n[fenced](ignored.md)\n```\n"),
    ("docs/my file.md", "# Spaced\n"),
    ("AgentLean/Cli.lean", ""),
    (".git/notes.md", "[x](nowhere.md)"),
    (".lake/doc.md", "[x](nowhere.md)"),
    ("dist/doc.md", "[x](nowhere.md)"),
    ("AgentLeanTest/testdata/out.md", "[x](nowhere.md)")]
  let problems ← withTree files check
  let want := [
    "docs/a.md:3: broken link \"missing.md\"",
    "docs/a.md:4: missing anchor \"#nope\"",
    "docs/a.md:5: link \"../../x.md\" leaves the repository"]
  expect (problems == want) s!"problems:\n{"\n".intercalate problems}"
