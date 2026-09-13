#!/bin/bash

targetWidth=11392
targetHeight=512

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
  # rotate portrait footage to landscape before letterbox-widening
  local rotate_filter=""
  if (( H > W )); then
    rotate_filter="[0:v]transpose=1[rot];"
    local tmp=$W
    W=$H
    H=$tmp
  fi

  # scale (no cropping) so the full frame fits targetHeight, then derive
  # the scaled width to use for the horizontal tiling math
  local scaledW=$(( (W * targetHeight + H / 2) / H ))
  local scale_source="[0:v]"
  if [[ -n "$rotate_filter" ]]; then
    scale_source="[rot]"
  fi
  local scale_filter="${scale_source}scale=${scaledW}:${targetHeight}[scaled];"
  W=$scaledW
  H=$targetHeight

  # ceil(targetWidth / W) copies per side
  local n_per_side=$(( (targetWidth + W - 1) / W ))
  local total=$(( 2 * n_per_side + 1 ))
  local strip_width=$(( W * total ))
  local crop_x=$(( (strip_width - targetWidth) / 2 ))

  # build split filter
  local filter="${rotate_filter}${scale_filter}[scaled]split=${total}"
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

  # hstack → crop width to exact target → setsar → fps
  filter="${filter}${stack_inputs}hstack=inputs=${total}[wide];"
  filter="${filter}[wide]crop=${targetWidth}:${targetHeight}:${crop_x}:0[co];"
  filter="${filter}[co]fps=30,setsar=1[out]"

  finalCommand="$finalCommand ffmpeg -i $fileOrig -filter_complex \"${filter}\" -map \"[out]\" -an -c:v prores_ks -profile:v 4 -r 30 $fileTarget; "
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
