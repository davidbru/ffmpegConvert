#!/bin/bash

# Usage: ./convertToWide.sh --folder /path/to/folder

targetWidth=11392
targetHeight=512

finalCommand=""
currentFileIndex=0
totalFiles=0

addToFinalCommand() {
  local fspec="$1"
  currentFileIndex=$((currentFileIndex + 1))
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
  fileTargetFolder="${outputFolder}${folderToOrig:${#inputFolder}}"
  local fileTarget
  printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithoutExt.mov"

  # get video dimensions
  local W H
  # some legacy QuickTime files carry a "track reference"/stream-group
  # structure that makes ffprobe report the same value twice (once per
  # section); take only the first line to guard against that
  W=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fspec" | head -n1)
  H=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fspec" | head -n1)

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

  local fnameDisplay
  printf -v fnameDisplay "%q" "$fnameWithExt"
  finalCommand="$finalCommand printf '\n\033[1;92m[%s/%s] Converting: %s\033[0m\n' \"${currentFileIndex}\" \"${totalFiles}\" $fnameDisplay; ffmpeg -i $fileOrig -filter_complex \"${filter}\" -map \"[out]\" -an -c:v dxv -r 30 $fileTarget; "
}

# Parse --folder argument
inputFolder=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)
      inputFolder="$2"
      shift 2
      ;;
    --folder=*)
      inputFolder="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --folder /path/to/folder" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$inputFolder" ]]; then
  echo "Usage: $0 --folder /path/to/folder" >&2
  exit 1
fi
inputFolder="${inputFolder%/}"  # Remove trailing slash if present

echo "$inputFolder"

# Create output folder next to input
outputFolder="${inputFolder}_wide"
mkdir -p "$outputFolder"

# Process directories first to ensure structure
while IFS= read -r dir; do
  targetDir="${outputFolder}${dir:${#inputFolder}}"
  mkdir -p "$targetDir"
done < <(find "$inputFolder" -type d)

# Collect matching video files first so we know the total count for
# progress reporting
videoFiles=()
while IFS= read -r -d '' file; do
  ext="${file##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ext" == "mov" || "$ext" == "mkv" || "$ext" == "mp4" || \
        "$ext" == "avi" || "$ext" == "gif" || "$ext" == "webm" ]]; then
    videoFiles+=("$file")
  fi
done < <(find "$inputFolder" -type f -print0 | grep -zv "__thumbs_mov")

totalFiles=${#videoFiles[@]}
for file in "${videoFiles[@]}"; do
  addToFinalCommand "$file"
done

eval "$finalCommand"

# Build an overview image into the output folder, sourced from the
# original files -- DXV output can't be previewed in Explorer/Finder,
# so this is the browsable overview instead.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$scriptDir/../overview/createOverview.sh" --folder "$inputFolder" --output "$outputFolder"
