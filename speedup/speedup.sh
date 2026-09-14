#!/bin/bash

# Usage: ./speedup.sh --folder /path/to/folder

speedupFactor=6

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


outputFolder="${inputFolder}_Fast"
mkdir -p "$outputFolder"

# Initialize an empty variable to hold all ffmpeg commands
commands=""

# Process all files in the input folder
for filename in "$inputFolder"/*; do
  # Get only the filename without the path
  filename=$(basename "$filename")
  
  echo "Processing: $filename"

  input_path="$inputFolder/$filename"
  output_path="$outputFolder/$filename"

  echo "  Input path: $input_path"
  echo "  Output path: $output_path"

  if [[ ! -f "$input_path" ]]; then
    echo "  ⚠️  Skipping: File not found."
    continue
  fi

  # Build the ffmpeg command and append it to the `commands` variable
  ffmpeg_cmd="ffmpeg -y -loglevel error -i \"$input_path\" -filter:v \"setpts=PTS/$speedupFactor\" -an -c:v libx264 -preset fast -crf 23 \"$output_path\""
  commands+="$ffmpeg_cmd; "

done

# After collecting all commands, echo them for debugging
echo "Commands to be executed:"
echo "$commands"

# Execute all the commands
eval "$commands"

# Refresh the contact sheet for the original folder -- a single browsable
# overview image of what's in it.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$scriptDir/../contactsheet/createContactSheet.sh" --folder "$inputFolder"
