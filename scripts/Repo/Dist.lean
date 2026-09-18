import AgentLean.BuildInfo
import Repo.Process

/-!
# Release archives

`lake exe repo dist` builds the command for the host and archives it with `README.md` and
`LICENSE` into `dist/`. Lake does not cross-compile, so each release target is built on its own
runner.
-/

namespace Repo.Dist

open System (FilePath)
open AgentLean (BuildInfo)

/-- Options of `dist`. -/
structure Options where
  /-- Release tag that must equal `v` followed by the version, checked before building. -/
  tag : Option String := none
  deriving Repr, DecidableEq

/-- Parses the arguments after `dist`. -/
def Options.parse : List String → Except String Options
  | [] => .ok {}
  | ["--tag", tag] => .ok { tag := some tag }
  | args => .error s!"dist takes [--tag vX.Y.Z], got {" ".intercalate args}"

/-- Fails unless `tag` is `v` followed by `version`. -/
def checkTag (version tag : String) : Except String Unit :=
  if tag == s!"v{version}" then .ok ()
  else .error s!"tag {tag} does not match version {version}; want v{version}"

/-- Whether a target triple names Windows. -/
def isWindowsTarget (target : String) : Bool := (target.splitOn "-").contains "windows"

/-- `<name>-<version>-<target>`: the archive's top directory and file name stem. -/
def archiveStem (info : BuildInfo) : String := s!"{info.name}-{info.version}-{info.target}"

/-- The archive file name: `.zip` for Windows targets, `.tar.gz` otherwise. -/
def archiveName (info : BuildInfo) : String :=
  archiveStem info ++ if isWindowsTarget info.target then ".zip" else ".tar.gz"

/-- Copies one file, keeping it executable when `executable` is set. -/
private def copyFile (source target : FilePath) (executable : Bool) : IO Unit := do
  IO.FS.writeBinFile target (← IO.FS.readBinFile source)
  if executable then
    let rwx : IO.AccessRight := { read := true, write := true, execution := true }
    let rx : IO.AccessRight := { read := true, execution := true }
    IO.setAccessRights target { user := rwx, group := rx, other := rx }

/-- The `tar` to run. On Windows it is the system bsdtar, which writes zip archives, rather than
a GNU tar that a Git shell puts earlier on `PATH`. -/
def tarCommand : IO String := do
  if System.Platform.isWindows then
    if let some systemRoot ← IO.getEnv "SystemRoot" then
      return (FilePath.mk systemRoot / "System32" / "tar.exe").toString
  return "tar"

/-- Builds the command and writes its archive under `root/dist`; returns the archive path. -/
def dist (root : FilePath) (options : Options) : IO FilePath := do
  let info := BuildInfo.current
  if let some tag := options.tag then
    if let .error message := checkTag info.version tag then throw <| IO.userError message
  runStep root "lake" ["build", info.name]
  let exe := if isWindowsTarget info.target then s!"{info.name}.exe" else info.name
  let stem := archiveStem info
  let distDir := root / "dist"
  let staging := distDir / stem
  if ← staging.pathExists then IO.FS.removeDirAll staging
  IO.FS.createDirAll staging
  copyFile (root / ".lake" / "build" / "bin" / exe) (staging / exe) true
  for file in ["README.md", "LICENSE"] do
    copyFile (root / file) (staging / file) false
  let archive := archiveName info
  let flags := if isWindowsTarget info.target then "-acf" else "-czf"
  runStep distDir (← tarCommand) [flags, archive, stem]
  IO.FS.removeDirAll staging
  return distDir / archive

end Repo.Dist
