#!/bin/bash

finalCommand=""

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

  if [[ -z "$W" || -z "$H" || ! "$W" =~ ^[0-9]+$ || ! "$H" =~ ^[0-9]+$ ]]; then
    echo "Skipping $fspec: could not read dimensions" >&2
    return
  fi
  if (( H < 384 )); then
    echo "Skipping $fspec: height ${H}px is less than 384px" >&2
    return
  fi

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

# Catch trailing slash from user input
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj/_assets/1_dxv] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj/_assets/1_dxv"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present

echo "$inputFolder"

# Create output folder next to input
outputFolder="${inputFolder}_wide"
mkdir -p "$outputFolder"

# Process directories first to ensure structure
while IFS= read -r dir; do
  targetDir="${dir/$inputFolder/$outputFolder}"
  mkdir -p "$targetDir"
done < <(find "$inputFolder" -type d)

# Process video files (skip __thumbs_mov folders)
while IFS= read -r -d '' file; do
  ext="${file##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ext" == "mov" || "$ext" == "mkv" || "$ext" == "mp4" || \
        "$ext" == "avi" || "$ext" == "gif" || "$ext" == "webm" ]]; then
    addToFinalCommand "$file"
  fi
done < <(find "$inputFolder" -type f -print0 | grep -zv "__thumbs_mov")

eval "$finalCommand"
