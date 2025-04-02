#!/bin/bash

clearAllTagsFromInputFolder() {
  echo "Removing all tags from files and directories in: $inputFolder"

  # Remove tags from all files
  find "$inputFolder" -type f -print0 | xargs -0 tag -r '*' 2>/dev/null

  # Remove tags from all directories
  find "$inputFolder" -type d -print0 | xargs -0 tag -r '*' 2>/dev/null
}

checkWidth() {
  local width="$1"
  local fspec="$2"

  # Calculate remainder when width is divided by 16
  local remainder=$(( width % 16 ))

  # Check if the remainder is 0 (multiple of 16) or 8
  if [[ "$remainder" -ne 0 ]]; then
      echo "$fspec - $width: does NOT work"
      tag -a "Red" "$fspec"
      tagUpstream "$fspec" "Orange"
#  else
#      echo "$fspec - $width: works"
  fi
}

tagUpstream() {
  local filePath="$1"
  local tagName="$2"

  filePath=$(realpath "$filePath")

  while [[ "$filePath" != "/" ]]; do
    local folderName=$(basename "$filePath")

    if [[ "$folderName" == "$stopFolder" ]]; then
#      echo "Stopping at: $filePath"
      break
    fi

    if [[ -d "$filePath" ]]; then
#      echo "Tagging: $filePath with $tagName"
      tag -a "$tagName" "$filePath"
    fi

    filePath=$(dirname "$filePath")
  done
}

processFile() {
  local fspec="$1"

#  echo "Processing: $fspec"
  local fnameWithExt=$(basename "$fspec")
  local fext="${fnameWithExt##*.}"

  # Preserve original path
  local fileOrig="$fspec"

  if [[ "$fext" =~ ^(mov|mkv|mp4|avi|webm)$ ]]; then
    local codec width
    codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$fileOrig" 2>/dev/null)

    # Check if the codec is DXV
    if [[ "$codec" == "dxv" ]]; then
      width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fileOrig" 2>/dev/null)

      # Ensure width is a valid number
      if [[ "$width" =~ ^[0-9]+$ ]]; then
        checkWidth "$width" "$fspec"
      else
        echo "Error: Unable to retrieve width for $fileOrig"
      fi
#    else
#      echo "$fileOrig is not DXV"
    fi
#  else
#    echo "Skipping (not a video file): $fspec"
  fi
}

# Get input folder
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present
stopFolder=$(basename "$inputFolder")  # Define the stopping folder

clearAllTagsFromInputFolder

# Process files
while IFS= read -r -d '' file; do
  processFile "$file"
done < <(find "$inputFolder" -type f -print0)

