# Running the convert scripts on Windows

These are bash scripts (macOS is the primary dev environment). To run them on
Windows you need a bash environment — **use Git Bash**, not WSL (see reasoning
below).

## 1. Install Git Bash

Install [Git for Windows](https://git-scm.com/download/win). This gives you:

- `bash` to run the `.sh` scripts
- GNU coreutils (`find`, `sed`, `grep`, `basename`, `dirname`, ...) that the
  scripts rely on

No WSL needed/recommended — see "Why Git Bash, not WSL" below.

**Important:** `bash` is *not* on the regular Windows PATH after installing
Git for Windows (only `Git\cmd` is added, not `Git\bin` where `bash.exe`
lives). So running `bash script.sh` from a plain PowerShell/cmd window will
fail with "bash is not recognized". Instead, either:

- Open **Git Bash** itself (Start Menu → "Git Bash", or right-click a folder
  in Explorer → "Git Bash Here") and run scripts from there with `./script.sh`
- or, from PowerShell, call it via the full path:
  `& "C:\Program Files\Git\bin\bash.exe" .\script.sh`

## 2. Install ffmpeg

Windows does not ship ffmpeg. Install it via winget:

```
winget install --id Gyan.FFmpeg
```

This installs the [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) "full"
build and adds it to your **User PATH** automatically. Open a **new**
terminal window afterwards (PATH changes only apply to new processes) and
verify:

```bash
ffmpeg -version
ffprobe -version
```

**If you still get `ffprobe: command not found` / `ffmpeg: command not
found`** in a "new" window: any terminal window that was already open
*before* the install still has the old PATH cached, and sometimes even
freshly-opened windows inherit a stale PATH from Explorer. Fully close all
terminal windows and open a new one; if it's still not found, log off and
back on (or reboot).

### Codec check: DXV / Hap encoders

`convertToWide.sh`, `convertToDXV.sh`, and `convertToHap.sh` encode to `dxv`
and/or `hap`. Confirmed on this machine: the `Gyan.FFmpeg` winget build
(9.0.1, "full_build") includes **both** `dxv` and `hap` encoders out of the
box — no extra/custom build needed:

```bash
ffmpeg -hide_banner -encoders | grep -i dxv   # -> dxv    Resolume DXV
ffmpeg -hide_banner -encoders | grep -i hap   # -> hap    Vidvox Hap
```

If you ever switch to a different ffmpeg source, re-run this check — not all
builds include `dxv` (it's a proprietary Resolume codec).

## 3. Thumbnail generation (`h264_videotoolbox` → `libx264` on Windows)

`convertToDXV.sh` and `convertToHap.sh` generate a thumbnail `.mov` using a
hardware encoder. `h264_videotoolbox` is Apple-only hardware acceleration
and doesn't exist on Windows, so both scripts now auto-detect the OS and use
`libx264` (software H.264, included in the ffmpeg build above) on Windows
instead — no manual steps needed, and macOS behavior (`h264_videotoolbox`)
is unchanged.

`createThumbnail.sh` still has macOS-only hardcoded paths (`/Volumes/...`)
and isn't currently set up to run cross-platform — let me know if that one
needs the same treatment.

## 4. Running a script

From Git Bash, in this folder:

```bash
bash convertToWide.sh
```

(or `& "C:\Program Files\Git\bin\bash.exe" .\convertToWide.sh` from
PowerShell — see the PATH note above.)

When prompted for the input folder, any of these work:

```
D:\Postfach\vj\_assets\1_dxv      (pasted straight from Explorer)
D:/Postfach/vj/_assets/1_dxv
/d/Postfach/vj/_assets/1_dxv
```

(All scripts' `read` prompts use `-r`, so backslashes in a pasted Windows
path are kept literally instead of being eaten as escape characters — Git
Bash's MSYS layer then translates the Windows-style path automatically.)

Unlike on macOS, there's no default path suggestion on Windows — you must
type/paste the full path each time.

Note: `convertToWide.sh`, `convertToDXV.sh`, `convertToH264.sh`, and
`convertToHap.sh` used to remap `inputFolder` → `outputFolder` via a `sed`
regex substitution, which broke (`sed: Invalid back reference`) on any
Windows path containing a backslash followed by a digit (e.g. `...\0_orig\...`).
This is now done with plain bash substring slicing instead, which has no
regex/escaping pitfalls and works identically on macOS.

## Why Git Bash, not WSL

- The Python script driving Resolume Arena talks to it over `localhost`.
  Resolume is a native Windows app, and Git Bash's Python runs natively on
  Windows too, so `localhost` just works. WSL2 runs in its own network
  namespace, which can complicate reaching a Windows-side `localhost` service.
- ffmpeg here processes video files living on the Windows filesystem
  (`D:\...`). Git Bash reads/writes those natively at full disk speed.
  WSL2 accessing Windows drives via `/mnt/d/...` has a known I/O performance
  penalty, especially noticeable with large video files.
