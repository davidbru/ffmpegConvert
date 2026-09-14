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

progress() {
  printf '\033[1;92m%s\033[0m\n' "$1"
}

# Collect files first so we know the total count for progress reporting
progress "Scanning for files..."
videoFiles=()
for filename in "$inputFolder"/*; do
  [[ -f "$filename" ]] && videoFiles+=("$filename")
done
totalFiles=${#videoFiles[@]}
currentFileIndex=0
progress "Found ${totalFiles} file(s) to process."

# Process all files in the input folder
for input_path in "${videoFiles[@]}"; do
  filename=$(basename "$input_path")
  currentFileIndex=$((currentFileIndex + 1))

  output_path="$outputFolder/$filename"

  progress "[${currentFileIndex}/${totalFiles}] Converting: ${filename}"
  ffmpeg -y -loglevel error -i "$input_path" -filter:v "setpts=PTS/$speedupFactor" -an -c:v libx264 -preset fast -crf 23 "$output_path"
done

# Build an overview image into the output folder, sourced from the
# original files.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$scriptDir/../overview/createOverview.sh" --folder "$inputFolder" --output "$outputFolder"
