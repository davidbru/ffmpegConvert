#!/bin/bash

checkWidth() {
  local width="$1"
  local fspec="$2"

  # Calculate remainder when width is divided by 16
  local remainder=$(( width % 16 ))

  # Check if the remainder is 0 (multiple of 16) or 8
  if [[ "$remainder" -eq 0 || "$remainder" -eq 8 ]]; then
    echo "$width: works"
  else
    echo "$width: does NOT work"
    tag -a "Red" "$fspec"
    tagUpstream "$fspec" "Orange"
  fi
}

tagUpstream() {
  local filePath="$1"
  local tagName="$2"

  filePath=$(realpath "$filePath")

  while [[ "$filePath" != "/" ]]; do
    local folderName=$(basename "$filePath")

    if [[ "$folderName" == "$stopFolder" ]]; then
      echo "Stopping at: $filePath"
      break
    fi

    if [[ -d "$filePath" ]]; then
      echo "Tagging: $filePath with $tagName"
      tag -a "$tagName" "$filePath"
    fi

    filePath=$(dirname "$filePath")
  done
}

addToFinalCommand() {
  local fspec="$1"

  echo "Processing: $fspec"
  local fnameWithExt=$(basename "$fspec")
  local fext="${fnameWithExt##*.}"

  # Preserve original path
  local fileOrig="$fspec"

  if [[ "$fext" =~ ^(mov|mkv|mp4|avi|webm)$ ]]; then
    local width
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fileOrig" 2>/dev/null)

    # Ensure width is a valid number
    if [[ "$width" =~ ^[0-9]+$ ]]; then
      checkWidth "$width" "$fspec"
    else
      echo "Error: Unable to retrieve width for $fileOrig"
    fi
  else
    echo "Skipping (not a video file): $fspec"
  fi
}

# Get input folder
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present
stopFolder=$(basename "$inputFolder")  # Define the stopping folder

# Process files
while IFS= read -r -d '' file; do
  addToFinalCommand "$file"
done < <(find "$inputFolder" -type f -print0)

