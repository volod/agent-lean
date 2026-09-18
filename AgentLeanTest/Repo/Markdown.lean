import Repo.Markdown

/-! Tests for `Repo.Markdown`: lines, headings, GitHub anchors, links, tables and ids. -/

open Repo.Markdown

#guard lines "a\r\nb\n" == ["a", "b"]
#guard lines "a\n\nb" == ["a", "", "b"]
#guard lines "" == []
#guard splitFirst? "a -- b -- c" " -- " == some ("a", "b -- c")
#guard splitLast? "a -- b -- c" " -- " == some ("a -- b", "c")
#guard splitLast? "abc" " -- " == none
#guard isMarkdown "README.md" && isMarkdown "x.MD" && !isMarkdown "md" && !isMarkdown "a.mdx"

#guard slug "Project identity -- `project-identity`" == "project-identity----project-identity"
#guard slug "Run lock" == "run-lock"
#guard slug "Video -- Previews (v2.0)!" == "video----previews-v20"
#guard slug "snake_case and CAPS" == "snake_case-and-caps"

#guard heading? "## Notes ##" == some "Notes"
#guard heading? "#NoSpace" == none
#guard heading? "####### Seven" == none
#guard anchors "# Top\n## Notes\n```\n# Not a heading\n```\n## Notes ##\n#NoSpace\n" ==
  ["top", "notes", "notes-1"]

#guard linkTargets "[a](x.md) [b [c](y.md#z) ![img](i.png) [t](u \"title\") [r][ref] [e]()" ==
  ["x.md", "y.md#z", "i.png"]

#guard backtickedIds "`a-1` and `B` and `c` `open" == ["a-1", "c"]
#guard soleId? "`core`" == some "core"
#guard soleId? "`core` x" == none
#guard tableCells? "| a | `b` |" == some ["a", "`b`"]
#guard tableCells? "text" == none
#guard !isId "-lead" && !isId "" && isId "0001-x"
