#!/bin/bash

read -p "Pfad zum Ordner mit den originalen Dateien: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
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
  ffmpeg_cmd="ffmpeg -y -loglevel error -i \"$input_path\" -filter:v \"setpts=PTS/4\" -an -c:v libx264 -preset fast -crf 23 \"$output_path\""
  commands+="$ffmpeg_cmd; "

done

# After collecting all commands, echo them for debugging
echo "Commands to be executed:"
echo "$commands"

# Execute all the commands
eval "$commands"
