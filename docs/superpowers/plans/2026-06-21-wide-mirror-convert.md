# Wide Mirror Convert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `convert/convertToWide.sh` — a script that takes a folder of DXV video files and produces a 3840×384 mirror-tiled widescreen version of each, encoded as DXV.

**Architecture:** The script prompts for an input folder, mirrors the directory structure into `<input>_wide`, then for each video file builds a dynamic FFmpeg filter_complex that splits the video into alternating original/flipped copies, hstacks them into a strip wider than 3840px, and center-crops to exactly 3840×384. Commands are collected into a string and executed once with `eval`.

**Tech Stack:** bash, ffmpeg, ffprobe

## Global Constraints

- Output codec: `dxv`, no audio (`-an`)
- Output container: `.mov`
- Output size: exactly 3840×384 (both multiples of 16 — DXV requirement is satisfied)
- Output FPS: 30 (forced via `-r 30` and `fps=30` in filtergraph)
- Square pixels: `setsar=1` in filtergraph
- Skip files inside `__thumbs_mov` folders
- Skip non-video files entirely (no copy)
- Video extensions to process: `.mov`, `.mkv`, `.mp4`, `.avi`, `.gif`, `.webm`
- Follow `convert/convertToDXV.sh` conventions: `printf -v ... "%q"` for path escaping, `eval "$finalCommand"` at end

---

### Task 1: Script scaffold — input prompt, output folder, directory mirroring

**Files:**
- Create: `convert/convertToWide.sh`

**Interfaces:**
- Produces: `$inputFolder`, `$outputFolder`, mirrored directory structure, `$finalCommand` variable initialised to `""`

- [ ] **Step 1: Create the script file**

```bash
#!/bin/bash

finalCommand=""

# Catch trailing slash from user input
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj/_assets/1_dxv] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj/_assets/1_dxv"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present

echo "$inputFolder"

# Create output folder next to input
outputFolder="${inputFolder}_wide"
mkdir -p "$outputFolder"

# Process directories first to ensure structure
find "$inputFolder" -type d | while read -r dir; do
  targetDir="${dir/$inputFolder/$outputFolder}"
  mkdir -p "$targetDir"
done
```

Save to `convert/convertToWide.sh` and make executable:
```bash
chmod +x /Users/david/Desktop/vj/ffmpegConvert/convert/convertToWide.sh
```

- [ ] **Step 2: Test scaffold**

Run:
```bash
bash /Users/david/Desktop/vj/ffmpegConvert/convert/convertToWide.sh
```
Accept the default path. Expected: a new folder `/Users/david/Desktop/vj/_assets/1_dxv_wide` appears with the same subfolder structure as `1_dxv` but no files yet. Verify:
```bash
ls /Users/david/Desktop/vj/_assets/1_dxv_wide/
# should show: 2023_05_12_stwst  2023_11_24_stwst  ...
find /Users/david/Desktop/vj/_assets/1_dxv_wide -type f | wc -l
# should show: 0
```

- [ ] **Step 3: Commit**

```bash
git add convert/convertToWide.sh
git commit -m "feat: add convertToWide.sh scaffold with directory mirroring"
```

---

### Task 2: Per-file filtergraph function

**Files:**
- Modify: `convert/convertToWide.sh`

**Interfaces:**
- Consumes: `$inputFolder`, `$outputFolder`, `$finalCommand` (from Task 1)
- Produces: `addToFinalCommand()` function that appends one FFmpeg command per file to `$finalCommand`

The mirror pattern for `n_per_side=2` (total=5 streams, W=400px → strip=2000px):
```
index: 0(dist=2,orig) | 1(dist=1,flip) | 2(center,orig) | 3(dist=1,flip) | 4(dist=2,orig)
```
This produces seamless mirror tiling: `orig | flip | ORIG | flip | orig`.

- [ ] **Step 1: Add the function after the `finalCommand=""` line**

Add this function to `convert/convertToWide.sh`, between `finalCommand=""` and the `read` prompt:

```bash
addToFinalCommand() {
  local fspec="$1"
  local fnameWithExt
  fnameWithExt=$(basename "$fspec")
  local folderToOrig
  folderToOrig=$(dirname "$fspec")
  local fnameWithoutExt="${fnameWithExt%.*}"

  # escape special characters
  local fileOrig
  printf -v fileOrig "%q" "$fspec"

  # replace path to get targetFolder
  local fileTargetFolder
  fileTargetFolder=$(sed "s|$inputFolder|$outputFolder|" <<<"$folderToOrig")
  local fileTarget
  printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithoutExt.mov"

  # get video dimensions
  local W H
  W=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fspec")
  H=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fspec")

  # ceil(3840 / W) copies per side
  local n_per_side=$(( (3840 + W - 1) / W ))
  local total=$(( 2 * n_per_side + 1 ))
  local strip_width=$(( W * total ))
  local crop_x=$(( (strip_width - 3840) / 2 ))
  local crop_y=$(( (H - 384) / 2 ))

  # build split filter
  local filter="[0:v]split=${total}"
  for (( i=0; i<total; i++ )); do
    filter="${filter}[s${i}]"
  done
  filter="${filter};"

  # apply hflip to streams at odd distance from center; build hstack input list
  local stack_inputs=""
  for (( i=0; i<total; i++ )); do
    local dist=$(( i < n_per_side ? n_per_side - i : i - n_per_side ))
    if (( dist % 2 == 1 )); then
      filter="${filter}[s${i}]hflip[f${i}];"
      stack_inputs="${stack_inputs}[f${i}]"
    else
      stack_inputs="${stack_inputs}[s${i}]"
    fi
  done

  # hstack → crop width → crop height → setsar → fps
  filter="${filter}${stack_inputs}hstack=inputs=${total}[wide];"
  filter="${filter}[wide]crop=3840:${H}:${crop_x}:0[cw];"
  filter="${filter}[cw]crop=3840:384:0:${crop_y}[co];"
  filter="${filter}[co]fps=30,setsar=1[out]"

  finalCommand="$finalCommand ffmpeg -i $fileOrig -filter_complex \"${filter}\" -map \"[out]\" -an -c:v dxv -r 30 $fileTarget; "
}
```

- [ ] **Step 2: Test the function on one file**

Temporarily add this at the bottom of the script (after the function, before the `read` prompt) to test in isolation:

```bash
inputFolder="/Users/david/Desktop/vj/_assets/1_dxv"
outputFolder="/tmp/wide_test"
mkdir -p "$outputFolder/2023_05_12_stwst/twitter"
addToFinalCommand "/Users/david/Desktop/vj/_assets/1_dxv/2023_05_12_stwst/twitter/protobacillus-1655400210300915713-20230508_043220-gif1.mov"
eval "$finalCommand"
```

Run:
```bash
bash /Users/david/Desktop/vj/ffmpegConvert/convert/convertToWide.sh
```

Then verify the output:
```bash
ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,codec_name,r_frame_rate -of csv=p=0 \
  "/tmp/wide_test/2023_05_12_stwst/twitter/protobacillus-1655400210300915713-20230508_043220-gif1.mov"
# Expected output: 3840,384,dxv,30/1
```

- [ ] **Step 3: Remove the temporary test lines** added in Step 2

- [ ] **Step 4: Commit**

```bash
git add convert/convertToWide.sh
git commit -m "feat: add mirror-tile filtergraph function to convertToWide.sh"
```

---

### Task 3: File loop and final wiring

**Files:**
- Modify: `convert/convertToWide.sh`

**Interfaces:**
- Consumes: `addToFinalCommand()`, `$inputFolder`, `$outputFolder`, `$finalCommand` (from Tasks 1–2)
- Produces: complete, runnable script

- [ ] **Step 1: Add file loop and eval at the end of the script**

Append after the directory-mirroring `find` block:

```bash
# Process video files (skip __thumbs_mov folders)
while IFS= read -r -d '' file; do
  ext="${file##*.}"
  if [[ "$ext" == "mov" || "$ext" == "mkv" || "$ext" == "mp4" || \
        "$ext" == "avi" || "$ext" == "gif" || "$ext" == "webm" ]]; then
    addToFinalCommand "$file"
  fi
done < <(find "$inputFolder" -type f -print0 | grep -zv "__thumbs_mov")

eval "$finalCommand"
```

The complete final script should look like:

```bash
#!/bin/bash

finalCommand=""

addToFinalCommand() {
  local fspec="$1"
  local fnameWithExt
  fnameWithExt=$(basename "$fspec")
  local folderToOrig
  folderToOrig=$(dirname "$fspec")
  local fnameWithoutExt="${fnameWithExt%.*}"

  local fileOrig
  printf -v fileOrig "%q" "$fspec"

  local fileTargetFolder
  fileTargetFolder=$(sed "s|$inputFolder|$outputFolder|" <<<"$folderToOrig")
  local fileTarget
  printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithoutExt.mov"

  local W H
  W=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fspec")
  H=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fspec")

  local n_per_side=$(( (3840 + W - 1) / W ))
  local total=$(( 2 * n_per_side + 1 ))
  local strip_width=$(( W * total ))
  local crop_x=$(( (strip_width - 3840) / 2 ))
  local crop_y=$(( (H - 384) / 2 ))

  local filter="[0:v]split=${total}"
  for (( i=0; i<total; i++ )); do
    filter="${filter}[s${i}]"
  done
  filter="${filter};"

  local stack_inputs=""
  for (( i=0; i<total; i++ )); do
    local dist=$(( i < n_per_side ? n_per_side - i : i - n_per_side ))
    if (( dist % 2 == 1 )); then
      filter="${filter}[s${i}]hflip[f${i}];"
      stack_inputs="${stack_inputs}[f${i}]"
    else
      stack_inputs="${stack_inputs}[s${i}]"
    fi
  done

  filter="${filter}${stack_inputs}hstack=inputs=${total}[wide];"
  filter="${filter}[wide]crop=3840:${H}:${crop_x}:0[cw];"
  filter="${filter}[cw]crop=3840:384:0:${crop_y}[co];"
  filter="${filter}[co]fps=30,setsar=1[out]"

  finalCommand="$finalCommand ffmpeg -i $fileOrig -filter_complex \"${filter}\" -map \"[out]\" -an -c:v dxv -r 30 $fileTarget; "
}

# Catch trailing slash from user input
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj/_assets/1_dxv] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj/_assets/1_dxv"}
inputFolder="${inputFolder%/}"

echo "$inputFolder"

outputFolder="${inputFolder}_wide"
mkdir -p "$outputFolder"

find "$inputFolder" -type d | while read -r dir; do
  targetDir="${dir/$inputFolder/$outputFolder}"
  mkdir -p "$targetDir"
done

while IFS= read -r -d '' file; do
  ext="${file##*.}"
  if [[ "$ext" == "mov" || "$ext" == "mkv" || "$ext" == "mp4" || \
        "$ext" == "avi" || "$ext" == "gif" || "$ext" == "webm" ]]; then
    addToFinalCommand "$file"
  fi
done < <(find "$inputFolder" -type f -print0 | grep -zv "__thumbs_mov")

eval "$finalCommand"
```

- [ ] **Step 2: End-to-end test on a small subfolder**

Run the script pointing at a single subfolder to avoid processing all assets:
```bash
bash /Users/david/Desktop/vj/ffmpegConvert/convert/convertToWide.sh
# At the prompt enter: /Users/david/Desktop/vj/_assets/1_dxv/2023_05_12_stwst/twitter
```

Then spot-check one output file:
```bash
ffprobe -v quiet -select_streams v:0 \
  -show_entries stream=width,height,codec_name,r_frame_rate \
  -of csv=p=0 \
  "/Users/david/Desktop/vj/_assets/1_dxv/2023_05_12_stwst/twitter_wide/protobacillus-1655400210300915713-20230508_043220-gif1.mov"
# Expected: 3840,384,dxv,30/1
```

Also confirm `__thumbs_mov` files are absent from output:
```bash
find "/Users/david/Desktop/vj/_assets/1_dxv/2023_05_12_stwst/twitter_wide" -path "*__thumbs_mov*" | wc -l
# Expected: 0
```

- [ ] **Step 3: Commit**

```bash
git add convert/convertToWide.sh
git commit -m "feat: complete convertToWide.sh — mirror-tile DXV widescreen converter"
```
