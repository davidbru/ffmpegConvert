#!/bin/bash

# Usage: ./createOverview.sh --folder /path/to/source [--output /path/to/target]
#
# Creates one overview image (_overview.jpg) per folder, recursively,
# containing a single representative frame from every video file directly
# inside that folder in --folder. Useful for browsing DXV/Hap-encoded
# folders in Explorer/Finder, since neither OS can generate native
# thumbnails for those codecs.
#
# Frames are always read from --folder (the original source footage, not a
# DXV/Hap/wide-tiled conversion of it, which wouldn't be a meaningful
# preview). Without --output, the image is written directly into that same
# source folder. With --output, --folder's directory structure is mirrored
# under --output and the image is written there instead -- so it sits next
# to the *converted* files it's meant to help you browse, not the
# originals.

columns=4
cellWidth=320
cellHeight=180
bgColor="black"
borderWidth=10
borderColor="white"

tileWidth=$(( cellWidth + 2 * borderWidth ))
tileHeight=$(( cellHeight + 2 * borderWidth ))

extensions=(mov mkv mp4 avi gif webm)

# Parse --folder and --output arguments
inputFolder=""
outputFolder=""
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
    --output)
      outputFolder="$2"
      shift 2
      ;;
    --output=*)
      outputFolder="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --folder /path/to/source [--output /path/to/target]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$inputFolder" ]]; then
  echo "Usage: $0 --folder /path/to/source [--output /path/to/target]" >&2
  exit 1
fi
inputFolder="${inputFolder%/}"  # Remove trailing slash if present
outputFolder="${outputFolder%/}"

isVideoExt() {
  local ext
  ext="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  local e
  for e in "${extensions[@]}"; do
    [[ "$ext" == "$e" ]] && return 0
  done
  return 1
}

buildBlankCell() {
  local out="$1"
  ffmpeg -y -v error -f lavfi -i "color=${bgColor}:s=${cellWidth}x${cellHeight}" -frames:v 1 \
    -vf "pad=${tileWidth}:${tileHeight}:${borderWidth}:${borderWidth}:color=${borderColor}" \
    "$out"
}

extractThumb() {
  local fspec="$1"
  local out="$2"

  local duration
  duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$fspec")
  if [[ -z "$duration" ]]; then
    echo "Skipping $fspec: could not read duration" >&2
    return 1
  fi
  local half
  half=$(awk -v d="$duration" 'BEGIN { printf "%.2f", d / 2 }')

  ffmpeg -y -v error -ss "$half" -i "$fspec" -frames:v 1 \
    -vf "scale=${cellWidth}:${cellHeight}:force_original_aspect_ratio=decrease,pad=${cellWidth}:${cellHeight}:(ow-iw)/2:(oh-ih)/2:color=${bgColor},pad=${tileWidth}:${tileHeight}:${borderWidth}:${borderWidth}:color=${borderColor}" \
    "$out"
}

processDir() {
  local dir="$1"
  local writeDir="$dir"
  if [[ -n "$outputFolder" ]]; then
    writeDir="${outputFolder}${dir:${#inputFolder}}"
    mkdir -p "$writeDir"
  fi

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f -print0 | sort -z)

  local videos=()
  local f ext
  for f in "${files[@]}"; do
    ext="${f##*.}"
    if isVideoExt "$ext"; then
      videos+=("$f")
    fi
  done

  local count=${#videos[@]}
  if (( count == 0 )); then
    return
  fi

  echo "Building overview for: $dir ($count video(s))"

  local tmpDir
  tmpDir=$(mktemp -d)

  local thumbs=()
  local i=0
  local v thumbPath
  for v in "${videos[@]}"; do
    thumbPath="$tmpDir/thumb_$(printf "%04d" "$i").jpg"
    if extractThumb "$v" "$thumbPath"; then
      thumbs+=("$thumbPath")
    fi
    i=$((i + 1))
  done

  local actualCount=${#thumbs[@]}
  if (( actualCount == 0 )); then
    rm -rf "$tmpDir"
    return
  fi

  # cap columns at the actual video count so a folder with e.g. 1-3 videos
  # doesn't get padded out to a full-width row of mostly blank cells
  local effectiveColumns=$columns
  if (( actualCount < effectiveColumns )); then
    effectiveColumns=$actualCount
  fi
  local rows=$(( (actualCount + effectiveColumns - 1) / effectiveColumns ))
  local totalCells=$(( rows * effectiveColumns ))

  # pad with blank cells so the grid is rectangular
  if (( totalCells > actualCount )); then
    local blankPath="$tmpDir/blank.jpg"
    buildBlankCell "$blankPath"
    while (( ${#thumbs[@]} < totalCells )); do
      thumbs+=("$blankPath")
    done
  fi

  local outFile="$writeDir/_overview.jpg"

  if (( totalCells == 1 )); then
    cp "${thumbs[0]}" "$outFile"
  else
    local inputs=()
    local t
    for t in "${thumbs[@]}"; do
      inputs+=(-i "$t")
    done

    local layout=""
    local idx col row x y
    for (( idx=0; idx<totalCells; idx++ )); do
      col=$(( idx % effectiveColumns ))
      row=$(( idx / effectiveColumns ))
      x=$(( col * tileWidth ))
      y=$(( row * tileHeight ))
      layout="${layout}${x}_${y}"
      if (( idx < totalCells - 1 )); then
        layout="${layout}|"
      fi
    done

    ffmpeg -y -v error "${inputs[@]}" -filter_complex "xstack=inputs=${totalCells}:layout=${layout}" "$outFile"
  fi

  rm -rf "$tmpDir"
  echo "  -> $outFile"
}

while IFS= read -r -d '' dir; do
  processDir "$dir"
done < <(find "$inputFolder" -type d ! -name "__thumbs_mov" -print0)
