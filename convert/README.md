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

## 3. Previewing DXV/Hap folders: contact sheets, not per-file thumbnails

`convertToDXV.sh`, `convertToHap.sh`, and `convertToWide.sh` used to each
generate a `__thumbs_mov` subfolder with a per-video H.264 preview file.
That's been removed — instead, use `../contactsheet/createContactSheet.sh`
to generate one `_contactsheet.jpg` overview image per folder (a grid of
one frame from each video in it), viewable directly in Explorer/Finder
without decoding DXV/Hap at all:

```bash
../contactsheet/createContactSheet.sh --folder /path/to/folder
```

It recurses the same way the convert scripts do, and writes into a sibling
`<folder>_contactsheets` directory. See that folder for details.

`createThumbnail.sh` still has macOS-only hardcoded paths (`/Volumes/...`)
and predates this change — it generates a single JPEG for one hardcoded
file and isn't part of the per-folder preview flow above.

## 4. Running a script

All scripts take the input folder as a `--folder` argument (no more
interactive prompt):

```bash
bash convertToWide.sh --folder /d/Postfach/vj/_assets/1_dxv
```

(or `& "C:\Program Files\Git\bin\bash.exe" .\convertToWide.sh --folder D:\Postfach\vj\_assets\1_dxv`
from PowerShell — see the PATH note above.)

`--folder <path>` and `--folder=<path>` both work. Any path style works too:

```
--folder "D:\Postfach\vj\_assets\1_dxv"   (pasted straight from Explorer)
--folder D:/Postfach/vj/_assets/1_dxv
--folder /d/Postfach/vj/_assets/1_dxv
```

Quote the path if it contains spaces. `--folder` is required — running a
script without it prints a usage message and exits (no more default path,
on macOS or Windows).

Note: `convertToWide.sh`, `convertToDXV.sh`, `convertToH264.sh`, and
`convertToHap.sh` remap `inputFolder` → `outputFolder` via plain bash
substring slicing (not `sed`/regex), so paths with special characters
(including backslashes followed by a digit, e.g. `...\0_orig\...`, which
previously crashed `sed` with `Invalid back reference`) are handled safely.

## Why Git Bash, not WSL

- The Python script driving Resolume Arena talks to it over `localhost`.
  Resolume is a native Windows app, and Git Bash's Python runs natively on
  Windows too, so `localhost` just works. WSL2 runs in its own network
  namespace, which can complicate reaching a Windows-side `localhost` service.
- ffmpeg here processes video files living on the Windows filesystem
  (`D:\...`). Git Bash reads/writes those natively at full disk speed.
  WSL2 accessing Windows drives via `/mnt/d/...` has a known I/O performance
  penalty, especially noticeable with large video files.
