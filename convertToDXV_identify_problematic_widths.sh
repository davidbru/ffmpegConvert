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
    tag -a Red "$fspec"
    tagUpstream "$fspec" "Orange"
  fi
}

# Function to tag a file and its upstream directories
tagUpstream() {
  local filePath="$1"
  local tagName="$2"

  filePath=$(realpath "$filePath")

  while [ "$filePath" != "/" ]; do
    folderName=$(basename "$filePath")

    if [[ "$folderName" == "$stopFolder" ]]; then
      echo "Stopping at: $filePath"
      break
    fi

    if [ -d "$filePath" ]; then
      echo "Tagging: $filePath with $tagName"
      tag -a "$tagName" "$filePath"
    fi

    filePath=$(dirname "$filePath")
  done
}

addToFinalCommand() {
  echo "$1"

  export fspec="$1"
  fnameWithExt=$(basename "$fspec")
  fext="${fnameWithExt##*.}"

  # Preserve original path without extra escaping
  fileOrig="$fspec"

  if [[ "$fext" == "mov" || "$fext" == "mkv" || "$fext" == "mp4" || "$fext" == "avi" || "$fext" == "webm" ]]; then
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fileOrig")

    # Ensure width is a valid number
    if [[ "$width" =~ ^[0-9]+$ ]]; then
      checkWidth "$width" "$fspec"
    else
      echo "Error: Unable to retrieve width"
    fi
  else
    echo "Skipping (not a video file)"
  fi
}

# Get input folder
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present
stopFolder=$(basename "$inputFolder")

# Process files
while IFS= read -r -d '' file; do
  addToFinalCommand "$file"
done < <(find "$inputFolder" -type f -print0)
